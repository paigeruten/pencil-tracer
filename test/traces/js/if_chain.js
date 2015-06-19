var message = function (hour) {
  if (hour < 12) {
    return 'good morning';
  } else if (hour < 18) {
    return 'good afternoon';
  } else {
    return 'good evening';
  }
};

message(6);
message(13);
message(20);

// Trace: [1, 11, enter(1), 2, 3, leave(1), 12, enter(1), 2, 4, 5, leave(1), 13, enter(1), 2, 4, 7, leave(1)]
// Assert: message(6) === 'good morning'
// Assert: message(13) === 'good afternoon'
// Assert: message(20) === 'good evening'

