f = (cb) ->
  cb 3

x = 0
if true
  await
    f defer x
  'tail'

# Trace: [1, 4, 5, 6, 7, enter(1), 2, leave(1), 8]
# Assert: x === 3

