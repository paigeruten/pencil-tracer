var obj = { a: 1, b: 2, c: 3 };
var sum = 0;
for (var key in obj) {
  sum += obj[key];
}

var key2;
for (key2 in obj) {
  sum += obj[key2];
}

// Trace:
//   1: before  obj=/
//   1: after   obj=<object>
//   2: before  sum=/
//   2: after   sum=0
//   3: before  obj=<object>
//   3: after   obj=<object>
//   3: before  key='a'
//   3: after   key='a'
//   4: before  sum=0 obj=<object> key='a'
//   4: after   sum=1 obj=<object> key='a'
//   3: before  key='b'
//   3: after   key='b'
//   4: before  sum=1 obj=<object> key='b'
//   4: after   sum=3 obj=<object> key='b'
//   3: before  key='c'
//   3: after   key='c'
//   4: before  sum=3 obj=<object> key='c'
//   4: after   sum=6 obj=<object> key='c'
//   7: before  key2=/
//   7: after   key2=/
//   8: before  obj=<object>
//   8: after   obj=<object>
//   8: before  key2='a'
//   8: after   key2='a'
//   9: before  sum=6 obj=<object> key2='a'
//   9: after   sum=7 obj=<object> key2='a'
//   8: before  key2='b'
//   8: after   key2='b'
//   9: before  sum=7 obj=<object> key2='b'
//   9: after   sum=9 obj=<object> key2='b'
//   8: before  key2='c'
//   8: after   key2='c'
//   9: before  sum=9 obj=<object> key2='c'
//   9: after   sum=12 obj=<object> key2='c'

