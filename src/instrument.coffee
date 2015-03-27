coffeeScript = require "coffee-script"
{nodeType, makeUndefinedNode, makeAssignNode, makeReturnNode} = require "./ast"

class InstrumentError extends Error
  constructor: (@message) ->
    @name = "InstrumentError"
    Error.call this
    Error.captureStackTrace this, arguments.callee

# Sets the line number of the given instrumented node, and sets it recursively
# on each child.
fixLocationData = (instrumentedNode, lineNum) ->
  doIt = (node) ->
    node.locationData =
      first_line: lineNum
      first_column: 0
      last_line: lineNum
      last_column: 0

  doIt instrumentedNode
  instrumentedNode.eachChild doIt

# Creates an instrumented node that calls the trace function, passing in the
# event object.
createInstrumentedNode = (traceFunc, locationData, eventType) ->
  # Give the line and column numbers as 1-indexed values, instead of 0-indexed.
  locationObj = "{ first_line: #{locationData.first_line + 1},"
  locationObj += " first_column: #{locationData.first_column + 1},"
  locationObj += " last_line: #{locationData.last_line + 1},"
  locationObj += " last_column: #{locationData.last_column + 1} }"

  # Create the node from a string of CoffeeScript.
  instrumentedNode =
    coffeeScript.nodes("#{traceFunc}({ location: #{locationObj}, type: '#{eventType}' })")

  # Set the line number of the node and its children to the line number of the
  # code it corresponds to.
  fixLocationData(instrumentedNode, locationData.first_line)

  instrumentedNode

# Returns a unique name to use as a temporary variable, by appending a number
# to the given name until it gets a string that isn't in `used`.
temporaryVariable = (name, used) ->
  index = 0
  loop
    curName = "#{name}#{index}"
    return curName unless curName in used
    index++

# Instruments some CoffeeScript code, compiles to JavaScript, and returns the
# JavaScript code.
#
# Options:
#   traceFunc: the name of the function to call and pass events into (default: "ide.trace")
#   ast: if true, returns the instrumented AST instead of compiling
#
exports.instrument = (filename, code, options = {}) ->
  traceFunc = options.traceFunc ? "ide.trace"

  # Parse the code to get an AST.
  try
    tokens = coffeeScript.tokens code, {}

    # Get all referenced variables so we can generate a unique one when we need
    # to use a temporary variable.
    referencedVars = (token[1] for token in tokens when token.variable)

    ast = coffeeScript.nodes tokens
  catch err
    throw new InstrumentError("Could not parse #{filename}: #{err.stack}")

  # Instruments the AST recursively. Arguments:
  #   node: the current node of the AST
  #   nodeIndex: the index of the current node in its Block, or null if the
  #     parent node is not a Block.
  #   parent: the parent node, or null if we're on the root node
  #   inCode: the innermost Code block we are currently in
  #
  instrumentTree = (node, nodeIndex=null, parent=null, inCode=null) ->
    # Keep track of which Code node we are currently in. A Code is a function
    # definition, and we need the Code's location data for 'leave' events that
    # trigger on Return statements.
    inCode = node if nodeType(node) is "Code"

    # Instrument children of Blocks.
    if nodeType(node) is "Block"
      children = node.expressions
      childIndex = 0
      while childIndex < children.length
        expression = children[childIndex]

        # Skip Comments and nodes that we have spliced in ourselves.
        unless expression.doNotInstrument or nodeType(expression) is "Comment"
          # Instrument this line with a normal event.
          instrumentedNode = createInstrumentedNode(traceFunc, expression.locationData, "")

          # Insert it before the node it corresponds to, and correct the childIndex.
          children.splice(childIndex, 0, instrumentedNode)
          childIndex++

          # Recursively instrument the children of this node.
          instrumentTree(expression, childIndex, node, inCode)

        childIndex++

      # If this is the outer-most Block of a function definition (a Code node),
      # then we need to have an "enter" event trigger at the top of the function,
      # and a "leave" event trigger at the bottom.
      if nodeType(parent) is "Code"
        # The "enter" event is easy, just stick it at the top of the function body.
        children.splice(0, 0, createInstrumentedNode(traceFunc, parent.locationData, "enter"))

        # The "leave" event is a lot more complicated. It has to trigger right
        # before any return statements in the function, and at the end of the
        # function in the case of an implicit return.
        #
        # Furthermore, to get "enter" and "leave" events in the right order, we
        # need to make sure the expression being returned is evaluated before
        # the "leave" event is triggered. So we need to assign the returned
        # expression to a temporary variable, trigger the event, then return
        # the temporary variable.
        if children.length == 1
          # If the function body was empty, add the instrumented node and then
          # make "undefined" the return value of the function.
          children.splice(1, 0, createInstrumentedNode(traceFunc, parent.locationData, "leave"))
          children.splice(2, 0, makeUndefinedNode())
        else
          # Get the last expression, which is implicitly returned (unless it's
          # a Return statement).
          lastExpr = children[children.length - 1]

          # Don't have to do anything if it's an explicit Return, we'll handle
          # that case when we traverse that Return node.
          unless nodeType(lastExpr) is "Return"
            # Get a temporary variable name and add it to referencedVars so we
            # don't use it again.
            tempVariableName = temporaryVariable("_tempReturnVal", referencedVars)
            referencedVars.push(tempVariableName)

            # Make an Assign node with our temporary variable name, and the
            # last expression in the function as the value.
            assignNode = makeAssignNode(tempVariableName, lastExpr)

            # Replace the last expression in the function with the Assign.
            children.splice(children.length - 1, 1, assignNode)

            # Add the instrumented node for the 'leave' event after the Assign.
            children.splice(children.length, 0, createInstrumentedNode(traceFunc, parent.locationData, "leave"))

            # Add the temporary variable as the last expression of the function.
            children.splice(children.length, 0, coffeeScript.nodes(tempVariableName).expressions[0])
    else
      # Return statements need to be replaced with an assignment to a temporary
      # variable, an instrumented 'leave' event, and a Return statement that
      # returns the temporary variable.
      if nodeType(node) is "Return" and inCode?
        # I'm pretty sure the parent of a Return has to be a Block.
        # TODO: make sure this assumption is always true.
        if nodeType(parent) isnt "Block"
          throw new InstrumentError("Encountered a Return whose parent is not a Block. This is a bug, please report!")

        # Get a temporary variable name and add it to referencedVars so we don't
        # use it again.
        tempVariableName = temporaryVariable("_tempReturnVal", referencedVars)
        referencedVars.push(tempVariableName)

        # Make an Assign node with our temporary variable name, and the
        # expression in the Return node as the value.
        assignNode = makeAssignNode(tempVariableName, node.expression)

        # Replace the Return node with the Assign.
        parent.expressions.splice(nodeIndex, 1, assignNode)

        # Add the instrumented node for the 'leave' event after the Assign.
        parent.expressions.splice(nodeIndex + 1, 0, createInstrumentedNode(traceFunc, inCode.locationData, "leave"))

        # Add a new Return node that returns the temporary variable after the
        # instrumented line.
        parent.expressions.splice(nodeIndex + 2, 0, makeReturnNode(tempVariableName))

        # Mark the three nodes we just added so that they won't be instrumented
        # themselves.
        parent.expressions[nodeIndex].doNotInstrument = true
        parent.expressions[nodeIndex + 1].doNotInstrument = true
        parent.expressions[nodeIndex + 2].doNotInstrument = true

      # Recursively instrument each child of this node.
      node.eachChild (child) =>
        instrumentTree(child, null, node, inCode)

  # Instrument the whole AST.
  instrumentTree ast

  # If caller just wants the AST, return it now.
  return ast if options.ast

  # Compile the instrumented AST to JavaScript.
  try
    js = ast.compile {}
  catch err
    throw new InstrumentError("Could not compile #{filename} after instrumenting: #{err.stack}")

  # Return the JavaScript.
  return js

