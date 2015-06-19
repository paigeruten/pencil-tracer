var squareExpr = function (x) {
  return x * x;
};

function squareDecl(x) {
  return x * x;
}

var x = squareExpr(3);
var y = squareDecl(3);

// Trace: [1, 5, 9, enter(1), 2, leave(1), 10, enter(5), 6, leave(5)]
// Assert: x === 9
// Assert: y === 9

