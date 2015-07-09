sum = 0
for x in [1, 2, 3]
  sum += x

# Trace:
#   1: before  sum=/
#   1: after   sum=0
#   2: before
#     2: after   x=1
#     3: before  sum=0 x=1
#     3: after   sum=1 x=1
#     2: after   x=2
#     3: before  sum=1 x=2
#     3: after   sum=3 x=2
#     2: after   x=3
#     3: before  sum=3 x=3
#     3: after   sum=6 x=3

