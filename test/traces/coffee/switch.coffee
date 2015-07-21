shape = (sides) ->
  switch sides
    when 0, 1, 2
      'invalid input'
    when 3
      'triangle'
    else
      'too complicated'

shape 1
shape 3
shape 4

# Trace:
#   1:  before  shape=/
#   1:  after   shape=<function>
#   10: before
#     1: enter   sides=1
#     2: before  sides=1
#     2: after   sides=1
#     3: before
#     3: after
#     4: before
#     4: after
#     1: leave   return='invalid input'
#   10: after   shape()='invalid input'
#   11: before
#     1: enter   sides=3
#     2: before  sides=3
#     2: after   sides=3
#     3: before
#     3: after
#     5: before
#     5: after
#     6: before
#     6: after
#     1: leave   return='triangle'
#   11: after   shape()='triangle'
#   12: before
#     1: enter   sides=4
#     2: before  sides=4
#     2: after   sides=4
#     3: before
#     3: after
#     5: before
#     5: after
#     8: before
#     8: after
#     1: leave   return='too complicated'
#   12: after   shape()='too complicated'

