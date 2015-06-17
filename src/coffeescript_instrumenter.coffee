class CoffeeScriptInstrumenter
  # The constructor takes the CoffeeScript module to use to parse the code,
  # generate instrumented code, and compile the result to JavaScript. This lets
  # you instrument Iced CoffeeScript if you want, for example.
  constructor: (@coffee) ->
    if not @coffee?
      throw new Error("A CoffeeScript compiler must be passed to CoffeeScriptInstrumenter!")

    @getNodeTypes()

  # Get the constructor for each possible node type in the AST. This is
  # used to identify the type of each node in the AST, since we can't depend
  # on constructor.name if the coffee-script library is minified.
  getNodeTypes: ->
    @nodeTypes =
      'Block': @coffee.nodes("").constructor
      'Literal': @coffee.nodes("0").expressions[0].base.constructor
      'Undefined': @coffee.nodes("undefined").expressions[0].base.constructor
      'Null': @coffee.nodes("null").expressions[0].base.constructor
      'Bool': @coffee.nodes("true").expressions[0].base.constructor
      'Return': @coffee.nodes("return").expressions[0].constructor
      'Value': @coffee.nodes("0").expressions[0].constructor
      'Comment': @coffee.nodes("###\n###").expressions[0].constructor
      'Call': @coffee.nodes("f()").expressions[0].constructor
      'Extends': @coffee.nodes("A extends B").expressions[0].constructor
      'Access': @coffee.nodes("a.b").expressions[0].properties[0].constructor
      'Index': @coffee.nodes("a[0]").expressions[0].properties[0].constructor
      'Range': @coffee.nodes("[0..1]").expressions[0].base.constructor
      'Slice': @coffee.nodes("a[0..1]").expressions[0].properties[0].constructor
      'Obj': @coffee.nodes("{}").expressions[0].base.constructor
      'Arr': @coffee.nodes("[]").expressions[0].base.constructor
      'Class': @coffee.nodes("class").expressions[0].constructor
      'Assign': @coffee.nodes("a=0").expressions[0].constructor
      'Code': @coffee.nodes("->").expressions[0].constructor
      'Param': @coffee.nodes("(a)->").expressions[0].params[0].constructor
      'Splat': @coffee.nodes("[a...]").expressions[0].base.objects[0].constructor
      'Expansion': @coffee.nodes("[...]").expressions[0].base.objects[0].constructor
      'While': @coffee.nodes("0 while true").expressions[0].constructor
      'Op': @coffee.nodes("1+1").expressions[0].constructor
      'In': @coffee.nodes("0 in []").expressions[0].constructor
      'Try': @coffee.nodes("try").expressions[0].constructor
      'Throw': @coffee.nodes("throw 0").expressions[0].constructor
      'Existence': @coffee.nodes("a?").expressions[0].constructor
      'Parens': @coffee.nodes("(0)").expressions[0].base.constructor
      'For': @coffee.nodes("0 for a in []").expressions[0].constructor
      'Switch': @coffee.nodes("switch a\n  when 0 then 0").expressions[0].constructor
      'If': @coffee.nodes("0 if 0").expressions[0].constructor

    # If we have an Iced CoffeeScript compiler, get the Iced-specific node
    # types as well.
    if @coffee.iced?
      icedNodes = @coffee.nodes("await f defer a")
      @nodeTypes.IcedRuntime = icedNodes.expressions[0].constructor
      @nodeTypes.Await = icedNodes.expressions[1].constructor
      @nodeTypes.Defer = icedNodes.expressions[1].body.expressions[0].args[0].constructor
      @nodeTypes.Slot = icedNodes.expressions[1].body.expressions[0].args[0].slots[0].constructor
    else
      # Otherwise assign them to an empty function so we can still use the
      # instanceof operator on them.
      @nodeTypes.IcedRuntime = @nodeTypes.Await = @nodeTypes.Defer = @nodeTypes.Slot = ->

  # Create a Value(Undefined()) node.
  makeUndefinedNode: ->
    @coffee.nodes("undefined").expressions[0]

  # Create an Assign node that assigns the given valueNode to the given variable
  # name.
  makeAssignNode: (variableName, valueNode) ->
    node = @coffee.nodes("x = 0").expressions[0]
    node.variable.base.value = variableName
    node.value = valueNode
    node

  # Create a Return node that returns the value of the given variable name.
  makeReturnNode: (variableName) ->
    node = @coffee.nodes("return x").expressions[0]
    node.expression.base.value = variableName
    node

  # Sets the line number of the given instrumented node, and sets it recursively
  # on each child.
  fixLocationData: (instrumentedNode, lineNum) ->
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
  createInstrumentedNode: (traceFunc, locationData, eventType) ->
    # Give the line and column numbers as 1-indexed values, instead of 0-indexed.
    locationObj = "{ first_line: #{locationData.first_line + 1},"
    locationObj += " first_column: #{locationData.first_column + 1},"
    locationObj += " last_line: #{locationData.last_line + 1},"
    locationObj += " last_column: #{locationData.last_column + 1} }"

    # Create the node from a string of CoffeeScript.
    instrumentedNode =
      @coffee.nodes("#{traceFunc}({ location: #{locationObj}, type: '#{eventType}' })")

    # Set the line number of the node and its children to the line number of the
    # code it corresponds to.
    @fixLocationData(instrumentedNode, locationData.first_line)

    instrumentedNode

  # Returns a unique name to use as a temporary variable, by appending a number
  # to the given name until it gets a string that isn't in `used`.
  temporaryVariable: (name, used) ->
    name = "_penciltracer_#{name}"
    index = 0
    loop
      curName = "#{name}#{index}"
      return curName unless curName in used
      index++

  compileAst: (ast, originalCode, options) ->
    # Pilfer the SourceMap class from CoffeeScript...
    SourceMap = @coffee.compile("", sourceMap: true).sourceMap.constructor

    if options.sourceMap
      map = new SourceMap

    fragments = ast.compileToFragments options

    currentLine = 0
    currentLine += 1 if options.header
    currentLine += 1 if options.shiftLine
    currentColumn = 0
    js = ""
    for fragment in fragments
      if options.sourceMap
        if fragment.locationData and not /^[;\s]*$/.test fragment.code
          map.add(
            [fragment.locationData.first_line, fragment.locationData.first_column]
            [currentLine, currentColumn]
            {noReplace: true})
        newLines = @coffee.helpers.count fragment.code, "\n"
        currentLine += newLines
        if newLines
          currentColumn = fragment.code.length - (fragment.code.lastIndexOf("\n") + 1)
        else
          currentColumn += fragment.code.length

      js += fragment.code

    if options.header
      compilerName = if @coffee.iced? then "IcedCoffeeScript" else "CoffeeScript"
      header = "Generated by #{compilerName} #{@coffee.VERSION} (instrumented by pencil-tracer)"
      js = "// #{header}\n#{js}"

    if options.sourceMap
      answer = {js}
      answer.sourceMap = map
      answer.v3SourceMap = map.generate(options, originalCode)
      answer
    else
      js

  # Instruments some CoffeeScript code, compiles to JavaScript, and returns the
  # JavaScript code.
  #
  # Options:
  #   traceFunc: the name of the function to call and pass events into (default: "pencilTrace")
  #   ast: if true, returns the instrumented AST instead of compiling
  #
  instrument: (filename, code, options = {}) ->
    traceFunc = options.traceFunc ? "pencilTrace"

    # Tokenize the code.
    tokens = @coffee.tokens code, {}

    # Get all referenced variables so we can generate a unique one when we need
    # to use a temporary variable.
    referencedVars = (token[1] for token in tokens when token.variable)

    # Parse the tokens to get an AST.
    ast = @coffee.nodes tokens

    # Instruments the AST recursively. Arguments:
    #   node: the current node of the AST
    #   nodeIndex: the index of the current node in its Block, or null if the
    #     parent node is not a Block.
    #   parent: the parent node, or null if we're on the root node
    #   inCode: the innermost Code block we are currently in
    #
    instrumentTree = (node, nodeIndex=null, parent=null, inCode=null) =>
      # Keep track of which Code node we are currently in. A Code is a function
      # definition, and we need the Code's location data for 'leave' events that
      # trigger on Return statements.
      inCode = node if node instanceof @nodeTypes.Code

      # Instrument children of Blocks.
      if node instanceof @nodeTypes.Block and parent not instanceof @nodeTypes.Parens
        children = node.expressions
        children.push node.icedContinuationBlock if node.icedContinuationBlock
        childIndex = 0
        while childIndex < children.length
          expression = children[childIndex]

          # Skip Comments and nodes that we have spliced in ourselves.
          # Also skip Iced CoffeeScript's runtime node. (TODO: Allow a blacklist
          # option to be passed in, with these two node types as defaults.)
          unless expression.doNotInstrument or expression instanceof @nodeTypes.Comment or expression instanceof @nodeTypes.IcedRuntime
            # Instrument this line with a normal event.
            instrumentedNode = @createInstrumentedNode(traceFunc, expression.locationData, "")

            # Insert it before the node it corresponds to, and correct the childIndex.
            children.splice(childIndex, 0, instrumentedNode)
            childIndex++

            # Recursively instrument the children of this node.
            instrumentTree(expression, childIndex, node, inCode)

          childIndex++

        # If this is the outer-most Block of a function definition (a Code node),
        # then we need to have an "enter" event trigger at the top of the function,
        # and a "leave" event trigger at the bottom.
        if parent instanceof @nodeTypes.Code
          # The "enter" event is easy, just stick it at the top of the function body.
          children.splice(0, 0, @createInstrumentedNode(traceFunc, parent.locationData, "enter"))

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
            children.splice(1, 0, @createInstrumentedNode(traceFunc, parent.locationData, "leave"))
            children.splice(2, 0, @makeUndefinedNode())
          else
            # Get the last expression, which is implicitly returned (unless it's
            # a Return statement).
            lastExpr = children[children.length - 1]

            # Don't have to do anything if it's an explicit Return, we'll handle
            # that case when we traverse that Return node.
            #
            # Also don't worry about an Await node, as it is currently always a
            # statement and can't be assigned a value.
            unless lastExpr instanceof @nodeTypes.Return or lastExpr instanceof @nodeTypes.Await
              # Get a temporary variable name and add it to referencedVars so we
              # don't use it again.
              tempVariableName = @temporaryVariable("tempReturnVal", referencedVars)
              referencedVars.push(tempVariableName)

              # Make an Assign node with our temporary variable name, and the
              # last expression in the function as the value.
              assignNode = @makeAssignNode(tempVariableName, lastExpr)

              # Replace the last expression in the function with the Assign.
              children.splice(children.length - 1, 1, assignNode)

              # Add the instrumented node for the 'leave' event after the Assign.
              children.splice(children.length, 0, @createInstrumentedNode(traceFunc, parent.locationData, "leave"))

              # Add the temporary variable as the last expression of the function.
              children.splice(children.length, 0, @coffee.nodes(tempVariableName).expressions[0])
      else
        # Return statements need to be replaced with an assignment to a temporary
        # variable, an instrumented 'leave' event, and a Return statement that
        # returns the temporary variable.
        if node instanceof @nodeTypes.Return and inCode?
          # I'm pretty sure the parent of a Return has to be a Block.
          # TODO: make sure this assumption is always true.
          if parent not instanceof @nodeTypes.Block
            throw new Error("Encountered a Return whose parent is not a Block. This is a bug, please report!")

          # Get a temporary variable name and add it to referencedVars so we don't
          # use it again.
          tempVariableName = @temporaryVariable("tempReturnVal", referencedVars)
          referencedVars.push(tempVariableName)

          # Make an Assign node with our temporary variable name, and the
          # expression in the Return node as the value.
          assignNode = @makeAssignNode(tempVariableName, node.expression)

          # Replace the Return node with the Assign.
          parent.expressions.splice(nodeIndex, 1, assignNode)

          # Add the instrumented node for the 'leave' event after the Assign.
          parent.expressions.splice(nodeIndex + 1, 0, @createInstrumentedNode(traceFunc, inCode.locationData, "leave"))

          # Add a new Return node that returns the temporary variable after the
          # instrumented line.
          parent.expressions.splice(nodeIndex + 2, 0, @makeReturnNode(tempVariableName))

          # Mark the three nodes we just added so that they won't be instrumented
          # themselves.
          parent.expressions[nodeIndex].doNotInstrument = true
          parent.expressions[nodeIndex + 1].doNotInstrument = true
          parent.expressions[nodeIndex + 2].doNotInstrument = true

        # Recursively instrument each child of this node.
        node.eachChild (child) =>
          instrumentTree(child, null, node, inCode)

        if node.icedContinuationBlock?
          instrumentTree(node.icedContinuationBlock, null, node, inCode)

    # Instrument the whole AST.
    instrumentTree ast

    # If caller just wants the AST, return it now.
    return ast if options.ast

    # Compile the instrumented AST to JavaScript.
    try
      compileOptions =
        runtime: "inline" # for Iced CoffeeScript, includes the runtime in the output
        bare: options.bare
        header: options.header
        sourceMap: options.sourceMap
        referencedVars: referencedVars
      result = @compileAst ast, code, compileOptions
    catch err
      throw new Error("Could not compile #{filename} after instrumenting: #{err.stack}")

    # Return the JavaScript.
    return result

exports.instrumentCoffee = (filename, code, coffee, options = {}) ->
  instrumenter = new CoffeeScriptInstrumenter(coffee)
  instrumenter.instrument filename, code, options

