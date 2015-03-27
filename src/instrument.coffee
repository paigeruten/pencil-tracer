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

createInstrumentedLine = (traceFunc, locationData, eventType) ->
  locationObj = "{ first_line: #{locationData.first_line + 1},"
  locationObj += " first_column: #{locationData.first_column},"
  locationObj += " last_line: #{locationData.last_line + 1},"
  locationObj += " last_column: #{locationData.last_column} }"

  instrumentedLine =
    coffeeScript.nodes("#{traceFunc}({ location: #{locationObj}, type: '#{eventType}' })")

  fixLocationData(instrumentedLine, locationData.first_line + 1)

  instrumentedLine

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

  instrumentTree = (node, parent=null, depth=0) ->
    if nodeType(node) is "Block"
      children = node.expressions
      childIndex = 0
      while childIndex < children.length
        expression = children[childIndex]

        unless nodeType(expression) is "Comment"
          instrumentedLine = createInstrumentedLine(traceFunc, expression.locationData, "")

          children.splice(childIndex, 0, instrumentedLine)
          childIndex++

        instrumentTree(expression, node, depth + 1)
        childIndex++

      if nodeType(parent) is "Code"
        children.splice(0, 0, createInstrumentedLine(traceFunc, parent.locationData, "enter"))
        children.splice(children.length, 0, createInstrumentedLine(traceFunc, parent.locationData, "leave"))
    else
      # coffee-coverage does this, because chaining "produces code that's
      # harder to instrument".
      # TODO: figure out if this is actually needed for what we're doing.
      if nodeType(node) is "If"
        node.isChain = false

      node.eachChild (child) => instrumentTree(child, node, depth + 1)

  instrumentTree ast

  return ast if options.ast

  try
    js = ast.compile {}
  catch err
    throw new InstrumentError("Could not compile #{filename} after instrumenting: #{err.stack}")

  return js

