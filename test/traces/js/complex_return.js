var f = function() {
  return (function() {
    return 3;
  })();
};

f();

// Trace: [1, 7, enter(1), 2, enter(2), 3, leave(2), leave(1)]
// Assert: f() === 3

