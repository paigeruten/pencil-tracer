var f = function() { return 'a' }

f()

// Trace: [1, 3, enter(1), 1, leave(1)]
// Assert: f() === 'a'

