var x = 0, y = 0;
while (x < 3) {
  x++;
  continue;
  y++;
}
x = y;

// Trace:
//   1: before  x=/ y=/
//   1: after   x=0 y=0
//   2: before  x=0
//   2: after   x=0
//   3: before  x=0
//   3: after   x=1
//   4: before
//   4: after
//   2: before  x=1
//   2: after   x=1
//   3: before  x=1
//   3: after   x=2
//   4: before
//   4: after
//   2: before  x=2
//   2: after   x=2
//   3: before  x=2
//   3: after   x=3
//   4: before
//   4: after
//   2: before  x=3
//   2: after   x=3
//   7: before  x=3 y=0
//   7: after   x=0 y=0

