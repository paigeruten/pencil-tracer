i = 0
loop
  i++
  break if i == 2

# Trace:
#   1: before  i=/
#   1: after   i=0
#   2: before
#     2: after
#     3: before  i=0
#     3: after   i=1
#     4: before  i=1
#     4: after   i=1
#     2: after
#     3: before  i=1
#     3: after   i=2
#     4: before  i=2
#     4: after   i=2
#     4: before
#     4: after

