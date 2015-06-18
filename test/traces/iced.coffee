f = (cb) ->
  cb 3

x = 0
await
  f defer x

f ->

# Trace: [1, 4, 5, 6, enter(1), 2, leave(1), 8, enter(1), 2, enter(8), leave(8), leave(1)]
# Assert: x === 3

