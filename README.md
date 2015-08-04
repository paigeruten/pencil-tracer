# pencil-tracer [![Build Status](https://travis-ci.org/yjerem/pencil-tracer.svg?branch=master)](https://travis-ci.org/yjerem/pencil-tracer)

`pencil-tracer` is a library that takes a JavaScript or CoffeeScript program as input, and outputs instrumented JavaScript that records a line-by-line trace of the program's execution when it runs.

## Install

    $ npm install pencil-tracer

## Build

    $ cake build
    $ cake test

## Usage

    var pencilTracer = require('pencil-tracer');

    // javascript
    var output = pencilTracer.instrumentJs('myfile.js', 'var x = 3;');

    // coffeescript
    var coffeeScript = require('coffee-script');
    var output = pencilTracer.instrumentCoffee('myfile.coffee', 'x = 3', coffeeScript);

Two functions are exported: `instrumentJs` and `instrumentCoffee`. `instrumentJs` takes a file name, some code, and an options object. `instrumentCoffee` takes the same arguments, as well as a CoffeeScript compiler as the third argument (this lets you use a specific version of CoffeeScript, including Iced CoffeeScript).

Both functions return a string containing the instrumented code. When run, the instrumented code will make a call to `pencilTrace()` for each line, passing it an object like this:

    {
      type: 'after',
      location: {
        first_line: 1,
        first_column: 1,
        last_line: 1,
        last_column: 5
      },
      vars: [{ name: 'x', value: 3 }]
    }

`type` is `before` or `after` for normal executed code. It can also be `enter`
or `leave` when a function is entered or left.

`instrumentJs` and `instrumentCoffee` take the following options:

* `traceFunc`: the function that will be called for each event (default: `'pencilTrace'`).
* `ast`: if true, returns the instrumented AST instead of the compiled JS.
* `bare` (CoffeeScript only): if true, tells coffeescript not to wrap the output in a top-level function.
* `includeArgsStrings`: if true, each tracked function call will include a string containing the arguments passed to the function

`pencil-tracer.js` is a browserified (UMD) version of the library.

## Documentation

### Full Example

A program's execution can be traced by collecting the events that are triggered
by the instrumented code. This simple program demonstrates the four types of
events that can be triggered:

```javascript
var square = function (x) {
  return x * x;
};

var y = square(3);
```

Here is what the program looks like after being instrumented:

```javascript
var _returnVar;

pencilTrace({type: 'before', location: {first_line: 1, ...}, vars: [{name: 'square', value: square, functionDef: true}]});
var square = function (x) {
  var _returnOrThrow = { type: 'return', value: undefined };
  pencilTrace({type: 'enter', location: {first_line: 1, ...}, vars: [{name: 'x', value: x}]});
  try {
    pencilTrace({type: 'before', location: {first_line: 2, ...}, vars: [{name: 'x', value: x}]});
    _returnOrThrow.value = x * x;
    pencilTrace({type: 'after', location: {first_line: 2, ...}, vars: [{name: 'x', value: x}]});
    return _returnOrThrow.value;
  } catch (err) {
    _returnOrThrow.type = 'throw';
    _returnOrThrow.value = err;
    throw err;
  } finally {
    pencilTrace({type: 'leave', location: {first_line: 1, ...}, returnOrThrow: _returnOrThrow});
  }
};
pencilTrace({type: 'after', location: {first_line: 1, ...}, vars: [{name: 'square', value: square, functionDef: true}]});

pencilTrace({type: 'before', location: {first_line: 5, ...}, vars: [{name: 'y', value: y}]});
var y = (_returnVar = square(3));
pencilTrace({type: 'after', location: {first_line: 5, ...}, vars: [{name: 'y', value: y}], functionCalls: [{name: 'square', value: _returnVar}]});
```

(The `location` property also includes `first_column`, `last_line`, and
`last_column` fields, which are left out for readability here.)

Each event is an object with a `type` of either `'before'`, `'after'`,
`'enter'`, or `'leave'`. You can collect these events into a full trace by
providing a `pencilTrace()` implementation like this:

```javascript
var pencilTraceEvents = [];
var pencilTrace = function (event) {
  pencilTraceEvents.push(event);
}
```

This would produce the following trace of the program above:

```javascript
[{type: 'before', location: {first_line: 1, ...}, vars: [{name: 'square', value: undefined, functionDef: true}]},
 {type: 'after',  location: {first_line: 1, ...}, vars: [{name: 'square', value: <function>, functionDef: true}]},
 {type: 'before', location: {first_line: 5, ...}, vars: [{name: 'y', value: undefined}]},
 {type: 'enter',  location: {first_line: 1, ...}, vars: [{name: 'x', value: 3}]},
 {type: 'before', location: {first_line: 2, ...}, vars: [{name: 'x', value: 3}]},
 {type: 'after',  location: {first_line: 2, ...}, vars: [{name: 'x', value: 3}]},
 {type: 'leave',  location: {first_line: 1, ...}, returnOrThrow: {type: 'return', value: 9},
 {type: 'after',  location: {first_line: 5, ...}, vars: [{name: 'y', value: 9}], functionCalls: [{name: 'square', value: 9}]}]
```

As this example shows, each statement in the original program will trigger a
`'before'` and `'after'` event (with variable values that are used in that
statement), and each instrumented function will trigger an `'enter`' event
(with argument values) and a `'leave'` event (with either the return value or
the the thrown error in the case of an exception).

### Events

Every event has `type` and `location` properties. `location` is the start and
end location of the original code that this event is associated with.

```javascript
{
  type: 'before' or 'after' or 'enter' or 'leave',
  location: {
    first_line: 1-indexed integer,
    first_column: 1-indexed integer,
    last_line: 1-indexed integer,
    last_column: 1-indexed integer
  },
  ...
}
```

#### `'before'` Event

Triggered before each instrumented statement. A `vars` property contains the
variables and values used in the original code that this event is associated
with. The `vars` object has variable names for keys, and variable values as
values.

```javascript
{
  type: 'before',
  location: { ... },
  vars: [ ... ]
}
```

#### `'after'` Event

For every `'before'` event, there is an `'after'` event with the same
`location` and the same variable names in `vars`, but if any variables were
updated by the code that this event is associated with, their new values will
be available in `vars`. `after` events also contain a `functionCalls`
property containing names and values of function calls used in the code.

```javascript
{
  type: 'after',
  location: { ... },
  vars: [ ... ],
  functionCalls: [ ... ]
}
```

#### `'enter'` Event

Triggered at the beginning of a body of a function. The `vars` property contains
argument names and values. The `location` will give the start and end of the
entire function body.

```javascript
{
  type: 'enter',
  location: { ... },
  vars: [ ... ]
}
```

#### `'leave'` Event

Triggered after a function returns or throws an error. The `returnOrThrow`
property contains an object with two properties: `type` tells you whether the
function returned normally or threw an error, and `value` tells you the return
value or the error object that was thrown. The `location` will be the same as
the `'enter'` event's `location`.

```javascript
{
  type: 'leave',
  location: { ... },
  returnOrThrow: {
    type: 'return' or 'throw',
    value: ...
  }
}
```

### Blocks

Statements containing blocks, such as if statements and loops, are handled
differently than ordinary statements. For example, consider this while loop:

```javascript
var x = 3;
while (x--) {
  console.log(x);
}
```

Instead of instrumenting it like this:

```javascript
var x = 3;
pencilTrace({type: 'before', ...});
while (x--) {
  console.log(x);
}
pencilTrace({type: 'after', ...});
```

It's much more useful to instrument it like this:

```javascript
var x = 3;
var _temp;
while (pencilTrace({type: 'before', ...}), _temp = x--, pencilTrace({type: 'after', ...}), _temp) {
  console.log(x);
}
```

Here we instrument the conditional expression of the while loop. This way we
can show that the condition is being executed on every iteration, and we can
track how the value `x` is being changed.

If statements, switch statements, and for loops are instrumented similarly.

