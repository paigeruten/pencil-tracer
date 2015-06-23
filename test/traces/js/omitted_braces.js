var x = 0;
if (false)
  x = 1;
else if (false)
  x = 2;
else
  x = 3;

while (x === 3)
  x++;

do
  x++;
while (false);

for (;
     x === 5;
     x++)
  ;

for (var k in {a: 1})
  x++;

// Trace: [1, 2, 4, 7, 9, 10, 9, 12, 13, 14, 16, 17, 19, 18, 17, 21, 22]
// Assert: x === 7

