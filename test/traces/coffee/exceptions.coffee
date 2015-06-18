f = ->
  throw new Error()

g = ->
  try
    f()
  catch err
    'caught it'

g()

# Trace: [1, 4, 10, enter(4), 5, 6, enter(1), 2, leave(1), 8, leave(4)]
# Assert: g() === 'caught it'

