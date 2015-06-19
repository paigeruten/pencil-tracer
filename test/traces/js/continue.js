var x = 0, y = 0;
while (x < 3) {
  x++;
  continue;
  y++;
}

// Trace: [1, 2, 3, 4, 2, 3, 4, 2, 3, 4, 2]
// Assert: x === 3
// Assert: y === 0

