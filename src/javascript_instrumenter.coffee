acorn = require "acorn"
escodegen = require "escodegen"

isArray = Array.isArray || (value) -> {}.toString.call(value) is '[object Array]'

class JavaScriptInstrumenter
  constructor: (@options) ->
    @options.traceFunc ?= "pencilTrace"

  temporaryVariable: (base) ->
    name = "_penciltracer_#{base}"
    index = 0
    loop
      curName = name + index
      unless curName in @referencedVars
        @referencedVars.push curName
        return curName
      index++

  createInstrumentedNode: (eventType, options={}) ->
    loc = options.loc ? options.node.loc

    if eventType isnt "leave"
      vars = options.vars ? (if eventType is "enter" then @findArguments(options.node) else @findVariables(options.node))
    if eventType is "after"
      functionCalls = options.functionCalls ? @findFunctionCalls(options.node)

    # Give the column numbers as 1-indexed values, instead of 0-indexed. Line
    # numbers are already 1-indexed.
    locationObj = "{ first_line: #{loc.start.line},"
    locationObj += " first_column: #{loc.start.column + 1},"
    locationObj += " last_line: #{loc.end.line},"
    locationObj += " last_column: #{loc.end.column + 1} }"

    soakify = (name) ->
      if name.indexOf(".") is -1
        "(typeof #{name} === 'undefined' ? void 0 : #{name})"
      else
        # TODO: handle variables like a.b.c, when a or a.b might not be defined.
        throw "todo"

    extra =
      switch eventType
        when "before", "after"
          "vars: [" + ("{name: '#{name}', value: #{soakify(name)}}" for name in vars) + "]"
        when "enter"
          "vars: [" + ("{name: '#{name}', value: #{name}}" for name in vars) + "]"
        when "leave"
          "returnOrThrow: #{options.returnOrThrowVar}"

    if eventType is "after"
      extra += ", functionCalls: [" + ("{name: '#{f.name}', value: #{f.tempVar}}" for f in functionCalls) + "]"

    eventObj = "{location: #{locationObj}, type: '#{eventType}', #{extra}}"

    instrumentedNode =
      acorn.parse("#{@options.traceFunc}(#{eventObj});").body[0]

    instrumentedNode.pencilTracerInstrumented = true
    instrumentedNode.expression.pencilTracerInstrumented = true
    instrumentedNode

  createInstrumentedExpr: (originalExpr) ->
    tempVar = @temporaryVariable "temp"

    sequenceExpr = { type: "SequenceExpression", expressions: [] }
    sequenceExpr.expressions.push @createInstrumentedNode("before", node: originalExpr).expression
    sequenceExpr.expressions.push @createAssignNode(tempVar, originalExpr)
    sequenceExpr.expressions.push @createInstrumentedNode("after", node: originalExpr).expression
    sequenceExpr.expressions.push { type: "Identifier", name: tempVar }
    sequenceExpr

  createAssignNode: (varName, expr) ->
    type: "AssignmentExpression"
    operator: "="
    left:
      type: "Identifier"
      name: varName
    right: expr

  findVariables: (node, vars=[]) ->
    if node.type is "Identifier"
      if vars.indexOf(node.name) is -1
        vars.push node.name

    # TODO: handle consecutive memberexpressions, e.g. `a.b.c`

    for key of node
      #continue if key is "parent"
      continue if node.type is "Property" and key is "key"
      continue if node.type in ["FunctionExpression", "FunctionDeclaration"] and key is "params"
      if isArray(node[key])
        for child in node[key]
          @findVariables(child, vars)
      else if node[key] and typeof node[key].type is "string" and node[key].type not in STATEMENTS
        @findVariables(node[key], vars)

    vars

  findArguments: (funcNode) ->
    (param.name for param in funcNode.params)

  findFunctionCalls: (node, parent=null, grandparent=null, vars=[]) ->
    # TODO. Finish @findVariables() first, this will be very similar.
    []

  mapChildren: (node, func) ->
    for key of node
      if isArray(node[key])
        for child, i in node[key]
          node[key][i] = func(child)
      else
        node[key] = func(node[key])

  instrumentTree: (node, parent=null, returnOrThrowVar) ->
    @mapChildren node, (child) =>
      if child.type in ["EmptyStatement", "ExpressionStatement", "DebuggerStatement", "FunctionDeclaration"]
        type: "BlockStatement"
        body: [@createInstrumentedNode("before", node: child), child, @createInstrumentedNode("after", node: child)]
      else
        child

  instrument: (filename, code) ->
    @referencedVars = []
    ast = acorn.parse code, locations: true, onToken: (token) =>
      if token.type.label is "name" and @referencedVars.indexOf(token.value) is -1
        @referencedVars.push token.value

    @caughtErrorVar = @temporaryVariable("err")

    @instrumentTree ast

    return ast if @options.ast

    escodegen.generate(ast)

exports.instrumentJs = (filename, code, options = {}) ->
  instrumenter = new JavaScriptInstrumenter(options)
  instrumenter.instrument filename, code

