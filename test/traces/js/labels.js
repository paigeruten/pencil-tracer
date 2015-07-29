var i, j;

loop1:
for (i = 0; i < 2; i++) {
  loop2:
  for (j = 0; j < 2; j++) {
    if (i == 0 && j == 0) {
      break loop1;
    }
  }
}

// Trace:
//   1: before  i=/ j=/
//   1: after   i=/ j=/
//   4: before  i=/
//   4: after   i=0
//   4: before  i=0
//   4: after   i=0
//   6: before  j=/
//   6: after   j=0
//   6: before  j=0
//   6: after   j=0
//   7: before  i=0 j=0
//   7: after   i=0 j=0
//   8: before
//   8: after

