var f = function() {
  return (function() {
    return 3;
  })();
};

f();

// Trace:
//   1: before  f=/
//   1: after   f=<function>
//   7: before  f=<function>
//     1: enter
//     2: before
//       2: enter
//       3: before
//       3: after
//       2: leave   return=3
//     2: after
//     1: leave   return=3
//   7: after

