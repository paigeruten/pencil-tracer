acorn = require "acorn"
escodegen = require "escodegen"

FIND_VARIABLES_IN =
  ["ThisExpression", "ArrayExpression", "ObjectExpression", "Property",
   "SequenceExpression", "UnaryExpression", "BinaryExpression",
   "AssignmentExpression", "UpdateExpression", "LogicalExpression",
   "ConditionalExpression", "CallExpression", "NewExpression",
   "MemberExpression", "Identifier", "VariableDeclarator"]

isArray = Array.isArray || (value) -> {}.toString.call(value) is '[object Array]'

class JavaScriptInstrumenter
  constructor: (@options) ->
    @options.traceFunc ?= "pencilTrace"

  temporaryVariable: (base, needsDeclaration=false) ->
    name = "_penciltracer_#{base}"
    index = 0
    loop
      curName = name + index
      unless curName in @referencedVars
        @referencedVars.push curName
        @undeclaredVars.push curName if needsDeclaration
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
      soakified = ""
      closeParens = ""
      parts = name.split "."
      for i in [0...parts.length]
        expr = parts[0..i].join(".")
        if i is 0
          expr = "(typeof #{expr} === 'undefined' ? void 0 : #{expr})"

        if i is parts.length - 1
          soakified += expr
        else
          soakified += "((typeof #{expr} === 'undefined' || #{expr} === null) ? #{expr} : "
          closeParens += ")"
      soakified + closeParens

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

  createInstrumentedExpr: (originalExpr, tempVar=null) ->
    if tempVar is null
      tempVar = @temporaryVariable "temp", true

    sequenceExpr = { type: "SequenceExpression", expressions: [] }
    sequenceExpr.expressions.push @createInstrumentedNode("before", node: originalExpr).expression
    sequenceExpr.expressions.push @createAssignNode(tempVar, originalExpr)
    sequenceExpr.expressions.push @createInstrumentedNode("after", node: originalExpr).expression
    sequenceExpr.expressions.push { type: "Identifier", name: tempVar }
    sequenceExpr

  createAssignNode: (varName, expr, asStatement=false) ->
    node = acorn.parse("#{varName} = 0;").body[0]
    node.expression.right = expr
    node.expression.left.pencilTracerGenerated = true

    if asStatement then node else node.expression

  createReturnNode: (varName) ->
    acorn.parse("return #{varName};", allowReturnOutsideFunction: true).body[0]

  createUndefinedNode: ->
    acorn.parse("void 0").body[0].expression

  findVariables: (node, parent=null, vars=[]) ->
    return [] if node.pencilTracerGenerated

    if node.type in ["Identifier", "ThisExpression"]
      name = if node.type is "ThisExpression" then "this" else node.name
      if vars.indexOf(name) is -1
        vars.push name
    else if node.type is "MemberExpression" and not node.computed
      curNode = node
      parts = []
      while curNode.type is "MemberExpression" and not curNode.computed
        parts.unshift curNode.property.name
        curNode = curNode.object
      if curNode.type in ["Identifier", "ThisExpression"]
        ident = if curNode.type is "ThisExpression" then "this" else curNode.name
        parts.unshift ident
        parts.pop() if parent.type in ["CallExpression", "NewExpression"] and parent.callee is node
        name = parts.join(".")
        if vars.indexOf(name) is -1
          vars.push name

    for key of node
      continue if node.type is "Property" and key is "key"
      continue if node.type in ["FunctionExpression", "FunctionDeclaration"] and key is "params"
      continue if node.type is "MemberExpression" and key is "property" and not node.computed
      continue if node.type is "MemberExpression" and key is "object" and node[key].type in ["Identifier", "ThisExpression"] and not node.computed
      continue if node.type in ["CallExpression", "NewExpression"] and key is "callee" and node[key].type in ["ThisExpression", "Identifier"]
      if isArray(node[key])
        for child in node[key]
          @findVariables(child, node, vars) if child.type in FIND_VARIABLES_IN
      else if node[key] and typeof node[key].type is "string"
        @findVariables(node[key], node, vars) if node[key].type in FIND_VARIABLES_IN

    vars

  findArguments: (funcNode) ->
    (param.name for param in funcNode.params)

  findFunctionCalls: (node, vars=[]) ->
    if node.pencilTracerReturnVar
      name =
        if node.callee.type is "ThisExpression"
          "this"
        else if node.callee.type is "Identifier"
          node.callee.name
        else if node.callee.type is "MemberExpression" and not node.callee.computed
          node.callee.property.name
        else
          "<anonymous>"

      vars.push {name: name, tempVar: node.pencilTracerReturnVar}

    for key of node
      if isArray(node[key])
        for child in node[key]
          @findFunctionCalls(child, vars) if child.type in FIND_VARIABLES_IN
      else if node[key] and typeof node[key].type is "string"
        @findFunctionCalls(node[key], vars) if node[key].type in FIND_VARIABLES_IN

    vars

  shouldInstrumentWithBlock: (node, parent) ->
    node.type in ["EmptyStatement", "ExpressionStatement", "DebuggerStatement", "VariableDeclaration", "FunctionDeclaration"] and
    # Exclude variable declarations in for statements
    not (parent.type is "ForStatement" and parent.init is node) and
    not (parent.type is "ForInStatement" and parent.left is node) and
    # Exclude single-statement bodies of for-in statements, as those are a special case.
    not (parent.type is "ForInStatement" and parent.body is node)

  shouldInstrumentExpr: (node, parent) ->
    (parent.type is "IfStatement" and parent.test is node) or
    (parent.type is "WithStatement" and parent.object is node) or
    (parent.type is "SwitchStatement" and parent.discriminant is node) or
    (parent.type is "WhileStatement" and parent.test is node) or
    (parent.type is "DoWhileStatement" and parent.test is node) or
    (parent.type is "ForStatement" and parent.test is node) or
    (parent.type is "ForStatement" and parent.update is node) or
    (parent.type is "ForStatement" and parent.init is node and node.type isnt "VariableDeclaration") or
    (parent.type is "ForInStatement" and parent.right is node) or
    (parent.type is "SwitchCase" and parent.test is node) or
    (parent.type is "ThrowStatement")

  mapChildren: (node, func) ->
    for key of node
      if isArray(node[key])
        for child, i in node[key]
          node[key][i] = func(child)
      else if node[key] and node[key].type
        node[key] = func(node[key])

  instrumentTree: (node, parent=null, returnOrThrowVar) ->
    if node.type in ["FunctionDeclaration", "FunctionExpression"]
      returnOrThrowVar = @temporaryVariable "returnOrThrow"

    if node.type in ["CallExpression", "NewExpression"]
      node.pencilTracerReturnVar = @temporaryVariable("returnVar", true)

    @mapChildren node, (child) =>
      @instrumentTree(child, node, returnOrThrowVar)
      if @shouldInstrumentWithBlock(child, node)
        type: "BlockStatement"
        body: [@createInstrumentedNode("before", node: child), child, @createInstrumentedNode("after", node: child)]
      else if @shouldInstrumentExpr(child, node)
        if child.pencilTracerReturnVar
          @createInstrumentedExpr(child, child.pencilTracerReturnVar)
        else
          @createInstrumentedExpr(child)
      else if child.pencilTracerReturnVar
        @createAssignNode(child.pencilTracerReturnVar, child)
      else if child.type is "ForStatement" and child.init?.type is "VariableDeclaration"
        varDecl = child.init
        child.init = null

        type: "BlockStatement"
        body: [
          @createInstrumentedNode("before", node: varDecl)
          varDecl
          @createInstrumentedNode("after", node: varDecl)
          child
        ]
      else if node.type is "ForInStatement" and child is node.body
        if child.type isnt "BlockStatement"
          child =
            type: "BlockStatement"
            body: [@createInstrumentedNode("before", node: child), child, @createInstrumentedNode("after", node: child)]

        type: "BlockStatement"
        body: [
          @createInstrumentedNode("before", node: node.left)
          @createInstrumentedNode("after", node: node.left)
          child
        ]
      else if child.type is "ReturnStatement"
        if child.argument is null
          child.argument = @createUndefinedNode()

        type: "BlockStatement"
        body: [
          @createInstrumentedNode("before", node: child)
          @createAssignNode(returnOrThrowVar + ".value", child.argument, true)
          @createInstrumentedNode("after", node: child)
          @createReturnNode(returnOrThrowVar + ".value")
        ]
      else if child.type in ["BreakStatement", "ContinueStatement"]
        type: "BlockStatement"
        body: [@createInstrumentedNode("before", node: child, vars: []), @createInstrumentedNode("after", node: child, vars: []), child]
      else if node.type in ["FunctionDeclaration", "FunctionExpression"] and node.body is child
        newBlock = acorn.parse("""
          {
            var #{returnOrThrowVar} = { type: 'return', value: void 0 };
            try {}
            catch (#{@caughtErrorVar}) {
              #{returnOrThrowVar}.type = 'throw';
              #{returnOrThrowVar}.value = #{@caughtErrorVar};
              throw #{@caughtErrorVar};
            } finally {}
          }
        """).body[0]

        tryStatement = newBlock.body[1]

        tryStatement.block = child
        newBlock.body.unshift(@createInstrumentedNode("enter", node: node))
        tryStatement.finalizer.body.unshift(@createInstrumentedNode("leave", node: node, returnOrThrowVar: returnOrThrowVar))

        newBlock
      else
        child

  instrument: (filename, code) ->
    @undeclaredVars = []
    @referencedVars = []
    ast = acorn.parse code, locations: true, onToken: (token) =>
      if token.type.label is "name" and @referencedVars.indexOf(token.value) is -1
        @referencedVars.push token.value

    @caughtErrorVar = @temporaryVariable("err")

    @instrumentTree ast

    if @undeclaredVars.length > 0
      tempVarsDeclaration =
        type: "VariableDeclaration"
        kind: "var"
        declarations: ({type: "VariableDeclarator", id: {type: "Identifier", name: name}, init: null} for name in @undeclaredVars)

      ast.body.unshift(tempVarsDeclaration)

    return ast if @options.ast

    escodegen.generate(ast)

exports.instrumentJs = (filename, code, options = {}) ->
  instrumenter = new JavaScriptInstrumenter(options)
  instrumenter.instrument filename, code

