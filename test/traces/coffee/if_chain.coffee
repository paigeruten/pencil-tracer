message = (hour) ->
  if hour < 12
    'good morning'
  else if hour < 18
    'good afternoon'
  else
    'good evening'

message(6)
message(13)
message(20)

# Trace:
#   1:  before  message=/
#   1:  after   message=<function>
#   9:  before
#     1: enter   hour=6
#     2: before  hour=6
#     2: after   hour=6
#     3: before
#     3: after
#     1: leave   return='good morning'
#   9:  after
#   10: before
#     1: enter   hour=13
#     2: before  hour=13
#     2: after   hour=13
#     4: before  hour=13
#     4: after   hour=13
#     5: before
#     5: after
#     1: leave   return='good afternoon'
#   10: after
#   11: before
#     1: enter   hour=20
#     2: before  hour=20
#     2: after   hour=20
#     4: before  hour=20
#     4: after   hour=20
#     7: before
#     7: after
#     1: leave   return='good evening'
#   11: after

