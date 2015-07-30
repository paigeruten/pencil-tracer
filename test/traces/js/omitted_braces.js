var x = 0;
if (false)
  x = 1;
else if (false)
  x = 2;
else
  x = 3;

while (x === 3)
  x++;

do
  x++;
while (false);

for (;
     x === 5;
     x++)
  ;

for (var k in {a: 1})
  x++;

// Trace:
//   1:  before  x=/
//   1:  after   x=0
//   2:  before
//   2:  after
//   4:  before
//   4:  after
//   7:  before  x=0
//   7:  after   x=3
//   9:  before  x=3
//   9:  after   x=3
//   10: before  x=3
//   10: after   x=4
//   9:  before  x=4
//   9:  after   x=4
//   13: before  x=4
//   13: after   x=5
//   14: before
//   14: after
//   17: before  x=5
//   17: after   x=5
//   19: before
//   19: after
//   18: before  x=5
//   18: after   x=6
//   17: before  x=6
//   17: after   x=6
//   21: before
//   21: after
//   21: before  k='a'
//   21: after   k='a'
//   22: before  x=6
//   22: after   x=7

