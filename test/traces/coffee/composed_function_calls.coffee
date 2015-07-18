double = (x) -> x + x
square = (x) ->
  x * x

y = double square 3

# Trace:
#   1: before  double=/
#   1: after   double=<function>
#   2: before  square=/
#   2: after   square=<function>
#   5: before  y=/
#     2: enter   x=3
#     3: before  x=3
#     3: after   x=3
#     2: leave   return=9
#     1: enter   x=9
#     1: before  x=9
#     1: after   x=9
#     1: leave   return=18
#   5: after   y=18

