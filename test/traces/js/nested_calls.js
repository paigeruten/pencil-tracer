var g = function (x) {
  return x + 1;
}

var f = function (x) {
  return g(x);
}

f(3);

// Trace: [1, 5, 9, enter(5), 6, enter(1), 2, leave(1), leave(5)]
// Assert: f(3) === 4

