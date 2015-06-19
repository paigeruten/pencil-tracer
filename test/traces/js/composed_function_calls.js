var double = function (x) { return x + x; }
var square = function (x) {
  return x * x;
}

var y = double(square(3));

// Trace: [1, 2, 6, enter(2), 3, leave(2), enter(1), 1, leave(1)]
// Assert: y === 18

