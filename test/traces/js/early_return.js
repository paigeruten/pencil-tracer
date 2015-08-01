var isEven = function (n) {
  if (n % 2 === 0) {
    return true;
  }
  return false;
};

isEven(5);
isEven(6);

// Trace:
//   1: before  isEven=/
//   1: after   isEven=<function>
//   8: before
//     1: enter   n=5
//     2: before  n=5
//     2: after   n=5
//     5: before
//     5: after
//     1: leave   return=false
//   8: after   isEven()=false
//   9: before
//     1: enter   n=6
//     2: before  n=6
//     2: after   n=6
//     3: before
//     3: after
//     1: leave   return=true
//   9: after   isEven()=true

