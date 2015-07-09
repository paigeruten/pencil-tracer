class Animal
  constructor: (@name) ->

  move: (meters) ->
    @name + ' moved ' + meters + 'm'

class Snake extends Animal
  move: ->
    super(5) + ' by slithering'

sam = new Snake 'Sam'
sam.move()

# Trace:
#   1:  before  Animal=/
#   1:  after   Animal=<function>
#   7:  before  Snake=/ Animal=<function>
#   7:  after   Snake=<function> Animal=<function>
#   11: before  sam=/ Snake=<function>
#     2: enter   name='Sam'
#     2: leave   return=/
#   11: after   sam=<object> Snake=<function>
#   12: before  sam=<object>
#     8: enter
#     9: before
#       4: enter   meters=5
#       5: before  @name='Sam' meters=5
#       5: after   @name='Sam' meters=5
#       4: leave   return='Sam moved 5m'
#     9: after
#     8: leave   return='Sam moved 5m by slithering'
#   12: after   sam=<object>

