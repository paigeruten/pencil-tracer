double = (x) -> x + x
square = (x) ->
  x * x

y = double square 3

# Trace: [1, 2, 5, enter(2), 3, leave(2), enter(1), 1, leave(1)]
# Assert: y === 18

