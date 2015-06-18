shape = (sides) ->
  switch sides
    when 3
      'triangle'
    when 4
      'rectangle'
    else
      'too complicated'

shape 3
shape 4
shape 5

# Trace: [1, 10, enter(1), 2, 4, leave(1), 11, enter(1), 2, 6, leave(1), 12, enter(1), 2, 8, leave(1)]
# Assert: shape(3) === 'triangle'
# Assert: shape(4) === 'rectangle'
# Assert: shape(5) === 'too complicated'

