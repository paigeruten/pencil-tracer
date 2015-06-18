class Animal
  constructor: (@name) ->

  move: (meters) ->
    @name + ' moved ' + meters + 'm'

class Snake extends Animal
  move: ->
    super(5) + ' by slithering'

sam = new Snake 'Sam'
sam.move()

# Trace: [1, 2, 7, 8, 11, enter(2), leave(2), 12, enter(8), 9, enter(4), 5, leave(4), leave(8)]
# Assert: sam.move() === 'Sam moved 5m by slithering'

