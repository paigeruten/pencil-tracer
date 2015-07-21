four = 4
square = (x) -> x * x
squares = (square x for x in [1, 2, 3, four] when x isnt four)

# Trace:
#   1: before  four=/
#   1: after   four=4
#   2: before  square=/
#   2: after   square=<function>
#   3: before  squares=/
#     3: before  four=4
#     3: after   four=4
#     3: before  x=1
#     3: after   x=1
#     3: before  x=1 four=4
#     3: after   x=1 four=4
#     3: before  x=1
#       2: enter   x=1
#       2: before  x=1
#       2: after   x=1
#       2: leave   return=1
#     3: after   x=1 square()=1
#     3: before  x=2
#     3: after   x=2
#     3: before  x=2 four=4
#     3: after   x=2 four=4
#     3: before  x=2
#       2: enter   x=2
#       2: before  x=2
#       2: after   x=2
#       2: leave   return=4
#     3: after   x=2 square()=4
#     3: before  x=3
#     3: after   x=3
#     3: before  x=3 four=4
#     3: after   x=3 four=4
#     3: before  x=3
#       2: enter   x=3
#       2: before  x=3
#       2: after   x=3
#       2: leave   return=9
#     3: after   x=3 square()=9
#     3: before  x=4
#     3: after   x=4
#     3: before  x=4 four=4
#     3: after   x=4 four=4
#   3: after   squares=[1, 4, 9]

