var nums = [1, 2, 3];
var sum = 0;
for (var i = 0;
     i < nums.length;
     i++) {
  sum += nums[i];
}

for (;;) {
  break;
}

// Trace:
//   1:  before  nums=/
//   1:  after   nums=[1, 2, 3]
//   2:  before  sum=/
//   2:  after   sum=0
//   3:  before  i=/
//   3:  after   i=0
//   4:  before  i=0 nums.length=3
//   4:  after   i=0 nums.length=3
//   6:  before  i=0 nums=[1, 2, 3] sum=0
//   6:  after   i=0 nums=[1, 2, 3] sum=1
//   5:  before  i=0
//   5:  after   i=1
//   4:  before  i=1 nums.length=3
//   4:  after   i=1 nums.length=3
//   6:  before  i=1 nums=[1, 2, 3] sum=1
//   6:  after   i=1 nums=[1, 2, 3] sum=3
//   5:  before  i=1
//   5:  after   i=2
//   4:  before  i=2 nums.length=3
//   4:  after   i=2 nums.length=3
//   6:  before  i=2 nums=[1, 2, 3] sum=3
//   6:  after   i=2 nums=[1, 2, 3] sum=6
//   5:  before  i=2
//   5:  after   i=3
//   4:  before  i=3 nums.length=3
//   4:  after   i=3 nums.length=3
//   9:  before
//   9:  after
//   10: before
//   10: after

