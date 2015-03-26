# coffee-tracer

`coffee-tracer` is a library that takes a CoffeeScript program as input, and outputs instrumented code that records a line-by-line trace of the program's execution when it runs. It borrows some code from [`coffee-coverage`](https://github.com/benbria/coffee-coverage), which also outputs instrumented CoffeeScript.

This is the pre-project for my [GSoC 2015](https://www.google-melange.com/gsoc/homepage/google/gsoc2015) proposal. It is the first step in creating a better visual debugger for [Pencil Code](http://pencilcode.net/).

## Install

It's published to npm, so just type:

    $ npm install coffee-tracer

## Usage

For now, `coffee-tracer` simply exposes a single `instrument` function, which takes a filename and file contents as arguments, instruments the given CoffeeScript code, and returns the compiled JavaScript as a string. For each line that is executed in the outputted JS, `ide.trace(event)` will be called, where event is an object of the form `{ line: ..., column: ..., type: ... }`, `type` being either `"enter"` or `"leave"` or `""`, depending on whether a function is being entered or left. For now, it's up to the user of the library to implement `ide.trace()`.

## Example

I've included a little binary for testing/showing-off purposes that lets you either instrument a CoffeeScript file and see the JavaScript output, or see the results of an actual trace on a CoffeeScript program. Here are the two commands in action:

    $ cat test.coffee
    square = (x) -> x * x

    y = 2
    for _ in [1..5]
      y = square y

    # print it out
    console.log y

    $ coffee test.coffee
    4294967296
    $ coffee-tracer instrument test.coffee
    (function() {
      var _, i, square, y;

      ide.trace({
        line: 1,
        column: 0
      });

      square = function(x) {
        ide.trace({
          line: 1,
          column: 16
        });
        return x * x;
      };

      ide.trace({
        line: 3,
        column: 0
      });

      y = 2;

      ide.trace({
        line: 4,
        column: 0
      });

      for (_ = i = 1; i <= 5; _ = ++i) {
        ide.trace({
          line: 5,
          column: 2
        });
        y = square(y);
      }

      ide.trace({
        line: 8,
        column: 0
      });

      console.log(y);

    }).call(this);

    $ coffee-tracer trace test.coffee
    4294967296
    [ { line: 1, column: 0 },
      { line: 3, column: 0 },
      { line: 4, column: 0 },
      { line: 5, column: 2 },
      { line: 1, column: 16 },
      { line: 5, column: 2 },
      { line: 1, column: 16 },
      { line: 5, column: 2 },
      { line: 1, column: 16 },
      { line: 5, column: 2 },
      { line: 1, column: 16 },
      { line: 5, column: 2 },
      { line: 1, column: 16 },
      { line: 8, column: 0 } ]

## TODO

By the proposal deadline I will:

* Recognize "Enter" and "Leave" events in the trace
* Write tests

