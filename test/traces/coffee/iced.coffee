f = (autocb) ->
  3

x = 0
if true
  await
    f defer x
  'tail'

# Trace:
#   1: before  f=/
#   1: after   f=<function>
#   4: before  x=/
#   4: after   x=0
#   5: before
#   5: after
#   6: before
#   6: after
#   7: before  f=<function> x=/
#     1: enter   autocb=<function>
#     2: before  autocb=<function>
#     2: after   autocb=<function>
#     1: leave   return=/
#   7: after   f=<function> x=3
#   8: before
#   8: after

