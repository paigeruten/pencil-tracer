var i = 0;
do {
  i++;
} while (i < 3);

// Trace:
//   1: before  i=/
//   1: after   i=0
//   3: before  i=0
//   3: after   i=1
//   4: before  i=1
//   4: after   i=1
//   3: before  i=1
//   3: after   i=2
//   4: before  i=2
//   4: after   i=2
//   3: before  i=2
//   3: after   i=3
//   4: before  i=3
//   4: after   i=3

