falafel = require "falafel"

STATEMENTS = [
  "EmptyStatement", "BlockStatement", "ExpressionStatement", "IfStatement",
  "LabeledStatement", "BreakStatement", "ContinueStatement", "WithStatement",
  "SwitchStatement", "ReturnStatement", "ThrowStatement", "TryStatement",
  "WhileStatement", "DoWhileStatement", "ForStatement", "ForInStatement",
  "DebuggerStatement", "FunctionDeclaration", "VariableDeclaration"
]

STATEMENTS_WITH_BODIES = [
  "IfStatement", "LabeledStatement", "WithStatement", "WhileStatement",
  "DoWhileStatement", "ForStatement", "ForInStatement"
]

isArray = Array.isArray || (value) -> {}.toString.call(value) is '[object Array]'

class JavaScriptInstrumenter
  constructor: (@options) ->
    @options.traceFunc ?= "pencilTrace"

  findVariables: (node, vars=[]) ->
    if node.type is "Identifier"
      if vars.indexOf(node.name) is -1
        vars.push node.name

    for key of node
      continue if key is "parent"
      continue if node.type is "Property" and key is "key"
      continue if node.type in ["FunctionExpression", "FunctionDeclaration"] and key is "params"
      if isArray(node[key])
        for child in node[key]
          @findVariables(child, vars)
      else if node[key] and typeof node[key].type is "string" and node[key].type not in STATEMENTS
        @findVariables(node[key], vars)

    vars

  findArguments: (funcNode, vars=[]) ->
    (param.name for param in funcNode.params)

  # Returns javascript code that calls the trace function, passing in the event
  # object.
  traceCall: (targetNode, eventType) ->
    loc = targetNode.loc

    # Give the column numbers as 1-indexed values, instead of 0-indexed. Line
    # numbers are already 1-indexed.
    locationObj = "{ first_line: #{loc.start.line},"
    locationObj += " first_column: #{loc.start.column + 1},"
    locationObj += " last_line: #{loc.end.line},"
    locationObj += " last_column: #{loc.end.column + 1} }"

    extra =
      switch eventType
        when "before", "after"
          "vars: {" + ("#{name}: (typeof #{name} === 'undefined' ? void 0 : #{name})" for name in @findVariables(targetNode)) + "}"
        when "enter"
          "vars: {" + ("#{name}: #{name}" for name in @findArguments(targetNode)) + "}"
        when "leave"
          "returnVal: 'TEST'"

    "#{@options.traceFunc}({ location: #{locationObj}, type: '#{eventType}', #{extra} })"

  # This checks whether a node is a single statement acting as the body of
  # another statement, e.g. the "i++;" in "while (i < 10) i++;". In that case,
  # to instrument "i++;" inside the loop we need to add braces around the loop
  # body.
  #
  # A special case is needed to handle ForStatements, since it's possible for
  # the child of a ForStatement to be a Statement without being the body of the
  # for loop, e.g. the "var i = 0;" in "for (var i = 0; i < 10; i++);". We
  # don't want to add braces around that.
  needsBraces: (node) ->
    node.type in STATEMENTS and
    node.type isnt "BlockStatement" and
    node.parent.type in STATEMENTS_WITH_BODIES and
    not (node.parent.type is "ForStatement" and node.parent.init is node) and
    not (node.parent.type is "ForInStatement" and node.parent.left is node)

  instrument: (filename, code) ->
    result = falafel code, locations: true, (node) =>
      switch node.type
        when "EmptyStatement", "ExpressionStatement", "BreakStatement", "ContinueStatement", "ReturnStatement", "ThrowStatement", "DebuggerStatement", "FunctionDeclaration"
          code = @traceCall(node, "before")
          node.update "#{code}; #{node.source()}"

          if node.parent.type in ["DoWhileStatement", "ForInStatement"]
            code = @traceCall(node.parent, "before")
            node.update "#{code}; #{node.source()}"

        when "VariableDeclaration"
          if node.parent.type not in ["ForStatement", "ForInStatement"]
            code = @traceCall(node, "before")
            node.update "#{code}; #{node.source()}"

        when "ForStatement"
          code = @traceCall(node.init || node, "before")
          node.update "#{code}; #{node.source()}"

        when "BlockStatement"
          if node.parent.type in ["FunctionDeclaration", "FunctionExpression"]
            enter = @traceCall(node.parent, "enter")
            leave = @traceCall(node.parent, "leave")
            node.update "{ #{enter}; try #{node.source()} finally { #{leave}; } }"

          if node.parent.type is "TryStatement"
            if node.parent.block is node
              code = @traceCall(node.parent, "before")
              node.update "{ #{code}; #{node.source()} }"
            else if node.parent.finalizer is node
              code = @traceCall(node, "before")
              node.update "{ #{code}; #{node.source()} }"

          if node.parent.type is "CatchClause"
            code = @traceCall(node.parent, "before")
            node.update "{ #{code}; #{node.source()} }"

          if node.parent.type in ["DoWhileStatement", "ForInStatement"]
            code = @traceCall(node.parent, "before")
            node.update "{ #{code}; #{node.source()} }"

        when "ThisExpression", "ArrayExpression", "ObjectExpression", "FunctionExpression", "SequenceExpression", "UnaryExpression", "BinaryExpression", "AssignmentExpression", "UpdateExpression", "LogicalExpression", "ConditionalExpression", "CallExpression", "NewExpression", "MemberExpression", "Identifier", "Literal", "RegExpLiteral"
          if node.parent.type in ["IfStatement", "WithStatement", "SwitchStatement", "WhileStatement", "DoWhileStatement", "ForStatement", "SwitchCase"]
            code = @traceCall(node, "before")
            node.update "#{code},(#{node.source()})"

      # Our instrumented code may have turned code like "if (cond) x();" into
      # "if (cond) pencilTrace(...); x();", but what we want in that case is
      # "if (cond) { pencilTrace(...); x(); }". Check if this node needs braces
      # and add them if so.
      if @needsBraces(node)
        node.update "{ #{node.source()} }"

    return result.toString()

exports.instrumentJs = (filename, code, options = {}) ->
  instrumenter = new JavaScriptInstrumenter(options)
  instrumenter.instrument filename, code

