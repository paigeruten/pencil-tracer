falafel = require "falafel"

class JavaScriptInstrumenter
  # Returns javascript code that calls the trace function, passing in the event
  # object.
  createInstrumentedLine: (traceFunc, location, eventType) ->
    # Give the column numbers as 1-indexed values, instead of 0-indexed. Line
    # numbers are already 1-indexed.
    locationObj = "{ first_line: #{location.start.line},"
    locationObj += " first_column: #{location.start.column + 1},"
    locationObj += " last_line: #{location.end.line},"
    locationObj += " last_column: #{location.end.column + 1} }"

    "#{traceFunc}({ location: #{locationObj}, type: '#{eventType}' })"

  instrument: (filename, code, options = {}) ->
    traceFunc = options.traceFunc ? "pencilTrace"

    result = falafel code, locations: true, (node) =>
      if /(Declaration|Statement)$/.test(node.type) and node.type isnt "BlockStatement"
        instrumentedLine = @createInstrumentedLine(traceFunc, node.loc, "code")
        node.update "#{instrumentedLine};#{node.source()}"

      if node.type is "BlockStatement" and /^Function(Declaration|Expression)$/.test node.parent.type
        instrumentedEnterLine = @createInstrumentedLine(traceFunc, node.loc, "enter")
        instrumentedLeaveLine = @createInstrumentedLine(traceFunc, node.loc, "leave")
        node.update "{ #{instrumentedEnterLine}; try #{node.source()} finally { #{instrumentedLeaveLine}; } }"

    return result.toString()

exports.instrumentJs = (filename, code, options = {}) ->
  instrumenter = new JavaScriptInstrumenter()
  instrumenter.instrument filename, code, options

