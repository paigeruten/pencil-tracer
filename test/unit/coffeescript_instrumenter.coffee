should = require 'should'
pencilTracer = require '../../lib/index'
coffeeScript = require 'coffee-script'

describe 'CoffeeScriptInstrumenter', ->
  describe 'instrumentCoffee()', ->
    it 'should be exported', ->
      pencilTracer.instrumentCoffee.should.have.type 'function'

    it 'should return instrumented javascript', ->
      coffee = 'x = 3'
      js = pencilTracer.instrumentCoffee('', coffee, coffeeScript)
      js.should.have.type 'string'
      js.should.not.equal coffee
      js.should.match /var/
      js.should.match /pencilTrace/

    it 'should listen to the "traceFunc" option', ->
      js = pencilTracer.instrumentCoffee('', 'x = 3', coffeeScript, traceFunc: 'myTraceFunc')
      js.should.match /myTraceFunc/
      js.should.not.match /pencilTrace/

    it 'should listen to the "bare" option', ->
      js = pencilTracer.instrumentCoffee('', 'x = 3', coffeeScript)
      jsBare = pencilTracer.instrumentCoffee('', 'x = 3', coffeeScript, bare: true)

      js.should.match /function\(\)/
      jsBare.should.not.match /function\(\)/

    it 'should listen to the "sourceMap" option', ->
      result = pencilTracer.instrumentCoffee('', 'x = 3', coffeeScript, sourceMap: true)
      result.should.have.type 'object'
      result.should.have.ownProperty 'code'
      result.should.have.ownProperty 'map'

    it 'should listen to the "ast" option', ->
      ast = pencilTracer.instrumentCoffee('', 'x = 3', coffeeScript, ast: true)
      ast.should.have.type 'object'
      ast.constructor.name.should.equal 'Block'

    it 'should listen to the "includeArgsStrings" option', ->
      js = pencilTracer.instrumentCoffee('', 'f(1, 2, 3)', coffeeScript, includeArgsStrings: true)
      js.should.match /argsString: '1, 2, 3'/

