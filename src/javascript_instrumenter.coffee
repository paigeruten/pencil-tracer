acorn = require "acorn"
escodegen = require "escodegen"

# Node types to traverse when finding variables and function calls used in a
# statement or expression.
FIND_VARIABLES_IN =
  ["ThisExpression", "ArrayExpression", "ObjectExpression", "Property",
   "SequenceExpression", "UnaryExpression", "BinaryExpression",
   "AssignmentExpression", "UpdateExpression", "LogicalExpression",
   "ConditionalExpression", "CallExpression", "NewExpression",
   "MemberExpression", "Identifier", "VariableDeclarator"]

# Helper to check whether a value is an Array.
isArray = Array.isArray || (value) -> {}.toString.call(value) is '[object Array]'

class JavaScriptInstrumenter
  # Options:
  #   * `traceFunc`: the name of the function to call for each trace event.
  #     (Default: "pencilTrace")
  constructor: (@options) ->
    @options.traceFunc ?= "pencilTrace"

  # Returns a unique name to use as a temporary variable, by appending a number
  # to the given base name until it gets an identifier that hasn't been used.
  # If `needsDeclaration` is true, then the variable will be pushed to
  # @undeclaredVars so that it will be declared at the top level of the output.
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

  # Recognizes function definitions. This includes function declarations as
  # well as variable declarations that assign a function expression to a
  # variable.
  isFunctionDef: (node) ->
    node?.type is "FunctionDeclaration" or
    (node?.type is "VariableDeclaration" and
     node.declarations.length is 1 and
     node.declarations[0].init?.type is "FunctionExpression")

  # Takes a variable or simple member expression as a string, e.g. "a.b.c", and
  # returns an expression that safely gets the value of the expression even if
  # "a" or "a.b" are undefined.
  soakify: (name) ->
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

  # Escape backslashes, single quotes, and newlines, so that the string can be
  # used in a JavaScript string literal.
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

    instrumentedNode =
      acorn.parse("#{@options.traceFunc}(#{eventObj});").body[0]

    # Mark the instrumented node, as well as the assignment expression node
    # itself, as having been instrumented.
    instrumentedNode.pencilTracerInstrumented = true
    instrumentedNode.expression.pencilTracerInstrumented = true

    instrumentedNode

  # Creates an expression that wraps the `originalExpr` between a 'before' and
  # 'after' event. For example, "x = 3" would become
  # "(pencilTrace('before', ...), _temp = x = 3, pencilTrace('after', ...), _temp)"
  # which is still an expression that can be used anywhere the original
  # expression could be used. If a `tempVar` isn't provided, a new one will be
  # generated.
  createInstrumentedExpr: (originalExpr, tempVar=null) ->
    if tempVar is null
      tempVar = @temporaryVariable "temp", true

    sequenceExpr = { type: "SequenceExpression", expressions: [] }
    sequenceExpr.expressions.push @createInstrumentedNode("before", node: originalExpr).expression
    sequenceExpr.expressions.push @createAssignNode(tempVar, originalExpr)
    sequenceExpr.expressions.push @createInstrumentedNode("after", node: originalExpr).expression
    sequenceExpr.expressions.push { type: "Identifier", name: tempVar }
    sequenceExpr

  # Creates an AssignmentExpression that assigns the given `expr` to the
  # `varName` variable. If `asStatement` is true, returns an ExpressionStatement
  # containing the AssignmentExpression.
  createAssignNode: (varName, expr, asStatement=false) ->
    node = acorn.parse("#{varName} = 0;").body[0]
    node.expression.right = expr
    node.expression.left.pencilTracerGenerated = true
    node.expression.loc = expr.loc

    if asStatement then node else node.expression

  # Creates a ReturnStatement that returns the given `varName` variable.
  createReturnNode: (varName) ->
    acorn.parse("return #{varName};", allowReturnOutsideFunction: true).body[0]

  # Creates a UnaryExpression ("void 0") that evaluates to undefined.
  createUndefinedNode: ->
    acorn.parse("void 0").body[0].expression

  # Finds every variable (e.g. "a") and simple member expression (e.g. "a.b.c")
  # used in a statement or expression. Only steps into nodes included in
  # FIND_VARIABLES_IN, defined at the top of this file. Basically, it won't
  # step into any code that will be instrumented later, such as function
  # expressions and blocks of code.
  findVariables: (node, parent=null, vars=[]) ->
    # Skip variables of AssignmentExpressions generated by @createAssignNode()
    # above. (TODO: should there be both pencilTracerInstrumented and
    # pencilTracerGenerated?)
    return [] if node.pencilTracerGenerated

    foundEndOfMemberExpression = false
    if node.type in ["Identifier", "ThisExpression"]
      # We've found a single variable (or `this` keyword).
      name = if node.type is "ThisExpression" then "this" else node.name

      # Append variable to vars if we haven't already.
      if vars.indexOf(name) is -1
        vars.push name
    else if node.type is "MemberExpression" and not node.computed
      # We have a MemberExpression, e.g. "a.b.c[0].d". We want to extract the
      # simple "a.b.c" part as a variable.
      curNode = node
      parts = []
      while curNode.type is "MemberExpression" and not curNode.computed
        parts.unshift curNode.property.name
        curNode = curNode.object
      if curNode.type in ["Identifier", "ThisExpression"]
        foundEndOfMemberExpression = true
        ident = if curNode.type is "ThisExpression" then "this" else curNode.name
        parts.unshift ident
        parts.pop() if parent?.type in ["CallExpression", "NewExpression"] and parent.callee is node
        name = parts.join(".")

        # Append variable to vars if we haven't already.
        if vars.indexOf(name) is -1
          vars.push name

    if not foundEndOfMemberExpression
      # Recursively search the children of this node, with some exceptions.
      for key of node
        # Skip property keys of object literals. Those look like variables, but
        # aren't. (e.g. the "a" in "{ a: 1 }".)
        continue if node.type is "Property" and key is "key"

        # Skip parameters of functions. (@findArguments() handles those.)
        continue if node.type in ["FunctionExpression", "FunctionDeclaration"] and key is "params"

        # Skip objects and non-computed properties of MemberExpression, since
        # we'll have already handled those above.
        continue if node.type is "MemberExpression" and key is "property" and not node.computed
        continue if node.type is "MemberExpression" and key is "object" and node[key].type in ["Identifier", "ThisExpression"] and not node.computed

        # Skip variables used as function calls, as function call tracking will
        # take care of those.
        continue if node.type in ["CallExpression", "NewExpression"] and key is "callee" and node[key].type in ["ThisExpression", "Identifier"]

        if isArray(node[key])
          for child in node[key]
            @findVariables(child, node, vars) if child.type in FIND_VARIABLES_IN
        else if node[key] and typeof node[key].type is "string"
          @findVariables(node[key], node, vars) if node[key].type in FIND_VARIABLES_IN

    vars

  # Takes a FunctionExpression or FunctionDeclaration and finds all argument
  # names for that function.
  findArguments: (funcNode) ->
    (param.name for param in funcNode.params)

  # Takes a location object and returns the substring at that location in the
  # original source file.
  substringByLocation: (loc) ->
    result = ""
    for lineNum in [loc.start.line..loc.end.line]
      result +=
        if lineNum is loc.start.line and lineNum is loc.end.line
          @lines[lineNum][loc.start.column...loc.end.column]
        else if lineNum is loc.start.line
          @lines[lineNum][loc.start.column..]
        else if lineNum is loc.end.line
          @lines[lineNum][...loc.end.column]
        else
          @lines[lineNum]
    result

  # Converts a list of argument nodes to a string containing the original
  # source of each argument, separated by commas.
  argsToString: (argNodes) ->
    (@substringByLocation(arg.loc) for arg in argNodes).join(", ")

  # Finds each function call in a statement or expression.
  findFunctionCalls: (node, funcs=[]) ->
    # Function calls have already been tagged with `pencilTracerReturnVar`s.
    if node.pencilTracerReturnVar
      # Get the function name, e.g. "func" for the expression "a.func()".
      name =
        if node.callee.type is "ThisExpression"
          "this"
        else if node.callee.type is "Identifier"
          node.callee.name
        else if node.callee.type is "MemberExpression" and not node.callee.computed
          node.callee.property.name
        else
          "<anonymous>"

      # Append the function info to funcs.
      funcs.push {name: name, tempVar: node.pencilTracerReturnVar, argsString: @argsToString(node.arguments)}

    # Recursively search the children of this node, skipping nodes that don't
    # appear in FIND_VARIABLES_IN.
    for key of node
      if isArray(node[key])
        for child in node[key]
          @findFunctionCalls(child, funcs) if child.type in FIND_VARIABLES_IN
      else if node[key] and typeof node[key].type is "string"
        @findFunctionCalls(node[key], funcs) if node[key].type in FIND_VARIABLES_IN

    funcs

  # Returns true if the node should be instrumented by replacing it with a
  # BlockStatement containing a before event, the original statement, and an
  # after event.
  shouldInstrumentWithBlock: (node, parent) ->
    node.type in ["EmptyStatement", "ExpressionStatement", "DebuggerStatement", "VariableDeclaration", "FunctionDeclaration"] and
    # Exclude variable declarations in for statements
    not (parent.type is "ForStatement" and parent.init is node) and
    not (parent.type is "ForInStatement" and parent.left is node) and
    # Exclude single-statement bodies of for-in statements, as those are a special case.
    not (parent.type is "ForInStatement" and parent.body is node)

  # Returns true for expression nodes that should be replaced by a
  # SequenceExpression (the comma operator) that wraps the original expression
  # in a before event and an after event, and makes the value of the
  # original expression the value of the whole SequenceExpression.
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

  # Maps over a node's children recursively, replacing each `child` node with
  # the result of `func(child)`.
  mapChildren: (node, func) ->
    for key of node
      if isArray(node[key])
        for child, i in node[key]
          node[key][i] = func(child)
      else if node[key] and node[key].type
        node[key] = func(node[key])

  # Instruments the AST recursively.
  #
  # Arguments:
  #   * `node`: the current node of the AST
  #   * `parent`: the parent node, or null if we're on the root node
  #   * `returnOrThrowVar`: the name of the variable used to track the return
  #     value or thrown error of the current function.
  instrumentTree: (node, parent=null, returnOrThrowVar) ->
    # If we're in a new function, set a new returnOrThrowVar for it.
    if node.type in ["FunctionDeclaration", "FunctionExpression"]
      returnOrThrowVar = @temporaryVariable "returnOrThrow"

    # Tag function calls with a pencilTracerReturnVar property, for tracking
    # function calls and their return value.
    if node.type in ["CallExpression", "NewExpression"]
      node.pencilTracerReturnVar = @temporaryVariable("returnVar", true)

    # If we have an infinite for loop like "for (;;) { ... }", replace it
    # with "for (;true;) { ... }" so we have an expression to instrument.
    if node.type is "ForStatement" and not node.test and not node.update
      node.test =
        type: "Literal"
        value: true
        loc: node.loc

    @mapChildren node, (child) =>
      # Instrument the child's descendants first.
      @instrumentTree(child, node, returnOrThrowVar)

      # Now instrument the current child. There are many cases...
      if @shouldInstrumentWithBlock(child, node)
        # Wrap it in a BlockStatement.
        type: "BlockStatement"
        body: [@createInstrumentedNode("before", node: child), child, @createInstrumentedNode("after", node: child)]
      else if @shouldInstrumentExpr(child, node)
        # Wrap it in a SequenceExpression.
        if child.pencilTracerReturnVar
          @createInstrumentedExpr(child, child.pencilTracerReturnVar)
        else
          @createInstrumentedExpr(child)
      else if child.pencilTracerReturnVar
        # Assign function calls to special variables that keep track of return
        # values.
        @createAssignNode(child.pencilTracerReturnVar, child)
      else if child.type is "ForStatement" and child.init?.type is "VariableDeclaration"
        # We can't wrap a VariableDeclaration of a ForStatement in any way, so
        # instead we'll move the VariableDeclaration above the ForStatement and
        # instrument that.

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
        # The variable of a ForInStatement is hard to instrument. We'll put a
        # before and after event for it at the beginning of the loop instead.

        if child.type isnt "BlockStatement"
          # If it's a single-statement body, we have to instrument it ourselves
          # here.
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
        # ReturnStatements need to be instrumented to capture the return value,
        # and trigger the after event after the returned expression is
        # evaluated and just before it is actually returned.

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
        # `break` and `continue` statements are simply instrumented with
        # before and after events that both come before the statement. No
        # variables can change, so this is okay.
        type: "BlockStatement"
        body: [@createInstrumentedNode("before", node: child, vars: []), @createInstrumentedNode("after", node: child, vars: []), child]
      else if node.type in ["FunctionDeclaration", "FunctionExpression"] and node.body is child
        # Function bodies are instrumented with a try..catch..finally statement
        # that is used to track return values, thrown errors, and trigger
        # leave events.

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
        # All other nodes are left unchanged.
        child

  # Instruments a JavaScript program.
  instrument: (code) ->
    # Store the lines of the program in an array, to be used by
    # @substringByLocation().
    @lines = code.match(/^.*((\r\n|\n|\r)|$)/gm)
    @lines.unshift null # Make it easy to use the 1-indexed line numbers acorn gives us.

    # Stores variable names that will need top-level declarations.
    @undeclaredVars = []

    # Stores every identifier seen in the AST, so that no generated variables
    # will have the same name as an already existing variable.
    @referencedVars = []

    # Parse the input program into an AST.
    ast = acorn.parse code, locations: true, onToken: (token) =>
      # Append each "name" token to @referencedVars.
      if token.type.label is "name" and @referencedVars.indexOf(token.value) is -1
        @referencedVars.push token.value

    # This variable will be used in each function's instrumented try..catch
    # statement.
    @caughtErrorVar = @temporaryVariable("err")

    # Instrument the AST.
    @instrumentTree ast

    # Declare all undeclared variables at the top of the program.
    if @undeclaredVars.length > 0
      tempVarsDeclaration =
        type: "VariableDeclaration"
        kind: "var"
        declarations: ({type: "VariableDeclarator", id: {type: "Identifier", name: name}, init: null} for name in @undeclaredVars)

      ast.body.unshift(tempVarsDeclaration)

    # Return the AST if that's all the caller wants.
    return ast if @options.ast

    # Generate JavaScript from the instrumented AST using escodegen, optionally
    # including a source map.
    if @options.sourceMap
      result = escodegen.generate(ast, sourceMap: "untitled.js", sourceMapWithCode: true)
      result.map = result.map.toString()
      result
    else
      escodegen.generate(ast)

# Instruments a JavaScript program.
#
# Options:
#   * `traceFunc`: the function that will be called for each event.
#     (Default: 'pencilTrace')
#   * `ast`: if true, returns the instrumented AST instead of the JavaScript.
#     (Default: false)
#   * `sourceMap`: if true, returns a source map as well as the instrumented
#     code. The return value will be an object with `code` and `map`
#     properties. (Default: false)
#   * `includeArgsStrings`: if true, each tracked function call will include a
#     string containing the arguments passed to the function. (Default: false)
exports.instrumentJs = (code, options = {}) ->
  instrumenter = new JavaScriptInstrumenter(options)
  instrumenter.instrument code

