firstName = "Jeremy"
lastName = "Ruten"
fullName = "#{firstName} #{lastName}"

# Expected: [1, 2, 3, 3, 3, 3]

# Note: line 3 has an event for the Assign, one for a Parens containing all the
# string concatenations, and one for each of the two interpolated expressions.

