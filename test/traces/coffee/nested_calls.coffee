g = (x) ->
  x + 1

f = (x) ->
  g x

f 3

# Trace:
#   1: before  g=/
#   1: after   g=<function>
#   4: before  f=/
#   4: after   f=<function>
#   7: before  f=<function>
#     4: enter   x=3
#     5: before  g=<function> x=3
#       1: enter   x=3
#       2: before  x=3
#       2: after   x=3
#       1: leave   return=4
#     5: after   g=<function> x=3
#     4: leave   return=4
#   7: after   f=<function>

