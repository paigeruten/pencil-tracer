falafel = require "falafel"

class JavaScriptInstrumenter
  instrument: (filename, code, options = {}) ->
    traceFunc = options.traceFunc ? "pencilTrace"

    result = falafel code, locations: true, (node) ->
      if node.type is 'CallExpression'
        node.update "#{traceFunc}({location: {first_line: #{node.loc.start.line}, first_column: #{node.loc.start.column}, last_line: #{node.loc.end.line}, last_column: #{node.loc.end.column}}, type: ''}),#{node.source()}"

    return result

exports.instrumentJs = (filename, code, options = {}) ->
  instrumenter = new JavaScriptInstrumenter()
  instrumenter.instrument filename, code, options

