should = require 'should'
pencilTracer = require '../../lib/index'
coffeeScript = require 'coffee-script'

describe 'JavaScriptInstrumenter', ->
  describe 'instrumentJs()', ->
    it 'should be exported', ->
      pencilTracer.instrumentJs.should.have.type 'function'

    it 'should return instrumented javascript', ->
      before = 'var x = 3;'
      after = pencilTracer.instrumentJs('', before)
      after.should.have.type 'string'
      after.should.not.equal before
      after.should.match /pencilTrace/

    it 'should listen to the "traceFunc" option', ->
      js = pencilTracer.instrumentJs('', 'var x = 3;', traceFunc: 'myTraceFunc')
      js.should.match /myTraceFunc/
      js.should.not.match /pencilTrace/

    it 'should listen to the "sourceMap" option', ->
      result = pencilTracer.instrumentJs('', 'var x = 3;', sourceMap: true)
      result.should.have.type 'object'
      result.should.have.ownProperty 'code'
      result.should.have.ownProperty 'map'

    it 'should listen to the "ast" option', ->
      ast = pencilTracer.instrumentJs('', 'var x = 3;', ast: true)
      ast.should.have.type 'object'
      ast.type.should.equal 'Program'

    it 'should listen to the "includeArgsStrings" option', ->
      js = pencilTracer.instrumentJs('', 'f(1, 2, 3);', includeArgsStrings: true)
      js.should.match /argsString: '1, 2, 3'/

