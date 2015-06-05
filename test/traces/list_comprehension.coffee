square = (x) -> x * x
squares = (square x for x in [1, 2, 3])

# Expected: [1, 2, 2, enter(1), 1, leave(1), 2, enter(1), 1, leave(1), 2, enter(1), 1, leave(1)]

