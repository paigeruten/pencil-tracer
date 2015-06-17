falafel = require "falafel"

class JavaScriptInstrumenter
  instrument: (filename, code, options = {}) ->
    traceFunc = options.traceFunc ? "pencilTrace"

    return code

exports.instrumentJs = (filename, code, options = {}) ->
  instrumenter = new JavaScriptInstrumenter()
  instrumenter.instrument filename, code, options

