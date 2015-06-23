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

    instrumentedNode.expressions[0]

  createInstrumentedExpr: (traceFunc, locationData, eventType, originalExpr) ->
    parensBlock = @coffee.nodes("(0)").expressions[0]
    parensBlock.base.body.expressions = []
    parensBlock.base.body.expressions[0] = @createInstrumentedNode(traceFunc, locationData, "code")
    parensBlock.base.body.expressions[1] = originalExpr
    parensBlock

  shouldInstrumentNode: (node) ->
    node not instanceof @nodeTypes.IcedRuntime and
    node not instanceof @nodeTypes.Comment and
    node not instanceof @nodeTypes.While and
    node not instanceof @nodeTypes.Switch and
    node not instanceof @nodeTypes.If

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

    # Parse the code to get an AST.
    ast = @coffee.nodes code

    # Instruments the AST recursively. Arguments:
    #   node: the current node of the AST
    #   parent: the parent node, or null if we're on the root node
    #
    instrumentTree = (node, parent=null) =>
      if node instanceof @nodeTypes.Block and parent not instanceof @nodeTypes.Parens and parent not instanceof @nodeTypes.Class
        # Instrument children of Blocks with normal code events.
        children = node.expressions
        childIndex = 0
        while childIndex < children.length
          expression = children[childIndex]

          if @shouldInstrumentNode(expression)
            # Instrument this line with a normal code event.
            instrumentedNode = @createInstrumentedNode(traceFunc, expression.locationData, "code")

            # Insert it before the node it corresponds to, and correct the childIndex.
            children.splice(childIndex, 0, instrumentedNode)
            childIndex++

          # Recursively instrument the children of this node.
          instrumentTree(expression, node) unless expression instanceof @nodeTypes.IcedRuntime

          childIndex++

        # Instrument the first line of for loops, so that the for loop is
        # traced for each iteration.
        if parent instanceof @nodeTypes.For
          instrumentedNode = @createInstrumentedNode(traceFunc, parent.locationData, "code")
          children.unshift(instrumentedNode)

      else if node instanceof @nodeTypes.While
        node.condition = @createInstrumentedExpr(traceFunc, node.locationData, "code", node.condition)

        node.eachChild (child) =>
          instrumentTree(child, node)
      else if node instanceof @nodeTypes.Switch
        node.subject = @createInstrumentedExpr(traceFunc, node.locationData, "code", node.subject)

        for caseClause in node.cases
          caseClause[0] = @createInstrumentedExpr(traceFunc, caseClause[0].locationData, "code", caseClause[0])

        node.eachChild (child) =>
          instrumentTree(child, node)
      else if node instanceof @nodeTypes.If
        node.condition = @createInstrumentedExpr(traceFunc, node.condition.locationData, "code", node.condition)

        node.eachChild (child) =>
          instrumentTree(child, node)
      else if node instanceof @nodeTypes.Code
        # Wrap function bodies with a try..finally block that makes sure "enter"
        # and "leave" events occur for the function, even if an exception is
        # thrown.
        tryBlock = @coffee.nodes("try\nfinally")
        tryNode = tryBlock.expressions[0]

        tryNode.attempt = node.body
        tryBlock.expressions.unshift(@createInstrumentedNode(traceFunc, node.locationData, "enter"))
        tryNode.ensure.expressions.unshift(@createInstrumentedNode(traceFunc, node.locationData, "leave"))

        node.body = tryBlock

        # Proceed to instrument the original function body.
        instrumentTree(tryNode.attempt, tryNode)
      else
        # Recursively instrument each child of this node.
        node.eachChild (child) =>
          instrumentTree(child, node)

        if node.icedContinuationBlock?
          instrumentTree(node.icedContinuationBlock, node)

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
      result = @compileAst ast, code, compileOptions
    catch err
      throw new Error("Could not compile #{filename} after instrumenting: #{err.stack}")

    # Return the JavaScript.
    return result

exports.instrumentCoffee = (filename, code, coffee, options = {}) ->
  instrumenter = new CoffeeScriptInstrumenter(coffee)
  instrumenter.instrument filename, code, options

