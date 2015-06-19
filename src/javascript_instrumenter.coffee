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

class JavaScriptInstrumenter
  # Returns javascript code that calls the trace function, passing in the event
  # object.
  traceCall: (traceFunc, location, eventType) ->
    # Give the column numbers as 1-indexed values, instead of 0-indexed. Line
    # numbers are already 1-indexed.
    locationObj = "{ first_line: #{location.start.line},"
    locationObj += " first_column: #{location.start.column + 1},"
    locationObj += " last_line: #{location.end.line},"
    locationObj += " last_column: #{location.end.column + 1} }"

    "#{traceFunc}({ location: #{locationObj}, type: '#{eventType}' })"

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

  instrument: (filename, code, options = {}) ->
    traceFunc = options.traceFunc ? "pencilTrace"

    result = falafel code, locations: true, (node) =>
      switch node.type
        # Instrument solitary semicolons to show that they count as statements,
        # and to show they can count as if/while bodies.
        when "EmptyStatement", "ExpressionStatement", "BreakStatement", "ContinueStatement", "ReturnStatement", "ThrowStatement", "DebuggerStatement", "FunctionDeclaration"
          code = @traceCall(traceFunc, node.loc, "code")
          node.update "#{code}; #{node.source()}"

        when "VariableDeclaration"
          if node.parent.type not in ["ForStatement", "ForInStatement"]
            code = @traceCall(traceFunc, node.loc, "code")
            node.update "#{code}; #{node.source()}"

        when "ForStatement"
          if node.init
            code = @traceCall(traceFunc, node.init.loc, "code")
            node.update "#{code}; #{node.source()}"

        # Instrument BlockStatements with enter/leave events when they are used
        # as a function body.
        when "BlockStatement"
          if node.parent.type in ["FunctionDeclaration", "FunctionExpression"]
            enter = @traceCall(traceFunc, node.loc, "enter")
            leave = @traceCall(traceFunc, node.loc, "leave")
            node.update "{ #{enter}; try #{node.source()} finally { #{leave}; } }"

        when "ThisExpression", "ArrayExpression", "ObjectExpression", "FunctionExpression", "SequenceExpression", "UnaryExpression", "BinaryExpression", "AssignmentExpression", "UpdateExpression", "LogicalExpression", "ConditionalExpression", "CallExpression", "NewExpression", "MemberExpression", "Identifier", "Literal", "RegExpLiteral"
          if node.parent.type in ["IfStatement", "WithStatement", "SwitchStatement", "WhileStatement", "DoWhileStatement", "ForStatement", "ForInStatement", "SwitchCase"]
            code = @traceCall(traceFunc, node.loc, "code")
            node.update "#{code},(#{node.source()})"

      # Our instrumented code may have turned code like "if (cond) x();" into
      # "if (cond) pencilTrace(...); x();", but what we want in that case is
      # "if (cond) { pencilTrace(...); x(); }". Check if this node needs braces
      # and add them if so.
      if @needsBraces(node)
        node.update "{ #{node.source()} }"

    return result.toString()

exports.instrumentJs = (filename, code, options = {}) ->
  instrumenter = new JavaScriptInstrumenter()
  instrumenter.instrument filename, code, options

