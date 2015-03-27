square = (x) -> x * x
squares = (square x for x in [1, 2, 3])

# Expected: [1, 2, 2, 2, enter(1), 1, leave(1), 2, enter(1), 1, leave(1), 2, enter(1), 1, leave(1)]

# Note: line 2 is an Assign node that contains a Parens node that contains a For
# node. That's why line 2 shows up three times in a row. TODO: have the option
# of blacklisting some node types from being instrumented, and figure out which
# ones should be blacklisted.

