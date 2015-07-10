var f = function() { return 'a' }

f()

// Trace:
//   1: before  f=/
//   1: after   f=<function>
//   3: before  f=<function>
//     1: enter
//     1: before
//     1: after
//     1: leave   return='a'
//   3: after   f=<function>

