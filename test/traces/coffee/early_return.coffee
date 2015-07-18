isEven = (n) ->
  return yes if n % 2 == 0
  return no

isEven(5)
isEven(6)

# Trace:
#   1: before  isEven=/
#   1: after   isEven=<function>
#   5: before
#     1: enter   n=5
#     2: before  n=5
#     2: after   n=5
#     3: before
#     3: after
#     1: leave   return=false
#   5: after
#   6: before
#     1: enter   n=6
#     2: before  n=6
#     2: after   n=6
#     2: before
#     2: after
#     1: leave   return=true
#   6: after

