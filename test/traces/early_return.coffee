isEven = (n) ->
  return yes if n % 2 == 0
  return no

isEven(5)
isEven(6)

# Trace: [1, 5, enter(1), 2, 3, leave(1), 6, enter(1), 2, 2, leave(1)]
# Assert: !isEven(5)
# Assert: isEven(6)

