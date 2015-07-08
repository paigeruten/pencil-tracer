sum = 0
for x in [1, 2]
  for i in [3, 4]
    sum += i

# Assert: sum === 14

# Note: CoffeeScript prefers to use 'i' as a for-loop index variable for the
# loop on line 2. If pencil-tracer doesn't send a list of referenced variables
# to ast.compileToFragments(), the 'i' variable will be used for the loop on
# line 2, and then this test will fail.

