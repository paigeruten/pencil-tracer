var obj = {
  x: 1,
  y: 2
};

var z = 0;
with (obj) {
  z = x + y;
}

// Trace: [1, 6, 7, 8]
// Assert: z === 3

