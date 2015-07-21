f = ->
  return
f()

# Trace:
#   1: before  f=/
#   1: after   f=<function>
#   3: before
#     1: enter
#     2: before
#     2: after
#     1: leave   return=/
#   3: after   f()=/

