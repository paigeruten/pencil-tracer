var obj = { a: 1, b: 2, c: 3 };
var sum = 0;
for (var key in obj) {
  sum += obj[key];
}

var key2;
for (key2 in obj) {
  sum += obj[key2];
}

// Trace: [1, 2, 3, 4, 3, 4, 3, 4, 7, 8, 9, 8, 9, 8, 9]
// Assert: sum === 12

