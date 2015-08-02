false && a.b.c.d;
false && a.b.c.d();
false && a.b.c.d[0]();
false && a.b.c[0].d();
false && a.b[0].c.d();
false && a[0].b.c.d();

// Trace:
//   1: before  a.b.c.d=/
//   1: after   a.b.c.d=/
//   2: before  a.b.c=/
//   2: after   a.b.c=/ d()=/
//   3: before  a.b.c.d=/
//   3: after   a.b.c.d=/ <anonymous>()=/
//   4: before  a.b.c=/
//   4: after   a.b.c=/ d()=/
//   5: before  a.b=/
//   5: after   a.b=/ d()=/
//   6: before  a=/
//   6: after   a=/ d()=/

