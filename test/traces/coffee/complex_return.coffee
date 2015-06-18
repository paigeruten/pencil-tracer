f = ->
  return (-> 3)()

f()

# Trace: [1, 4, enter(1), 2, enter(2), 2, leave(2), leave(1)]
# Assert: f() === 3

