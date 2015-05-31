# pencil-tracer

`pencil-tracer` is a library that takes a CoffeeScript program as input, and outputs instrumented code that records a line-by-line trace of the program's execution when it runs. It borrows some code from [`coffee-coverage`](https://github.com/benbria/coffee-coverage), which also outputs instrumented CoffeeScript.

This is the pre-project for my [GSoC 2015](https://www.google-melange.com/gsoc/homepage/google/gsoc2015) proposal. It is the first step in creating a better visual debugger for [Pencil Code](http://pencilcode.net/).

## Install

    $ npm install pencil-tracer

## Build

    $ cake build
    $ cake test

## Usage

To use as a library:

    {instrumentCoffee} = require "pencil-tracer"
    js = instrumentCoffee fileName, fileContents, options

For now, `pencil-tracer` gives you a single `instrumentCoffee` function, which takes a filename and file contents as arguments, instruments the given CoffeeScript code, and returns the compiled JavaScript as a string. For each line that is executed in the outputted JS, `pencilTrace(event)` will be called, where `event` is an object of the form `{ location: { first_line: .., first_column: .., last_line: .., last_column: .. }, type: .. }`, `type` being either `"enter"` or `"leave"` or `""`, depending on whether a function is being entered or left. For now, it's up to the user of the library to implement `pencilTrace()`.

`instrument` can take some options as its third argument:

* `traceFunc`: the function that will be called for each event (default: `"pencilTrace"`).
* `compiler`: the CoffeeScript module to use (this allows you to use instrument Iced CoffeeScript, for example)
* `ast`: if true, returns the instrumented AST instead of the compiled JS.

## Example

I've included a little binary for testing/showing-off purposes that lets you either instrument a CoffeeScript file and see the JavaScript or AST output, or see the results of an actual trace of a CoffeeScript program. The `animate` command gives you a nice flip-animation of the trace. It prints out the code, highlighting the part of the code that is currently executing. Code that is executing is highlighted in green, functions that are being entered are highlighted in yellow, and functions that are being left are highlighted in red. Run it like this:

    $ pencil-tracer animate test/traces/inheritance.coffee

Here are the other three commands in action:

    $ pencil-tracer trace test/traces/inheritance.coffee
          1:1-6:1
          2:3-6:1
          7:1-10:1
          8:3-10:1
          11:1-11:21
    enter 2:16-2:25
    leave 2:16-2:25
          12:1-12:10
    enter 8:9-10:1
          9:5-9:31
    enter 4:9-6:1
          5:5-5:36
    leave 4:9-6:1
    leave 8:9-10:1

    $ pencil-tracer instrument test/traces/while_loop.coffee
    (function() {
      var i;

      pencilTrace({
        location: {
          first_line: 1,
          first_column: 1,
          last_line: 1,
          last_column: 5
        },
        type: ''
      });

      i = 0;

      pencilTrace({
        location: {
          first_line: 2,
          first_column: 1,
          last_line: 2,
          last_column: 11
        },
        type: ''
      });

      while (i < 3) {
        pencilTrace({
          location: {
            first_line: 3,
            first_column: 3,
            last_line: 3,
            last_column: 5
          },
          type: ''
        });
        i++;
      }

    }).call(this);

    $ pencil-tracer ast test/traces/simple.coffee
    Block
      Block
        Call
          Value "pencilTrace"
          Value
            Obj
              Assign
                Value "location"
                Value
                  Obj
                    Assign
                      Value "first_line"
                      Value "1"
                    Assign
                      Value "first_column"
                      Value "1"
                    Assign
                      Value "last_line"
                      Value "1"
                    Assign
                      Value "last_column"
                      Value "5"
              Assign
                Value "type"
                Value "''"
      Assign
        Value "x"
        Value "3"
      Block
        Call
          Value "pencilTrace"
          Value
            Obj
              Assign
                Value "location"
                Value
                  Obj
                    Assign
                      Value "first_line"
                      Value "2"
                    Assign
                      Value "first_column"
                      Value "1"
                    Assign
                      Value "last_line"
                      Value "2"
                    Assign
                      Value "last_column"
                      Value "9"
              Assign
                Value "type"
                Value "''"
      Assign
        Value "y"
        Op *
          Value "x"
          Value "4"

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

