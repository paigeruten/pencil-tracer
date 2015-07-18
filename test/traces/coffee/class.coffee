class Person
  constructor: (@firstName, @lastName) ->

  name: ->
    @firstName + ' ' + @lastName

person = new Person 'Jeremy', 'Ruten'
name = person.name()

# Trace:
#   1: before  Person=<function>
#   1: after   Person=<function>
#   2: before
#   2: after
#   4: before
#   4: after
#   7: before  person=/
#     2: enter   @firstName='Jeremy' @lastName='Ruten'
#     2: leave   return=/
#   7: after   person=<object>
#   8: before  person=<object> name=/
#     4: enter
#     5: before  @firstName='Jeremy' @lastName='Ruten'
#     5: after   @firstName='Jeremy' @lastName='Ruten'
#     4: leave   return='Jeremy Ruten'
#   8: after   person=<object> name='Jeremy Ruten'

