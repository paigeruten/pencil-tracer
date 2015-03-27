coffeeScript = require "coffee-script"
{nodeType, makeUndefinedNode, makeAssignNode, makeReturnNode} = require "./ast"

class InstrumentError extends Error
  constructor: (@message) ->
    @name = "InstrumentError"
    Error.call this
    Error.captureStackTrace this, arguments.callee

fixLocationData = (instrumentedLine, lineNum) ->
  doIt = (node) ->
    node.locationData =
      first_line: lineNum - 1
      first_column: 0
      last_line: lineNum - 1
      last_column: 0

  doIt instrumentedLine
  instrumentedLine.eachChild doIt

createInstrumentedLine = (traceFunc, locationData, eventType) ->
  locationObj = "{ first_line: #{locationData.first_line + 1},"
  locationObj += " first_column: #{locationData.first_column},"
  locationObj += " last_line: #{locationData.last_line + 1},"
  locationObj += " last_column: #{locationData.last_column} }"

  instrumentedLine =
    coffeeScript.nodes("#{traceFunc}({ location: #{locationObj}, type: '#{eventType}' })")

  fixLocationData(instrumentedLine, locationData.first_line + 1)

  instrumentedLine

temporaryVariable = (name, used) ->
  index = 0
  loop
    curName = "#{name}#{index}"
    return curName unless curName in used
    index++

# Options:
#   traceFunc: the name of the function to call and pass events into (default: "ide.trace")
#   ast: if true, returns the instrumented AST instead of compiling it
exports.instrument = (filename, code, options = {}) ->
  traceFunc = options.traceFunc ? "ide.trace"

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
    # trigger with each Return statement.
    inCode = node if nodeType(node) is "Code"

    if nodeType(node) is "Block"
      children = node.expressions
      childIndex = 0
      while childIndex < children.length
        expression = children[childIndex]

        unless expression.doNotInstrument or nodeType(expression) is "Comment"
          instrumentedLine = createInstrumentedLine(traceFunc, expression.locationData, "")

          children.splice(childIndex, 0, instrumentedLine)
          childIndex++

          instrumentTree(expression, childIndex, node, inCode)

        childIndex++

      if nodeType(parent) is "Code"
        # The enter event is easy, just stick it at the top of the function body.
        children.splice(0, 0, createInstrumentedLine(traceFunc, parent.locationData, "enter"))

        # The leave event is a lot more complicated. It has to trigger right
        # before any return statements in the function, or at the end of the
        # function in the case of an implicit return.
        #
        # Furthermore, to get enter and leave events in the right order, we
        # need to make sure the expression whose value is being returned is
        # evaluated before the instrumented line. So we need to assign the
        # returned expression to a temporary variable, do the instrumented
        # line, then return the temporary variable.
        if children.length == 1
          # If the function body was empty, add the instrumented line and then
          # make "undefined" the return value of the function.
          children.splice(1, 0, createInstrumentedLine(traceFunc, parent.locationData, "leave"))

          # coffeeScript.nodes will return a Block(Value(Undefined())), we just
          # want Value(Undefined()), so unwrap it from the Block.
          children.splice(2, 0, makeUndefinedNode())
        else
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

            # Add the instrumented line for the 'leave' event after the Assign.
            children.splice(children.length, 0, createInstrumentedLine(traceFunc, parent.locationData, "leave"))

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

        # Add the instrumented line for the 'leave' event after the Assign.
        parent.expressions.splice(nodeIndex + 1, 0, createInstrumentedLine(traceFunc, inCode.locationData, "leave"))

        # Add a new Return node that returns the temporary variable after the
        # instrumented line.
        parent.expressions.splice(nodeIndex + 2, 0, makeReturnNode(tempVariableName))

        # Mark the three nodes we just added so that they are not instrumented
        # themselves.
        parent.expressions[nodeIndex].doNotInstrument = true
        parent.expressions[nodeIndex + 1].doNotInstrument = true
        parent.expressions[nodeIndex + 2].doNotInstrument = true

      # coffee-coverage does this, because chaining "produces code that's
      # harder to instrument".
      # TODO: figure out if this is actually needed for what we're doing.
      #       test/traces/if_chain.coffee still passes when this is commented out.
      if nodeType(node) is "If"
        node.isChain = false

      node.eachChild (child) =>
        instrumentTree(child, null, node, inCode)

  instrumentTree ast

  return ast if options.ast

  try
    js = ast.compile {}
  catch err
    throw new InstrumentError("Could not compile #{filename} after instrumenting: #{err.stack}")

  return js

