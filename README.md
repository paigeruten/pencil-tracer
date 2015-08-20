# pencil-tracer [![Build Status](https://travis-ci.org/yjerem/pencil-tracer.svg?branch=master)](https://travis-ci.org/yjerem/pencil-tracer)

`pencil-tracer` is a library that takes a JavaScript or CoffeeScript program as
input, and outputs instrumented JavaScript that records a line-by-line trace of
the program's execution when it runs.

This library was developed for [Pencil Code](https://pencilcode.net/) as a
[GSoC 2015](https://www.google-melange.com/gsoc/homepage/google/gsoc2015)
project.

## Install

    $ npm install pencil-tracer

## Build

    $ cake build
    $ cake test

## Try it

To quickly try it out, clone this repository and run these `cake` tasks.

    $ cake -f test/traces/js/simple.js instrument
    $ cake -f test/traces/js/simple.js trace

The first task instruments the given file and shows you the output. The second
task does a trace on the given file and shows you the trace.

## Usage

```javascript
var pencilTracer = require('pencil-tracer');

// javascript
var output = pencilTracer.instrumentJs('var x = 3;');

// coffeescript
var coffeeScript = require('coffee-script');
var output = pencilTracer.instrumentCoffee('x = 3', coffeeScript);
```

Two functions are exported: `instrumentJs` and `instrumentCoffee`.
`instrumentJs` takes some code and an options object. `instrumentCoffee` takes
the same arguments, as well as a CoffeeScript compiler as the second argument
(this lets you use a specific version of CoffeeScript, including Iced
CoffeeScript).

Both functions return a string containing the instrumented code. When run, the
instrumented code will make a call to `pencilTrace()` for each line, passing it
an object like this:

```javascript
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
```

`type` is `'before'` or `'after'` for normal executed code. It can also be
`'enter'` or `'leave'` when a function is entered or left.

`instrumentJs` and `instrumentCoffee` take the following options:

* `traceFunc`: the function that will be called for each event (default:
  `'pencilTrace'`).
* `ast`: if true, returns the instrumented AST instead of the compiled JS.
* `bare` (CoffeeScript only): if true, tells coffeescript not to wrap the
  output in a top-level function.
* `sourceMap`: if true, returns a source map as well as the instrumented code.
* `includeArgsStrings`: if true, each tracked function call will include a
  string containing the arguments passed to the function.

`pencil-tracer.js` is a browserified (UMD) version of the library.

## Obtaining a trace

All `pencil-tracer` gives you is a string of instrumented JavaScript. It is up
to you to run that code and collect the events. Here is an example program that
does that, using `Contextify` to the run the instrumented code in a sandbox.

```javascript
var pencilTracer = require('pencil-tracer');
var Contextify = require('contextify');

var code = pencilTracer.instrumentJs('var x = 3;');

var sandbox = {
  pencilTrace: function(event) {
    sandbox.pencilTraceEvents.push(event);
  },
  pencilTraceEvents: []
};

Contextify(sandbox);
sandbox.run(code);

console.log(sandbox.pencilTraceEvents);
```

## What gets traced

For the most part, every ordinary statement gets instrumented with `'before'`
and `'after'` events. For example,

```javascript
var x;
x = 1;
x++;
```

This program would be instrumented like so:

```javascript
<var x;>
<x = 1;>
<x++;>
```

Where `<` is shorthand for `pencilTrace('before', ...);` and `>` is shorthand
for `pencilTrace('after', ...);`. I'll continue using this shorthand for the
rest of this section.

### Functions

Function declarations get instrumented like an ordinary statement.

```javascript
// javascript
<function square(x) {
  return x * x;
}>
```

### Empty statements

In JavaScript, a semicolon by itself is called an empty statement. Each empty
statement gets instrumented like any other statement.

```javascript
// javascript
<;>
```

### `if` and `unless` statements

The condition expression is instrumented in `if` and `unless` statements.

```javascript
// javascript
if (<false>) {
  ...
} else if (<true>) {
  ...
} else {
  ...
}
```

```coffeescript
# coffeescript
if <false>
  ...
else if <true>
  ...
else
  ...

<i += 1> unless <false>
```

### `with` statements

The object expression is instrumented.

```javascript
// javascript
with (<obj>) {
  ...
}
```

### `switch` statements

The expression being switched on is instrumented, and each case expression is
instrumented.

```javascript
// javascript
switch (<3>) {
  case <1>:
    ...
  case <2>:
    ...
  case <3>:
    ...
  default:
    ...
}
```

```coffeescript
# coffeescript
switch <3>
  when <1> then ...
  when <2>, <3> then ...
  else ...
```

### `return` and `throw` statements

The expression being returned or thrown is instrumented.

```javascript
// javascript
return <true>;
throw <"error!">;
```

```coffeescript
# coffeescript
return <true>
throw <"error!">
```

### `try` statements

Only the error variable of the `catch` clause is instrumented, if it exists.

```javascript
// javascript
try {
  ...
} catch (<err>) {
  ...
} finally {
  ...
}
```

```coffeescript
# coffeescript
try
  ...
catch <err>
  ...
finally
  ...
```

### `while` loops

The loop condition is instrumented.

```javascript
// javascript
while (<true>) {
  ...
}
```

```coffeescript
# coffeescript
while <true>
  ...
```

Note: the `loop` keyword in CoffeeScript is syntax sugar for `while true`, so
it will be instrumented in the same way.

### `do..while` loops

The loop condition is instrumented.

```javascript
// javascript
do {
  ...
} while (<true>);
```

### `for` loops

Each of the three expressions in the head of the `for` loop is instrumented, if
they exist.

```javascript
// javascript
for (<var i = 0>; <i != 3>; <i++>) {
  ...
}
```

In the case of a `for (;;) { ... }` loop, the middle conditional expression is
instrumented.

```javascript
// javascript
for (;<>;) {
  ...
}
```

### `for in` loops

The object being iterated over and the variables being assigned to are both
instrumented.

```javascript
// javascript
for (<key> in <obj>) {
  ...
}
```

```coffeescript
# coffeescript
for <key, value> of <obj>
  ...
for <elem, idx> in <ary>
  ...
```

### Sequence expressions

The comma operator in JavaScript is known as a sequence expression, and even
though it can be used to put multiple statement-like expressions in a single
expression, the subexpressions are not instrumented in any special way.

```javascript
// javascript
<x = (i++, i++, i);>
```

```coffeescript
# coffeescript
<x = (i += 1; i += 1; i)>
```

### Classes

The head of the class is instrumented, and each method definition is
instrumented.

```coffeescript
# coffeescript
<class Person extends Entity>
  <constructor: (@firstName, @lastName) ->
    ...>

  <fullName: ->
    ...>
```

### Loop guards

CoffeeScript allows `when` clauses on its loops, which act as guards. If a loop
has a guard, the guard expression will be instrumented.

```coffeescript
# coffeescript
for <n> in <[1, 2, 3, 4, 5]> when <n % 2 is 0>
  ...
```

### List comprehensions

CoffeeScript's list comprehensions are just ordinary loops, which were covered
above, but it may helpful to show an example of how they are instrumented.

```coffeescript
# coffeescript
<odd_squares = (<n * n> for <n> in <[1, 2, 3, 4, 5]> when <(n * n) % 2 is 1>)>
```

## Full Example

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

## Events

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

### `'before'` Event

Triggered before each instrumented statement. A `vars` property contains the
variables and values used in the original code that this event is associated
with. Each object in `vars` has a `name` property and a `value` property.

```javascript
{
  type: 'before',
  location: { ... },
  vars: [ ... ]
}
```

### `'after'` Event

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

### `'enter'` Event

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

### `'leave'` Event

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

## Blocks

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

