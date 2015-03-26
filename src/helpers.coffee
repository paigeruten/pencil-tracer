exports.nodeType = (node) ->
  return node?.constructor?.name or null

