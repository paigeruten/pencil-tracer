var isEven = function (n) {
  if (n % 2 === 0) {
    return true;
  }
  return false;
};

isEven(5);
isEven(6);

// Trace: [1, 8, enter(1), 2, 5, leave(1), 9, enter(1), 2, 3, leave(1)]
// Assert: !isEven(5)
// Assert: isEven(6)

