f = ->
  throw new Error()

try
  f()
catch err
  'caught it'

# Trace: [1, 4, 5, enter(1), 2, 7]

# Note: not sure if there should be a leave event when the error is thrown.
# Maybe need a new kind of event for this?

