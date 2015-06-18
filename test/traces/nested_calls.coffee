g = (x) ->
  x + 1

f = (x) ->
  g x

f 3

# Trace: [1, 4, 7, enter(4), 5, enter(1), 2, leave(1), leave(4)]
# Assert: f(3) === 4

