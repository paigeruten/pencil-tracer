var double = function (x) { return x + x; }
var square = function (x) {
  return x * x;
}

var y = double(square(3));

// Trace:
//   1: before  double=/
//   1: after   double=<function>
//   2: before  square=/
//   2: after   square=<function>
//   6: before  y=/ double=<function> square=<function>
//     2: enter   x=3
//     3: before  x=3
//     3: after   x=3
//     2: leave   return=9
//     1: enter   x=9
//     1: before  x=9
//     1: after   x=9
//     1: leave   return=18
//   6: after   y=18 double=<function> square=<function>

