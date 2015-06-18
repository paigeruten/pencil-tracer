should = require 'should'
pencilTracer = require '../../lib/index'
coffeeScript = require 'coffee-script'

describe 'JavaScriptInstrumenter', ->
  describe 'instrumentJs()', ->
    it 'should be exported', ->
      pencilTracer.instrumentJs.should.have.type 'function'

    it 'should return instrumented javascript'; ->
      before = 'var x = 3;'
      after = pencilTracer.instrumentJs('', before)
      after.should.have.type 'string'
      after.should.not.equal before
      after.should.match /pencilTrace/

    it 'should listen to the "traceFunc" option'; ->
      js = pencilTracer.instrumentJs('', 'var x = 3;', traceFunc: 'myTraceFunc')
      js.should.match /myTraceFunc/
      js.should.not.match /pencilTrace/

