coffeeScript = require "coffee-script"
{nodeType} = require "./helpers"

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

# Options:
#   traceFunc: the name of the function to call and pass events into (default: "ide.trace")
#   ast: if true, returns the instrumented AST instead of compiling it
exports.instrument = (filename, code, options = {}) ->
  traceFunc = options.traceFunc ? "ide.trace"

  try
    tokens = coffeeScript.tokens code, {}
    ast = coffeeScript.nodes tokens
  catch err
    throw new InstrumentError("Could not parse #{filename}: #{err.stack}")

  instrumentTree = (node, depth=0) ->
    if nodeType(node) is "Block"
      children = node.expressions
      childIndex = 0
      while childIndex < children.length
        expression = children[childIndex]
        lineNum = expression.locationData.first_line + 1
        colNum = expression.locationData.first_column

        unless nodeType(expression) is "Comment"
          instrumentedLine =
            coffeeScript.nodes("#{traceFunc}({line: #{lineNum}, column: #{colNum}})")

          fixLocationData instrumentedLine, lineNum

          children.splice(childIndex, 0, instrumentedLine)
          childIndex++

        instrumentTree expression, depth + 1
        childIndex++
    else
      # coffee-coverage does this, because chaining "produces code that's
      # harder to instrument".
      # TODO: figure out if this is actually needed for what we're doing.
      if nodeType(node) is "If"
        node.isChain = false

      node.eachChild (child) => instrumentTree(child, depth + 1)

  instrumentTree ast

  return ast if options.ast

  try
    js = ast.compile {}
  catch err
    throw new InstrumentError("Could not compile #{filename} after instrumenting: #{err.stack}")

  return js

