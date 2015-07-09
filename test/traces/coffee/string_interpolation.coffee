firstName = 'Jeremy'
lastName = 'Ruten'
fullName = "#{firstName} #{lastName}"

# Trace:
#   1: before  firstName=/
#   1: after   firstName='Jeremy'
#   2: before  lastName=/
#   2: after   lastName='Ruten'
#   3: before  fullName=/ firstName='Jeremy' lastName='Ruten'
#   3: after   fullName='Jeremy Ruten' firstName='Jeremy' lastName='Ruten'

