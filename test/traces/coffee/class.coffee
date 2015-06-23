class Person
  constructor: (@firstName, @lastName) ->

  name: ->
    @firstName + ' ' + @lastName

person = new Person 'Jeremy', 'Ruten'
name = person.name()

# Trace: [1, 7, enter(2), leave(2), 8, enter(4), 5, leave(4)]
# Assert: name === 'Jeremy Ruten'

