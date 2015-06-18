id = (o) -> o

obj =
  prop1: id 1
  prop2: id 2
  prop3: id 3

# Trace: [1, 3, enter(1), 1, leave(1), enter(1), 1, leave(1), enter(1), 1, leave(1)]
# Assert: obj.prop1 === 1
# Assert: obj.prop2 === 2
# Assert: obj.prop3 === 3

