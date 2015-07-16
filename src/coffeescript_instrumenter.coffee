class CoffeeScriptInstrumenter
  # The constructor takes the CoffeeScript module to use to parse the code,
  # generate instrumented code, and compile the result to JavaScript. This lets
  # you instrument Iced CoffeeScript if you want, for example.
  constructor: (@coffee, @options = {}) ->
    if not @coffee?
      throw new Error("A CoffeeScript compiler must be passed to CoffeeScriptInstrumenter!")

    @options.traceFunc ?= "pencilTrace"

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
      icedNodes = @coffee.nodes("if 1\n  await f defer a\n  1")
      awaitNode = icedNodes.expressions[1].body.expressions[0]
      @nodeTypes.IcedRuntime = icedNodes.expressions[0].constructor
      @nodeTypes.Await = awaitNode.constructor
      @nodeTypes.Defer = awaitNode.body.expressions[0].args[0].constructor
      @nodeTypes.Slot = awaitNode.body.expressions[0].args[0].slots[0].constructor
      @nodeTypes.IcedTailCall = awaitNode.icedContinuationBlock.expressions[0].constructor
    else
      # Otherwise assign them to an empty function so we can still use the
      # instanceof operator on them.
      @nodeTypes.IcedRuntime = @nodeTypes.Await = @nodeTypes.Defer = @nodeTypes.Slot = @nodeTypes.IcedTailCall = ->

  # Returns a unique name to use as a temporary variable, by appending a number
  # to the given base name until it gets an identifier that hasn't been used.
  temporaryVariable: (base) ->
    name = "_penciltracer_#{base}"
    index = 0
    loop
      curName = name + index
      unless curName in @referencedVars
        @referencedVars.push curName
        return curName
      index++

  lastNonComment: (list) ->
    i = list.length
    return list[i] while i-- when list[i] not instanceof @nodeTypes.Comment
    null

  # Creates an instrumented node that calls the trace function, passing in the
  # event object.
  createInstrumentedNode: (targetNode, eventType, returnOrThrowVar) ->
    if targetNode instanceof @nodeTypes.IcedTailCall
      targetNode = targetNode.value

    locationData = targetNode.locationData

    # Give the line and column numbers as 1-indexed values, instead of 0-indexed.
    locationObj = "{ first_line: #{locationData.first_line + 1},"
    locationObj += " first_column: #{locationData.first_column + 1},"
    locationObj += " last_line: #{locationData.last_line + 1},"
    locationObj += " last_column: #{locationData.last_column + 1} }"

    extra =
      switch eventType
        when "before", "after"
          "vars: {" + ("#{name}: (if typeof #{name} is 'undefined' then undefined else #{name})" for name in @findVariables(targetNode)) + "}"
        when "enter"
          "vars: {" + ("#{name}: #{name}" for name in @findArguments(targetNode)) + "}"
        when "leave"
          "returnOrThrow: #{returnOrThrowVar}"

    eventObj = "{ location: #{locationObj}, type: '#{eventType}', #{extra} }"

    # Create the node from a string of CoffeeScript.
    instrumentedNode =
      @coffee.nodes("#{@options.traceFunc}(#{eventObj})").expressions[0]

    instrumentedNode.pencilTracerInstrumented = true
    instrumentedNode

  createInstrumentedExpr: (targetNode, originalExpr) ->
    tempVar = @temporaryVariable "temp"

    assignNode = @coffee.nodes("#{tempVar} = 0").expressions[0]
    assignNode.value = originalExpr

    parensBlock = @coffee.nodes("(0)").expressions[0]
    parensBlock.base.body.expressions = []
    parensBlock.base.body.expressions[0] = @createInstrumentedNode(targetNode, "before")
    parensBlock.base.body.expressions[1] = assignNode
    parensBlock.base.body.expressions[2] = @createInstrumentedNode(targetNode, "after")
    parensBlock.base.body.expressions[3] = @coffee.nodes(tempVar).expressions[0]
    parensBlock

  findVariables: (node, parent=null, vars=[]) ->
    return [] if not node

    if node instanceof @nodeTypes.Value and node.base instanceof @nodeTypes.Literal and node.base.isAssignable()
      # Skip properties in object literals, like the 'a' in {a: b}. That's not
      # a variable (but 'b' is).
      skip = parent instanceof @nodeTypes.Assign and parent.context is "object" and parent.variable is node
      if not skip
        if vars.indexOf(node.base.value) is -1
          vars.push node.base.value

    node.eachChild (child) =>
      @findVariables(child, node, vars) unless child instanceof @nodeTypes.Block and node not instanceof @nodeTypes.Parens

    vars

  findArguments: (codeNode) ->
    throw new Error("findArguments() expects a Code node") unless codeNode instanceof @nodeTypes.Code

    args = []
    for paramNode in codeNode.params
      name = paramNode.name
      if name instanceof @nodeTypes.Literal
        # A normal argument.
        args.push name.value
      else if name instanceof @nodeTypes.Value
        # The argument is an @-variable, we won't deal with those for now.
      else
        # Otherwise the argument is an array or object, for destructuring
        # assignment. Here we'll delegate to findVariables(), as it will
        # recursively find all identifiers in the structure.
        args.push.apply(args, @findVariables(name))
    args

  nodeIsObj: (node) ->
    node instanceof @nodeTypes.Value and node.isObject(true)

  nodeIsClassProperty: (node, className) ->
    @nodeIsObj(node) or
    (node instanceof @nodeTypes.Assign and node.variable.looksStatic className) or
    (node instanceof @nodeTypes.Assign and node.variable.this)

  shouldSkipNode: (node) ->
    node.pencilTracerInstrumented or
    node instanceof @nodeTypes.IcedRuntime

  shouldInstrumentNode: (node) ->
    not node.pencilTracerInstrumented and
    node not instanceof @nodeTypes.IcedRuntime and
    (node not instanceof @nodeTypes.IcedTailCall or node.value) and
    node not instanceof @nodeTypes.Comment and
    node not instanceof @nodeTypes.While and
    node not instanceof @nodeTypes.Switch and
    node not instanceof @nodeTypes.If

  compileAst: (ast, originalCode, compileOptions) ->
    # Pilfer the SourceMap class from CoffeeScript...
    SourceMap = @coffee.compile("", sourceMap: true).sourceMap.constructor

    if compileOptions.sourceMap
      map = new SourceMap

    fragments = ast.compileToFragments compileOptions

    currentLine = 0
    currentLine += 1 if compileOptions.header
    currentLine += 1 if compileOptions.shiftLine
    currentColumn = 0
    js = ""
    for fragment in fragments
      if compileOptions.sourceMap
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

    if compileOptions.header
      compilerName = if @coffee.iced? then "IcedCoffeeScript" else "CoffeeScript"
      header = "Generated by #{compilerName} #{@coffee.VERSION} (instrumented by pencil-tracer)"
      js = "// #{header}\n#{js}"

    if compileOptions.sourceMap
      answer = {js}
      answer.sourceMap = map
      answer.v3SourceMap = map.generate(compileOptions, originalCode)
      answer
    else
      js

  # Instruments the AST recursively. Arguments:
  #   node: the current node of the AST
  #   parent: the parent node, or null if we're on the root node
  #   inClass: whether we're traversing the body of a class
  #
  instrumentTree: (node, parent=null, inClass=false, returnOrThrowVar) ->
    return if @shouldSkipNode(node)

    inClass = node if node instanceof @nodeTypes.Class
    inClass = false if @nodeIsObj(node)

    if node instanceof @nodeTypes.Block and parent not instanceof @nodeTypes.Parens
      # Instrument children of Blocks with before events.
      children = node.expressions
      lastChild = @lastNonComment(children)
      childIndex = 0

      # Set up a top level object used for storing results of expressions.
      if not returnOrThrowVar
        returnOrThrowVar = @temporaryVariable "returnOrThrow"
        children.unshift @coffee.nodes("#{returnOrThrowVar} = {}").expressions[0]
        childIndex = 1

      while childIndex < children.length
        expression = children[childIndex]

        if @shouldInstrumentNode(expression)
          beforeNode = @createInstrumentedNode(expression, "before")
          afterNode = @createInstrumentedNode(expression, "after")

          children.splice(childIndex, 0, beforeNode)
          childIndex++
          children.splice(childIndex + 1, 0, afterNode)
          childIndex++

          # Assign the original last expression of the block to a temporary
          # variable, and return that value at the end of the block.
          if expression is lastChild and not expression.jumps() and expression not instanceof @nodeTypes.Await and not (inClass and @nodeIsClassProperty(expression, inClass.determineName()))
            assignNode = @coffee.nodes("#{returnOrThrowVar}.value = 0").expressions[0]
            assignNode.value = expression
            children[childIndex - 1] = assignNode
            children.splice(childIndex + 1, 0, @coffee.nodes("#{returnOrThrowVar}.value").expressions[0])
            children[childIndex + 1].icedHasAutocbFlag = expression.icedHasAutocbFlag
            childIndex++
          else if expression instanceof @nodeTypes.Return
            assignNode = @coffee.nodes("#{returnOrThrowVar}.value = 0").expressions[0]
            assignNode.value = expression.expression || @coffee.nodes("undefined").expressions[0]
            children[childIndex - 1] = assignNode
            children.splice(childIndex + 1, 0, @coffee.nodes("return #{returnOrThrowVar}.value").expressions[0])
            childIndex++
          else if expression instanceof @nodeTypes.Literal and expression.value in ["break", "continue"]
            temp = children[childIndex]
            children[childIndex] = children[childIndex - 1]
            children[childIndex - 1] = temp

        # Recursively instrument the children of this node.
        @instrumentTree(expression, node, inClass, returnOrThrowVar)

        childIndex++

      # Instrument the first line of for loops, so that the for loop is
      # traced for each iteration.
      if parent instanceof @nodeTypes.For
        instrumentedNode = @createInstrumentedNode(parent, "before")
        children.unshift(instrumentedNode)

    else if node instanceof @nodeTypes.While
      node.condition = @createInstrumentedExpr(node, node.condition)

      node.eachChild (child) =>
        @instrumentTree(child, node, inClass, returnOrThrowVar)
    else if node instanceof @nodeTypes.Switch
      if node.subject
        node.subject = @createInstrumentedExpr(node, node.subject)

      for caseClause in node.cases
        if caseClause[0] instanceof Array
          caseClause[0][0] = @createInstrumentedExpr(caseClause[0][0], caseClause[0][0])
        else
          caseClause[0] = @createInstrumentedExpr(caseClause[0], caseClause[0])

      node.eachChild (child) =>
        @instrumentTree(child, node, inClass, returnOrThrowVar)
    else if node instanceof @nodeTypes.If
      node.condition = @createInstrumentedExpr(node.condition, node.condition)

      node.eachChild (child) =>
        @instrumentTree(child, node, inClass, returnOrThrowVar)
    else if node instanceof @nodeTypes.Code
      returnOrThrowVar = @temporaryVariable "returnOrThrow"

      # Wrap function bodies with a try..finally block that makes sure "enter"
      # and "leave" events occur for the function, even if an exception is
      # thrown.
      block = @coffee.nodes """
        #{returnOrThrowVar} = { type: 'return', value: undefined }
        try
        catch #{@caughtErrorVar}
          #{returnOrThrowVar}.type = 'throw'
          #{returnOrThrowVar}.value = #{@caughtErrorVar}
          throw #{@caughtErrorVar}
        finally
      """
      tryNode = block.expressions[1]

      tryNode.attempt = node.body
      block.expressions.unshift(@createInstrumentedNode(node, "enter"))
      tryNode.ensure.expressions.unshift(@createInstrumentedNode(node, "leave", returnOrThrowVar))

      node.body = block

      # Proceed to instrument the original function body.
      @instrumentTree(tryNode.attempt, tryNode, inClass, returnOrThrowVar)
    else
      # Recursively instrument each child of this node.
      node.eachChild (child) =>
        @instrumentTree(child, node, inClass, returnOrThrowVar)

      if node.icedContinuationBlock?
        @instrumentTree(node.icedContinuationBlock, node, inClass, returnOrThrowVar)

  # Instruments some CoffeeScript code, compiles to JavaScript, and returns the
  # JavaScript code.
  instrument: (filename, code) ->
    csOptions =
      runtime: "inline" # for Iced CoffeeScript, includes the runtime in the output
      bare: @options.bare
      header: @options.header
      sourceMap: @options.sourceMap
      literate: @options.literate

    # Get a list of referenced variables so that generated variables won't get
    # the same name.
    @referencedVars = csOptions.referencedVars =
      (token[1] for token in @coffee.tokens(code, csOptions) when token.variable)

    @caughtErrorVar = @temporaryVariable("err")

    # Parse the code to get an AST.
    ast = @coffee.nodes code, csOptions

    # Instrument the whole AST.
    @instrumentTree ast

    # If caller just wants the AST, return it now.
    return ast if @options.ast

    # Compile the instrumented AST to JavaScript.
    result = @compileAst ast, code, csOptions

    # Return the JavaScript.
    return result

exports.instrumentCoffee = (filename, code, coffee, options = {}) ->
  instrumenter = new CoffeeScriptInstrumenter(coffee, options)
  instrumenter.instrument filename, code

