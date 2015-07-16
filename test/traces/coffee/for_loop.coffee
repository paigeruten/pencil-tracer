sum = 0
ary = [1, 2, 3]
for x in ary
  sum += x

# Trace:
#   1: before  sum=/
#   1: after   sum=0
#   2: before  ary=/
#   2: after   ary=[1, 2, 3]
#   3: before  x=1 ary=[1, 2, 3]
#   3: after   x=1 ary=[1, 2, 3]
#   4: before  sum=0 x=1
#   4: after   sum=1 x=1
#   3: before  x=2 ary=[1, 2, 3]
#   3: after   x=2 ary=[1, 2, 3]
#   4: before  sum=1 x=2
#   4: after   sum=3 x=2
#   3: before  x=3 ary=[1, 2, 3]
#   3: after   x=3 ary=[1, 2, 3]
#   4: before  sum=3 x=3
#   4: after   sum=6 x=3

