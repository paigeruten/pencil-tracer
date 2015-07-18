f = ->
  throw new Error()

g = ->
  try
    f()
  catch err
    return 'caught it'
  finally
    'finally'

g()

# Trace:
#   1:  before  f=/
#   1:  after   f=<function>
#   4:  before  g=/
#   4:  after   g=<function>
#   12: before
#     4: enter
#     6: before
#       1: enter
#       2: before
#       2: after
#       1: leave   throw=<object>
#     7: before  err=<object>
#     7: after   err=<object>
#     8: before
#     8: after
#     10: before
#     10: after
#     4: leave   return='caught it'
#   12: after

