f = (autocb) ->
  3

x = 0
if true
  await
    f defer x
  x

# Trace:
#   1: before  f=/
#   1: after   f=<function>
#   4: before  x=/
#   4: after   x=0
#   5: before
#   5: after
#   7: before
#     1: enter   autocb=<function>
#     2: before
#     2: after
#     1: leave   return=3
#   7: after
#   8: before  x=3
#   8: after   x=3

