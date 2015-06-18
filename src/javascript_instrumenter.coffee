falafel = require "falafel"

class JavaScriptInstrumenter
  # Returns javascript code that calls the trace function, passing in the event
  # object.
  createInstrumentedLine: (traceFunc, location, eventType) ->
    # Give the line and column numbers as 1-indexed values, instead of 0-indexed.
    locationObj = "{ first_line: #{location.start.line + 1},"
    locationObj += " first_column: #{location.start.column + 1},"
    locationObj += " last_line: #{location.end.line + 1},"
    locationObj += " last_column: #{location.end.column + 1} }"

    "#{traceFunc}({ location: #{locationObj}, type: '#{eventType}' })"

  instrument: (filename, code, options = {}) ->
    traceFunc = options.traceFunc ? "pencilTrace"

    result = falafel code, locations: true, (node) ->
      if node.type is 'CallExpression'
        instrumentedLine = @createInstrumentedLine(traceFunc, node.loc, "code")
        node.update "#{instrumentedLine},#{node.source()}"

    return result.toString()

exports.instrumentJs = (filename, code, options = {}) ->
  instrumenter = new JavaScriptInstrumenter()
  instrumenter.instrument filename, code, options

