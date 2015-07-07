class Scope
  constructor: (@parent) ->
    @vars = []

  add: (variable, type) ->
    if @vars.indexOf(variable) is -1
      @vars.push { name: variable, type: type }

  toCode: (activeVars) ->
    curScope = this
    code = "{"
    while curScope
      for variable in curScope.vars
        isActive = activeVars.indexOf(variable.name) isnt -1
        code += "'#{variable.name}': { name: '#{variable.name}', value: #{variable.name}, type: '#{variable.type}', active: #{isActive} }, "
      curScope = curScope.parent
    code += "}"
    code

exports.Scope = Scope

