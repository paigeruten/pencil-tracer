{name} = {name: 'Jeremy'}
[a, [{b: c}]] = [1, [{b: 2}]]

f = (a, [b], {c}, @d, e...) ->
f 1, [2], {c: 3}, 4, 5, 6

# Trace:
#   1: before  name=/
#   1: after   name='Jeremy'
#   2: before  a=/ c=/
#   2: after   a=1 c=2
#   4: before  f=/
#   4: after   f=<function>
#   5: before
#     4: enter   a=1 b=2 c=3 @d=4 e=[5, 6]
#     4: leave   return=/
#   5: after   f()=/

