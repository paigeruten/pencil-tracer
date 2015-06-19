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
      if /(Declaration|Statement)$/.test(node.type)
        instrumentedLine = @createInstrumentedLine(traceFunc, node.loc, "code")
        node.update "#{instrumentedLine};#{node.source()}"

    return result.toString()

exports.instrumentJs = (filename, code, options = {}) ->
  instrumenter = new JavaScriptInstrumenter()
  instrumenter.instrument filename, code, options

