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
      type: '',
      location: {
        first_line: 1,
        first_column: 1,
        last_line: 1,
        last_column: 5
      }
    }

`type` is empty for ordinary lines. It can also be `enter` or `leave` when a
function is entered or left.

`instrumentJs` and `instrumentCoffee` take the following options:

* `traceFunc`: the function that will be called for each event (default: `'pencilTrace'`).
* `ast` (CoffeeScript only): if true, returns the instrumented AST instead of the compiled JS.
* `bare` (CoffeeScript only): if true, tells coffeescript not to wrap the output in a top-level function.

`pencil-tracer.js` is a browserified (UMD) version of the library.

## Todo

* JavaScript support
* Test more than the results of traces. In particular, test that the AST
  manipulations don't change anything about the behaviour of the input program.
* Figure out how to test async stuff (the test framework needs to wait for the
  async stuff to complete before it examines the events array, somehow).
* Allow a blacklist of node types that shouldn't be instrumented to be
  specified (`Parens` nodes can really pollute the trace).
* Maybe add a new event type for when exceptions are thrown (currently the
  trace shows a function being entered but not left).
* Eventually, track program state like values of variables.

