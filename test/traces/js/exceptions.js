var f = function() {
  throw new Error();
};

var g = function() {
  try {
    f();
  } catch (err) {
    return 'caught it';
  } finally {
    'finally';
  }
};

g();

// Trace: [1, 5, 15, enter(5), 6, 7, enter(1), 2, leave(1), 8, 9, 10, 11, leave(5)]
// Assert: g() === 'caught it'

