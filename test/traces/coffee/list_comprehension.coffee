square = (x) -> x * x
squares = (square x for x in [1, 2, 3])

# Trace:
#   1: before  square=/
#   1: after   square=<function>
#   2: before  squares=/
#     2: before
#       2: after   x=1
#       2: before  square=<function> x=1
#         1: enter   x=1
#         1: before  x=1
#         1: after   x=1
#         1: leave   return=1
#       2: after   square=<function> x=1
#       2: after   x=2
#       2: before  square=<function> x=2
#         1: enter   x=2
#         1: before  x=2
#         1: after   x=2
#         1: leave   return=4
#       2: after   square=<function> x=2
#       2: after   x=3
#       2: before  square=<function> x=3
#         1: enter   x=3
#         1: before  x=3
#         1: after   x=3
#         1: leave   return=9
#       2: after   square=<function> x=3
#   2: after   squares=[1, 4, 9]

