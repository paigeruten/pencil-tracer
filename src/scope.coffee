class Scope
  constructor: (@parent) ->
    @vars = []

  add: (variable) ->
    if @vars.indexOf(variable) is -1
      @vars.push variable

  toCode: ->
    curScope = this
    code = "{ "
    while curScope
      for ident in curScope.vars
        code += "#{ident}: #{ident}, "
      curScope = curScope.parent
    code += "}"
    code

exports.Scope = Scope

