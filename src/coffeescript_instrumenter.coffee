# Helper to check whether a value is an Array.
isArray = Array.isArray || (value) -> {}.toString.call(value) is '[object Array]'

class CoffeeScriptInstrumenter
  # The constructor takes the CoffeeScript module to use to parse the code,
  # generate instrumented code, and compile the result to JavaScript. This lets
  # you instrument Iced CoffeeScript if you want, for example.
  #
  # Options:
  #   * `traceFunc`: the name of the function to call for each trace event.
  #     (Default: "pencilTrace")
  constructor: (@coffee, @options = {}) ->
    if not @coffee?
      throw new Error("A CoffeeScript compiler must be passed to CoffeeScriptInstrumenter!")

    @options.traceFunc ?= "pencilTrace"

    @getNodeTypes()

  # Get the constructor for each possible node type in the AST. This is
  # used to identify the type of each node in the AST, since we can't depend
  # on constructor.name if the coffee-script library is minified.
  getNodeTypes: ->
    # Constructors that aren't currently used by this file are commented out.
    @nodeTypes =
      'Block': @coffee.nodes("").constructor
      'Literal': @coffee.nodes("0").expressions[0].base.constructor
      #'Undefined': @coffee.nodes("undefined").expressions[0].base.constructor
      #'Null': @coffee.nodes("null").expressions[0].base.constructor
      #'Bool': @coffee.nodes("true").expressions[0].base.constructor
      'Return': @coffee.nodes("return").expressions[0].constructor
      'Value': @coffee.nodes("0").expressions[0].constructor
      'Comment': @coffee.nodes("###\n###").expressions[0].constructor
      'Call': @coffee.nodes("f()").expressions[0].constructor
      #'Extends': @coffee.nodes("A extends B").expressions[0].constructor
      'Access': @coffee.nodes("a.b").expressions[0].properties[0].constructor
      #'Index': @coffee.nodes("a[0]").expressions[0].properties[0].constructor
      #'Range': @coffee.nodes("[0..1]").expressions[0].base.constructor
      #'Slice': @coffee.nodes("a[0..1]").expressions[0].properties[0].constructor
      #'Obj': @coffee.nodes("{}").expressions[0].base.constructor
      #'Arr': @coffee.nodes("[]").expressions[0].base.constructor
      'Class': @coffee.nodes("class").expressions[0].constructor
      'Assign': @coffee.nodes("a=0").expressions[0].constructor
      'Code': @coffee.nodes("->").expressions[0].constructor
      'Param': @coffee.nodes("(a)->").expressions[0].params[0].constructor
      #'Splat': @coffee.nodes("[a...]").expressions[0].base.objects[0].constructor
      #'Expansion': @coffee.nodes("[...]").expressions[0].base.objects[0].constructor
      'While': @coffee.nodes("0 while true").expressions[0].constructor
      'Op': @coffee.nodes("1+1").expressions[0].constructor
      #'In': @coffee.nodes("0 in []").expressions[0].constructor
      'Try': @coffee.nodes("try").expressions[0].constructor
      'Throw': @coffee.nodes("throw 0").expressions[0].constructor
      #'Existence': @coffee.nodes("a?").expressions[0].constructor
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

  # Gets the last item of the given array that isn't a Comment node. This is
  # used when determining the value of a Block.
  lastNonComment: (list) ->
    i = list.length
    return list[i] while i-- when list[i] not instanceof @nodeTypes.Comment
    null

  # Recognizes function definitions. An assignment statement is a function
  # definition when the left hand side is a plain variable and the right hand
  # side is an anonymous function.
  isFunctionDef: (node) ->
    node instanceof @nodeTypes.Assign and
    not node.context and
    node.variable instanceof @nodeTypes.Value and
    node.variable.base instanceof @nodeTypes.Literal and
    node.variable.properties.length is 0 and
    node.value instanceof @nodeTypes.Code

  # Takes a variable or simple member expression as a string, e.g. "a.b.c", and
  # returns an expression that safely gets the value of the expression even if
  # "a"  or "a.b" are undefined.
  soakify: (name) ->
    if name.indexOf(".") is -1
      # Single variables have to be checked for existence before using them.
      "(if typeof #{name} is 'undefined' then undefined else #{name})"
    else
      # For member expressions like "a.b.c", convert to "a?.b?.c" which uses
      # CoffeeScript's soak operator.
      name.replace /\./g, "?."

  # Escape backslashes, single quotes, and newlines, so that the string can be
  # used in a CoffeeScript string literal.
  quoteString: (str) ->
    str.replace(/\\/g, "\\\\").replace(/'/g, "\\'").replace(/\n/g, "\\n")

  # Creates a node that calls the trace function, passing in the event object.
  # If no `node` option is given, then the `location`, `vars`, and (for 'after'
  # events) `functionCalls` options must be given. If a `node` is given, then
  # those options may be given to override the default behaviour.
  #
  # eventType can be 'before', 'after', 'enter', or 'leave'.
  #
  # Options:
  #   * `node`: The node associated with this trace event.
  #   * `location`: The location in the source file associated with this event.
  #     (Default: the location of the `node`)
  #   * `vars`: A list of variable names associated with this event. (Default:
  #     finds all variables used in the `node`)
  #   * `functionCalls`: A list of function calls associated with this event.
  #     (Default: finds all function calls in the `node`)
  #   * `returnOrThrowVar`: the name of the variable containing the return
  #     value or thrown error, in the case of a 'leave' event.
  createInstrumentedNode: (eventType, options={}) ->
    # If trying to instrument an IcedTailCall node, instrument its child node
    # instead.
    if options.node instanceof @nodeTypes.IcedTailCall
      options.node = options.node.value

    location = options.location ? options.node.locationData
    if eventType isnt "leave"
      vars = options.vars ? (if eventType is "enter" then @findArguments(options.node) else @findVariables(options.node))
    if eventType is "after"
      functionCalls = options.functionCalls ? @findFunctionCalls(options.node)

    # Give the line and column numbers as 1-indexed values, instead of 0-indexed.
    locationObj = "{ first_line: #{location.first_line + 1},"
    locationObj += " first_column: #{location.first_column + 1},"
    locationObj += " last_line: #{location.last_line + 1},"
    locationObj += " last_column: #{location.last_column + 1} }"

    extra =
      switch eventType
        when "before", "after"
          funcDef = if @isFunctionDef(options.node) then ", functionDef: true" else ""
          "vars: [" + ("{name: '#{name}', value: #{@soakify(name)} #{funcDef}}" for name in vars) + "]"
        when "enter"
          "vars: [" + ("{name: '#{name}', value: #{name}}" for name in vars) + "]"
        when "leave"
          "returnOrThrow: #{options.returnOrThrowVar}"

    if eventType is "after"
      if @options.includeArgsStrings
        extra += ", functionCalls: [" + ("{name: '#{f.name}', value: #{f.tempVar}, argsString: '#{@quoteString(f.argsString)}'}" for f in functionCalls) + "]"
      else
        extra += ", functionCalls: [" + ("{name: '#{f.name}', value: #{f.tempVar}}" for f in functionCalls) + "]"

    eventObj = "{ location: #{locationObj}, type: '#{eventType}', #{extra} }"

    # Create the node from a string of CoffeeScript.
    instrumentedNode =
      @coffee.nodes("#{@options.traceFunc}(#{eventObj})").expressions[0]

    # Mark the instrumented node as having been instrumented.
    instrumentedNode.pencilTracerInstrumented = true

    instrumentedNode

  # Creates an expression that wraps the `originalExpr` between a 'before' and
  # 'after' event. For example, "x = 3" would become
  # "(pencilTrace('before', ...); _temp = x = 3; pencilTrace('after', ...); _temp)"
  # which is still an expression that can be used anywhere the original
  # expression could be used.
  createInstrumentedExpr: (originalExpr) ->
    tempVar = @temporaryVariable "temp"

    parensBlock = @coffee.nodes("(0)").expressions[0]
    parensBlock.base.body.expressions = []
    parensBlock.base.body.expressions[0] = @createInstrumentedNode("before", node: originalExpr)
    parensBlock.base.body.expressions[1] = @createAssignNode(tempVar, originalExpr)
    parensBlock.base.body.expressions[2] = @createInstrumentedNode("after", node: originalExpr)
    parensBlock.base.body.expressions[3] = @coffee.nodes(tempVar).expressions[0]
    parensBlock

  # Creates an Assign node that assigns the given `valueNode` to the `varName`
  # variable.
  createAssignNode: (varName, valueNode) ->
    assignNode = @coffee.nodes("#{varName} = 0").expressions[0]
    assignNode.value = valueNode
    assignNode

  # Finds every variable (e.g. "a") and simple member expression (e.g. "a.b.c")
  # used in a statement or expression.
  findVariables: (node, parent=null, vars=[]) ->
    # If we have a variable or member expression...
    if node instanceof @nodeTypes.Value and node.base instanceof @nodeTypes.Literal and node.base.isAssignable()
      # Skip properties in object literals, like the 'a' in {a: b}. That's not
      # a variable (but 'b' is).
      skip = parent instanceof @nodeTypes.Assign and parent.context is "object" and parent.variable is node

      # Skip variables used as function calls, as function call tracking will
      # take care of those.
      skip ||= parent instanceof @nodeTypes.Call and parent.variable is node and node.properties.length is 0
      if not skip
        # Get the full variable name, e.g. get "@a.b" for the expression
        # "@a.b[0].c"
        name = if node.this then "@" else "#{node.base.value}."
        lastProp = node.properties[node.properties.length - 1]
        for prop in node.properties
          break if prop not instanceof @nodeTypes.Access or prop.soak or (prop is lastProp and parent instanceof @nodeTypes.Call and parent.variable is node)

          name += "#{prop.name.value}."
        name = name.slice(0, -1) unless name is "@"

        # Append variable to vars if we haven't already.
        if vars.indexOf(name) is -1
          vars.push name

    # Recursively search the children of this node, with some exceptions.
    node.eachChild (child) =>
      # Skip Blocks of code, unless it's the Block of a Parens node, which is
      # like the JavaScript comma operator and should be instrumented as one
      # unit of code.
      skip = child instanceof @nodeTypes.Block and node not instanceof @nodeTypes.Parens

      # Skip functions.
      skip ||= child instanceof @nodeTypes.Code

      # Skip nodes that we generated ourselves, as well as some other nodes
      # that we happen to not want to instrument?? (TODO: figure this out.)
      skip ||= not @shouldInstrumentNode(child)

      # Skip Iced CoffeeScript deferred variables, as they are hard to handle. (TODO!)
      skip ||= node instanceof @nodeTypes.Defer

      if not skip
        @findVariables(child, node, vars)

    vars

  # Takes a Code node and finds all variables used in the parameters of the
  # function.
  findArguments: (codeNode) ->
    throw new Error("findArguments() expects a Code node") unless codeNode instanceof @nodeTypes.Code

    args = []
    for paramNode in codeNode.params
      # Skip Expansion nodes, as in "(a, ..., b) ->".
      if paramNode instanceof @nodeTypes.Param
        name = paramNode.name
        if name instanceof @nodeTypes.Literal
          # A normal argument.
          args.push name.value
        else if name instanceof @nodeTypes.Value
          # The argument is an @-variable.
          args.push "@#{name.properties[0].name.value}"
        else
          # Otherwise the argument is an array or object, for destructuring
          # assignment. Here we'll delegate to findVariables(), as it will
          # recursively find all identifiers in the structure.
          args.push.apply(args, @findVariables(name))

    args

  # Takes a location object and returns the substring at that location in the
  # original source file.
  substringByLocation: (location) ->
    result = ""
    for lineNum in [location.first_line..location.last_line]
      result +=
        if lineNum is location.first_line and lineNum is location.last_line
          @lines[lineNum][location.first_column..location.last_column]
        else if lineNum is location.first_line
          @lines[lineNum][location.first_column..]
        else if lineNum is location.last_line
          @lines[lineNum][..location.last_column]
        else
          @lines[lineNum]
    result

  # Converts a list of argument nodes to a string containing the original
  # source of each argument, separated by commas.
  argsToString: (argNodes) ->
    (@substringByLocation(arg.locationData) for arg in argNodes).join(", ")

  # Finds each function call in a statement or expression.
  findFunctionCalls: (node, parent=null, grandparent=null, funcs=[]) ->
    # Check if this node is a function call. Skip function calls preceded by
    # the `new` operator, for now. (TODO!)
    if node instanceof @nodeTypes.Call and not (grandparent instanceof @nodeTypes.Op and grandparent.operator is "new")
      # Check for soaks. TODO: support "soaked" function calls.
      soak = node.soak
      if node.variable instanceof @nodeTypes.Value
        for prop in node.variable.properties
          soak ||= prop.soak

      unless soak
        # Get the function name, e.g. "func" for the expression "a.func()".
        name = "<anonymous>"
        if node.isSuper
          name = "super"
        else if node.variable instanceof @nodeTypes.Value
          if node.variable.properties.length > 0
            lastProp = node.variable.properties[node.variable.properties.length - 1]
            if lastProp instanceof @nodeTypes.Access
              name = lastProp.name.value
          else if node.variable.base instanceof @nodeTypes.Literal
            name = node.variable.base.value

        # Create a temporary variable to store the return value in.
        node.pencilTracerReturnVar = @temporaryVariable("returnVar")

        # Append the function call info to funcs.
        funcs.push {name: name, tempVar: node.pencilTracerReturnVar, argsString: @argsToString(node.args)}

    # Recursively search the children of this node, with some exceptions.
    node.eachChild (child) =>
      # Skip Blocks of code, unless it's the Block of a Parens node, which is
      # like the JavaScript comma operator and should be instrumented as one
      # unit of code.
      skip = child instanceof @nodeTypes.Block and node not instanceof @nodeTypes.Parens

      # Skip functions.
      skip ||= child instanceof @nodeTypes.Code

      # Skip nodes that we generated ourselves, as well as some other nodes
      # that we happen to not want to instrument?? (TODO: figure this out.)
      skip ||= not @shouldInstrumentNode(child)

      if not skip
        @findFunctionCalls(child, node, parent, funcs)

    funcs

  # Returns true if the node is a Value containing an object literal.
  nodeIsObj: (node) ->
    node instanceof @nodeTypes.Value and node.isObject(true)

  # Returns true if this node defines a class property when used inside a
  # class definition.
  nodeIsClassProperty: (node, className) ->
    @nodeIsObj(node) or
    (node instanceof @nodeTypes.Assign and node.variable.looksStatic className) or
    (node instanceof @nodeTypes.Assign and node.variable.this)

  # Returns true if the node is not part of the original source file, and
  # should be skipped entirely.
  shouldSkipNode: (node) ->
    node.pencilTracerInstrumented or
    node instanceof @nodeTypes.IcedRuntime

  # Returns true for any node that should be wrapped in before and after
  # events. Many nodes are exceptions, such as loops and if statements, because
  # they will have their condition expressions instrumented instead of the
  # entire loop or if statement itself.
  shouldInstrumentNode: (node) ->
    not @shouldSkipNode(node) and
    (node not instanceof @nodeTypes.IcedTailCall or node.value instanceof @nodeTypes.Value) and
    node not instanceof @nodeTypes.Comment and
    node not instanceof @nodeTypes.For and
    node not instanceof @nodeTypes.While and
    node not instanceof @nodeTypes.Switch and
    node not instanceof @nodeTypes.If and
    node not instanceof @nodeTypes.Class and
    node not instanceof @nodeTypes.Try and
    node not instanceof @nodeTypes.Await

  # Helper for @mapChildren() that handles arrays of children.
  mapChildrenArray: (children, func) ->
    for child, index in children
      if isArray(child)
        @mapChildrenArray(child, func)
      else
        children[index] = func(child)

  # Maps over a node's children recursively, replacing each `child` node with
  # the result of `func(child)`.
  mapChildren: (node, func) ->
    childrenAttrs = node.children.slice()
    childrenAttrs.push "icedContinuationBlock"
    for attr in childrenAttrs when node[attr]
      if isArray(node[attr])
        @mapChildrenArray(node[attr], func)
      else
        node[attr] = func(node[attr])

  # Compiles the AST to JavaScript. This code is mostly copied from the
  # CoffeeScript compiler. There is currently no way to both compile an
  # instrumented CoffeeScript AST *and* get a SourceMap with it, using
  # CoffeeScript's API.
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
      code: js
      map: map.generate(compileOptions, originalCode)
    else
      js

  # Instruments the AST recursively.
  #
  # Arguments:
  #   * `node`: the current node of the AST
  #   * `parent`: the parent node, or null if we're on the root node
  #   * `inClass`: whether we're traversing the body of a class
  #   * `returnOrThrowVar`: the name of the variable used to track the return
  #     value or thrown error of the current function.
  instrumentTree: (node, parent=null, inClass=false, returnOrThrowVar) ->
    # Skip nodes that aren't part of the original source file, like nodes we
    # inserted ourselves, and the IcedRuntime node in Iced CoffeeScript
    # programs.
    return if @shouldSkipNode(node)

    # Keep track of whether we're in a class body, which changes the meaning of
    # some nodes like object literals.
    inClass = node if node instanceof @nodeTypes.Class
    inClass = false if @nodeIsObj(node)

    # Some special cases below will recurse over only certain child nodes and
    # then set recursed to true. If recursed is still false at the end of the
    # function, then we'll recurse over all child nodes.
    recursed = false
    if node instanceof @nodeTypes.Block and parent not instanceof @nodeTypes.Parens
      # In CoffeeScript, the "statements" we want to instrument are children of
      # Blocks. The exception is when a Block is the child of a Parens, which
      # is similar to the comma operator in JavaScript.

      children = node.expressions

      # CoffeeScript Blocks are expressions whose value is the value of the
      # last non-Comment node in the Block. When inserting instrumented nodes
      # into the Block, we have to be careful to preserve this "return" value
      # by assigning it to a temporary variable and sticking that variable at
      # then end of the block.
      lastChild = @lastNonComment(children)

      childIndex = 0

      # Set up a top level object used for storing results of expressions.
      if not returnOrThrowVar
        returnOrThrowVar = @temporaryVariable "returnOrThrow"
        children.unshift @coffee.nodes("#{returnOrThrowVar} = {}").expressions[0]
        childIndex = 1

      # Iterate through the children.
      while childIndex < children.length
        expression = children[childIndex]

        # If a class body contains an object literal that defines more than one
        # method on the class, divide that object literal up into multiple
        # object literals, one for each method. That way we can instrument
        # each method definition separately.
        if inClass and @nodeIsObj(expression) and expression.base.properties.length > 1
          children.splice(childIndex, 1)
          for prop, i in expression.base.properties
            objValue = @coffee.nodes("{}").expressions[0]
            objValue.locationData = objValue.base.locationData = prop.locationData
            objValue.base.properties = objValue.base.objects = [prop]
            objValue.base.generated = expression.base.generated
            children.splice(childIndex + i, 0, objValue)
          expression = children[childIndex]

        # If it's not a special case handled below...
        if @shouldInstrumentNode(expression)
          beforeNode = @createInstrumentedNode("before", node: expression)
          afterNode = @createInstrumentedNode("after", node: expression)

          # Insert instrumented nodes before and after the child node.
          children.splice(childIndex, 0, beforeNode)
          childIndex++
          children.splice(childIndex + 1, 0, afterNode)
          childIndex++

          # If it's a tracked function call, assign the result to a variable.
          if expression.pencilTracerReturnVar
            children[childIndex - 1] = @createAssignNode(expression.pencilTracerReturnVar, expression)

          if expression instanceof @nodeTypes.Return
            # Convert bare return statements to return undefined explicitly, so
            # we have a Value node to work with.
            returnValue = expression.expression || @coffee.nodes("undefined").expressions[0]

            # If the returned expression is a tracked function call, assign its
            # value to a variable.
            returnValue = @createAssignNode(returnValue.pencilTracerReturnVar, returnValue) if returnValue.pencilTracerReturnVar

            # Assign the return value to the returnOrThrowVar, and replace the
            # return statement with this assignment statement.
            children[childIndex - 1] = @createAssignNode("#{returnOrThrowVar}.value", returnValue)

            # Now put a return statement that returns the result after the
            # 'after' event.
            children.splice(childIndex + 1, 0, @coffee.nodes("return #{returnOrThrowVar}.value").expressions[0])
            childIndex++
          else if expression instanceof @nodeTypes.Throw
            # Throw statements are handled pretty much the same as Return
            # statements above.
            #
            # Just using returnOrThrowVar as a temporary variable here. It and
            # returnOrThrowVar.type will be set in the catch block.
            thrownValue = expression.expression
            thrownValue = @createAssignNode(thrownValue.pencilTracerReturnVar, thrownValue) if thrownValue.pencilTracerReturnVar
            children[childIndex - 1] = @createAssignNode("#{returnOrThrowVar}.value", thrownValue)
            children.splice(childIndex + 1, 0, @coffee.nodes("throw #{returnOrThrowVar}.value").expressions[0])
            childIndex++
          else if expression instanceof @nodeTypes.Literal and expression.value in ["break", "continue"]
            # Since these jump immediately and have no side effects on
            # variables, we want to swap the child node and the 'after' event,
            # so that the 'after' event actually comes before the child node.
            temp = children[childIndex]
            children[childIndex] = children[childIndex - 1]
            children[childIndex - 1] = temp
          else if expression is lastChild and not expression.jumps() and expression not instanceof @nodeTypes.Await and not (inClass and @nodeIsClassProperty(expression, inClass.determineName())) and not (parent instanceof @nodeTypes.Try and parent.ensure is node)
            # Here we have an expression whose value determines the value of
            # the whole Block. The complicated if condition above is making
            # sure it is an expression and not a valueless statement.

            # Assign the original last expression of the block to a temporary
            # variable, and return that value at the end of the block.
            children[childIndex - 1] = @createAssignNode("#{returnOrThrowVar}.value", children[childIndex - 1])
            children.splice(childIndex + 1, 0, @coffee.nodes("#{returnOrThrowVar}.value").expressions[0])
            children[childIndex + 1].icedHasAutocbFlag = expression.icedHasAutocbFlag
            childIndex++

        # Recursively instrument the children of this node.
        @instrumentTree(expression, node, inClass, returnOrThrowVar)

        childIndex++

      recursed = true
    else if node instanceof @nodeTypes.For
      # Instrument each expression in the head of the for loop.
      node.source = @createInstrumentedExpr(node.source) unless node.range
      node.guard = @createInstrumentedExpr(node.guard) if node.guard
      node.step = @createInstrumentedExpr(node.step) if node.step

      # Takes a node used as the "name" or "index" of a for loop, which can
      # either be a single variable or a pattern structure with multiple
      # variables, and returns an array of all the variable names found.
      getVars = (n) =>
        if n instanceof @nodeTypes.Literal
          [n.value]
        else
          @findVariables(n)

      # A for loop can have a "name" variable/pattern, an "index"
      # variable/pattern, or both, or neither. For each of these four cases we
      # want to get a list of the variables for variable tracking, and a
      # location.
      if node.name and node.index
        if node.object
          location =
            first_line: node.name.locationData.first_line
            first_column: node.name.locationData.first_column
            last_line: node.index.locationData.last_line
            last_column: node.index.locationData.last_column
        else
          location =
            first_line: node.index.locationData.first_line
            first_column: node.index.locationData.first_column
            last_line: node.name.locationData.last_line
            last_column: node.name.locationData.last_column
        vars = getVars(node.name).concat(getVars(node.index))
      else if node.name
        location = node.name.locationData
        vars = getVars(node.name)
      else if node.index
        location = node.index.locationData
        vars = getVars(node.index)
      else
        location = node.locationData
        vars = []

      before = @createInstrumentedNode("before", location: location, vars: vars)
      after = @createInstrumentedNode("after", location: location, vars: vars, functionCalls: [])

      if node.guard
        # If there is a `when` guard, put the before and after events for the
        # loop in the guard so that they come before the before and after
        # events of the guard itself.
        parensBlock = @coffee.nodes("(0)").expressions[0]
        parensBlock.base.body.expressions = [before, after, node.guard]
        node.guard = parensBlock
      else
        # Otherwise we can just put them at the top of the loop body.
        node.body.expressions.unshift(before, after)
    else if node instanceof @nodeTypes.While
      # Instrument the loop condition, and the guard if one exists.
      node.condition = @createInstrumentedExpr(node.condition)
      node.guard = @createInstrumentedExpr(node.guard) if node.guard
    else if node instanceof @nodeTypes.Switch
      # Instrument the expression being switched on, if one exists.
      node.subject = @createInstrumentedExpr(node.subject) if node.subject

      # Instrument each case expression.
      for caseClause in node.cases
        if isArray(caseClause[0])
          caseClause[0][0] = @createInstrumentedExpr(caseClause[0][0])
        else
          caseClause[0] = @createInstrumentedExpr(caseClause[0])
    else if node instanceof @nodeTypes.If
      # Instrument the if condition.
      node.condition = @createInstrumentedExpr(node.condition)
    else if node instanceof @nodeTypes.Class
      # Put both events at the top of the class body.
      before = @createInstrumentedNode("before", node: node)
      after = @createInstrumentedNode("after", node: node)

      node.body.expressions.unshift(before, after)
    else if node instanceof @nodeTypes.Try
      # Only instrument the `catch` part of the Try.
      if node.recovery and node.errorVariable
        # The error variable can be either a single variable or a
        # destructuring pattern.
        if node.errorVariable instanceof @nodeTypes.Literal
          vars = [node.errorVariable.value]
        else
          vars = @findVariables(node.errorVariable)

        before = @createInstrumentedNode("before", node: node.errorVariable, vars: vars)
        after = @createInstrumentedNode("after", node: node.errorVariable, vars: vars, functionCalls: [])

        node.recovery.expressions.unshift(before, after)
    else if node instanceof @nodeTypes.Code
      # Create a new returnOrThrow variable for each function.
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
      block.expressions.unshift(@createInstrumentedNode("enter", node: node))
      tryNode.ensure.expressions.unshift(@createInstrumentedNode("leave", node: node, returnOrThrowVar: returnOrThrowVar))

      node.body = block

      @instrumentTree(tryNode.attempt, tryNode, inClass, returnOrThrowVar)
      recursed = true

    # Recursively instrument each child of this node (unless we already did it
    # for a special case above).
    unless recursed
      @mapChildren node, (child) =>
        ret = child
        if child.pencilTracerReturnVar
          # Track function call return values.
          ret = @createAssignNode(child.pencilTracerReturnVar, child)
        @instrumentTree(child, node, inClass, returnOrThrowVar)
        ret

  # Instruments some CoffeeScript code, compiles to JavaScript, and returns the
  # JavaScript code.
  instrument: (code) ->
    # Options to pass to the CoffeeScript compiler.
    csOptions =
      runtime: "inline" # for Iced CoffeeScript, includes the runtime in the output
      bare: @options.bare
      header: @options.header
      sourceMap: @options.sourceMap
      literate: @options.literate

    # Store the lines of the program in an array, to be used by
    # @substringByLocation().
    @lines = code.match(/^.*((\r\n|\n|\r)|$)/gm)

    # Get a list of referenced variables so that generated variables won't get
    # the same name.
    @referencedVars = csOptions.referencedVars =
      (token[1] for token in @coffee.tokens(code, csOptions) when token.variable)

    # This variable will be used in each function's instrumented try..catch
    # statement.
    @caughtErrorVar = @temporaryVariable("err")

    # Parse the code to get an AST.
    ast = @coffee.nodes code, csOptions

    # Instrument the AST.
    @instrumentTree ast

    # If caller just wants the AST, return it now.
    return ast if @options.ast

    # Compile the instrumented AST to JavaScript.
    result = @compileAst ast, code, csOptions

    # Return the JavaScript.
    return result

# Instruments a CoffeeScript program, returning compiled JavaScript.
#
# Arguments:
#   * `code`: the CoffeeScript code to instrument.
#   * `coffee`: the CoffeeScript compiler to use. This allows you to use a
#     particular version of CoffeeScript, including Iced CoffeeScript.
#
# Options:
#   * `traceFunc`: the function that will be called for each event.
#     (Default: 'pencilTrace')
#   * `ast`: if true, returns the instrumented AST instead of the compiled
#     JavaScript. (Default: false)
#   * `bare`: if true, tells CoffeeScript not to wrap the output in a top-level
#     function. (Default: false)
#   * `sourceMap`: if true, returns a source map as well as the instrumented
#     code. The return value will be an object with `code` and `map`
#     properties. (Default: false)
#   * `includeArgsStrings`: if true, each tracked function call will include a
#     string containing the arguments passed to the function. (Default: false)
exports.instrumentCoffee = (code, coffee, options = {}) ->
  instrumenter = new CoffeeScriptInstrumenter(coffee, options)
  instrumenter.instrument code

