var f = function() {
  throw new Error();
};

var g = function() {
  try {
    f();
  } catch (err) {
    return 'caught it';
  }
};

g();

// Trace: [1, 5, 13, enter(5), 7, enter(1), 2, leave(1), 9, leave(5)]
// Assert: g() === 'caught it'

