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

// Trace: [1, 17, enter(1), 2, 3, 4, 5, 6, 14, leave(1), 18, enter(1), 2, 3, 4, 7, 8, 9, 14, leave(1), 19, enter(1), 2, 3, 4, 7, 11, 12, 14, leave(1)]
// Assert: shape(3) === 'triangle'
// Assert: shape(4) === 'rectangle'
// Assert: shape(5) === 'too complicated'

