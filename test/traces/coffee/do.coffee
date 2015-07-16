a = 0
for f in [-> a = 1]
  do (f) ->
    do f

# Trace:
#   1: before  a=/
#   1: after   a=0
#   2: before
#   2: after
#   2: before  f=<function>
#   2: after   f=<function>
#   3: before
#     3: enter   f=<function>
#     4: before  f=<function>
#       2: enter
#       2: before  a=0
#       2: after   a=1
#       2: leave   return=1
#     4: after   f=<function>
#   3: after

