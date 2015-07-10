var obj = {
  x: 1,
  y: 2
};

var z = 0;
with (obj) {
  z = x + y;
}

// Trace:
//   1: before  obj=/
//   1: after   obj=<object>
//   6: before  z=/
//   6: after   z=0
//   7: before  obj=<object>
//   7: after   obj=<object>
//   8: before  z=0 x=1 y=2
//   8: after   z=3 x=1 y=2

