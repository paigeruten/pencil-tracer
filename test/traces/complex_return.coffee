f = ->
  return (-> 3)()

f()

# Expected: [1, 4, enter(1), 2, 2, enter(2), 2, leave(2), leave(1)]

