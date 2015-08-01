(function(){
  this;
  this(1);
  this.call;
  this.call(null, 2);
}).call(Math.floor);

// Trace:
//   1: before  Math.floor=<function>
//     1: enter
//     2: before  this=<function>
//     2: after   this=<function>
//     3: before
//     3: after   this()=1
//     4: before  this.call=<function>
//     4: after   this.call=<function>
//     5: before  this=<function>
//     5: after   this=<function> call()=2
//     1: leave   return=/
//   1: after   Math.floor=<function> call()=/

