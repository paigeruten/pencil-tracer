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

// Trace:
//   1:  before  f=/
//   1:  after   f=<function>
//   5:  before  g=/
//   5:  after   g=<function>
//   15: before
//     5: enter
//     7: before
//       1: enter
//       2: before
//       2: after   Error()=<object>
//       1: leave   throw=<object>
//     9: before
//     9: after
//     11: before
//     11: after
//     5: leave   return='caught it'
//   15: after   g()='caught it'

