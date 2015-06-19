var square = function (x) {
  return x * x;
};

function plus1(x) {
  return x + 1;
}

var y = plus1(square(3));

// Trace: [1, 5, 9, enter(1), 2, leave(1), enter(5), 6, leave(5)]
// Assert: y === 10

