shape = (sides) ->
  switch sides
    when 0, 1, 2
      'invalid input'
    when 3
      'triangle'
    when 4
      'rectangle'
    else
      'too complicated'

shape 1
shape 3
shape 4
shape 5

# Trace: [1, 12, enter(1), 2, 3, 4, leave(1), 13, enter(1), 2, 3, 5, 6, leave(1), 14, enter(1), 2, 3, 5, 7, 8, leave(1), 15, enter(1), 2, 3, 5, 7, 10, leave(1)]
# Assert: shape(1) === 'invalid input'
# Assert: shape(3) === 'triangle'
# Assert: shape(4) === 'rectangle'
# Assert: shape(5) === 'too complicated'

