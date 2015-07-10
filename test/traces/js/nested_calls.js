var g = function (x) {
  return x + 1;
}

var f = function (x) {
  return g(x);
}

f(3);

// Trace:
//   1: before  g=/
//   1: after   g=<function>
//   5: before  f=/
//   5: after   f=<function>
//   9: before  f=<function>
//     5: enter   x=3
//     6: before  x=3 g=<function>
//       1: enter   x=3
//       2: before  x=3
//       2: after   x=3
//       1: leave   return=4
//     6: after   x=3 g=<function>
//     5: leave   return=4
//   9: after   f=<function>

