f = (a, ..., b) ->
  a + b
x = f 1, 2, 3

[a, ..., b] = "abcdefg"

# Trace:
#   1: before  f=/
#   1: after   f=<function>
#   3: before  x=/
#     1: enter   a=1 b=3
#     2: before  a=1 b=3
#     2: after   a=1 b=3
#     1: leave   return=4
#   3: after   x=4
#   5: before  a=/ b=/
#   5: after   a='a' b='g'

