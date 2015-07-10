var squareExpr = function (x) {
  return x * x;
};

function squareDecl(x) {
  return x * x;
}

var x = squareExpr(3);
var y = squareDecl(3);

// Trace:
//   1:  before  squareExpr=/
//   1:  after   squareExpr=<function>
//   5:  before  squareDecl=<function>
//   5:  after   squareDecl=<function>
//   9:  before  x=/ squareExpr=<function>
//     1: enter   x=3
//     2: before  x=3
//     2: after   x=3
//     1: leave   return=9
//   9:  after   x=9 squareExpr=<function>
//   10: before  y=/ squareDecl=<function>
//     5: enter   x=3
//     6: before  x=3
//     6: after   x=3
//     5: leave   return=9
//   10: after   y=9 squareDecl=<function>

