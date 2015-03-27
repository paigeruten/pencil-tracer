coffeeScript = require "coffee-script"

exports.nodeType = (node) ->
  return node?.constructor?.name or null

exports.makeUndefinedNode = ->
  coffeeScript.nodes("undefined").expressions[0]

exports.makeAssignNode = (variableName, valueNode) ->
  node = coffeeScript.nodes("x = 0").expressions[0]
  node.variable.base.value = variableName
  node.value = valueNode
  node

exports.makeReturnNode = (variableName) ->
  node = coffeeScript.nodes("return x").expressions[0]
  node.expression.base.value = variableName
  node

