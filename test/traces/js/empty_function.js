var f = function() {};

f();

// Trace:
//   1: before  f=/
//   1: after   f=<function>
//   3: before  f=<function>
//     1: enter
//     1: leave   return=/
//   3: after   f=<function>

