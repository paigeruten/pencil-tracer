# Helpers for dealing with CoffeeScript ASTs.

coffeeScript = require "coffee-script"

exports.nodeType = (node) ->
  return node?.constructor?.name or null

# Create a Value(Undefined()) node.
exports.makeUndefinedNode = ->
  coffeeScript.nodes("undefined").expressions[0]

# Create an Assign node that assigns the given valueNode to the given variable
# name.
exports.makeAssignNode = (variableName, valueNode) ->
  node = coffeeScript.nodes("x = 0").expressions[0]
  node.variable.base.value = variableName
  node.value = valueNode
  node

# Create a Return node that returns the value of the given variable name.
exports.makeReturnNode = (variableName) ->
  node = coffeeScript.nodes("return x").expressions[0]
  node.expression.base.value = variableName
  node

