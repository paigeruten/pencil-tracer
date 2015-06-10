f = (cb) ->
  cb 3

await
  f defer x

f ->

# Expected: [1, 4, 5, enter(1), 2, leave(1), 7, enter(1), 2, enter(7), leave(7), leave(1)]

