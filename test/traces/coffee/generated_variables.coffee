sum = 0
for x in [1, 2]
  for i in [3, 4]
    sum += i

# Trace:
#   1: before  sum=/
#   1: after   sum=0
#   2: before
#   2: after
#   2: before  x=1
#   2: after   x=1
#     3: before
#     3: after
#     3: before  i=3
#     3: after   i=3
#       4: before  sum=0 i=3
#       4: after   sum=3 i=3
#     3: before  i=4
#     3: after   i=4
#       4: before  sum=3 i=4
#       4: after   sum=7 i=4
#   2: before  x=2
#   2: after   x=2
#     3: before
#     3: after
#     3: before  i=3
#     3: after   i=3
#       4: before  sum=7 i=3
#       4: after   sum=10 i=3
#     3: before  i=4
#     3: after   i=4
#       4: before  sum=10 i=4
#       4: after   sum=14 i=4
#
# Note: CoffeeScript prefers to use 'i' as a for-loop index variable for the
# loop on line 2. If pencil-tracer doesn't send a list of referenced variables
# to ast.compileToFragments(), the 'i' variable will be used for the loop on
# line 2, and overwritten by the inner loop, and then this test will fail.

