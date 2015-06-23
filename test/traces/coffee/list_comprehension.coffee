square = (x) -> x * x
squares = (square x for x in [1, 2, 3])

# Trace: [1, 2, 2, 2, enter(1), 1, leave(1), 2, 2, enter(1), 1, leave(1), 2, 2, enter(1), 1, leave(1)]
# Assert: squares.length === 3
# Assert: squares[0] === 1
# Assert: squares[1] === 4
# Assert: squares[2] === 9

