class Scope
  constructor: (@parent) ->
    @vars = []

  add: (variable, type) ->
    if @vars.indexOf(variable) is -1
      @vars.push { name: variable, type: type }

  toCode: ->
    curScope = this
    code = "[ "
    while curScope
      for variable in curScope.vars
        code += "{ name: '#{variable.name}', value: #{variable.name}, type: '#{variable.type}' }, "
      curScope = curScope.parent
    code += "]"
    code

exports.Scope = Scope

