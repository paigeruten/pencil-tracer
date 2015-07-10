var shape = function (sides) {
  var name;
  switch (sides) {
    case 3:
      name = 'triangle';
      break;
    case 4:
      name = 'rectangle';
      break;
    default:
      name = 'too complicated';
      break;
  }
  return name;
};

shape(3);
shape(4);
shape(5);

// Trace:
//   1:  before  shape=/
//   1:  after   shape=<function>
//   17: before  shape=<function>
//     1:  enter   sides=3
//     2:  before  name=/
//     2:  after   name=/
//     3:  before  sides=3
//     3:  after   sides=3
//     4:  before
//     4:  after
//     5:  before  name=/
//     5:  after   name='triangle'
//     6:  before
//     6:  after
//     14: before  name='triangle'
//     14: after   name='triangle'
//     1:  leave   return='triangle'
//   17: after   shape=<function>
//   18: before  shape=<function>
//     1:  enter   sides=4
//     2:  before  name=/
//     2:  after   name=/
//     3:  before  sides=4
//     3:  after   sides=4
//     4:  before
//     4:  after
//     7:  before
//     7:  after
//     8:  before  name=/
//     8:  after   name='rectangle'
//     9:  before
//     9:  after
//     14: before  name='rectangle'
//     14: after   name='rectangle'
//     1:  leave   return='rectangle'
//   18: after   shape=<function>
//   19: before  shape=<function>
//     1:  enter   sides=5
//     2:  before  name=/
//     2:  after   name=/
//     3:  before  sides=5
//     3:  after   sides=5
//     4:  before
//     4:  after
//     7:  before
//     7:  after
//     11: before  name=/
//     11: after   name='too complicated'
//     12:  before
//     12:  after
//     14: before  name='too complicated'
//     14: after   name='too complicated'
//     1:  leave   return='too complicated'
//   19: after   shape=<function>

