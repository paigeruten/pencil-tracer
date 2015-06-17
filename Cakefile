fs = require "fs"
{spawn} = require "child_process"
browserify = require "browserify"

task "build", ->
  # Compile CoffeeScript to JavaScript
  coffee = spawn "./node_modules/.bin/coffee", ["-c", "-o", "lib", "src"]
  coffee.stderr.on "data", (data) ->
    process.stderr.write data.toString()
  coffee.stdout.on "data", (data) ->
    print data.toString()

  coffee.on "exit", ->
    # Make a browserified version called pencil-tracer.js
    b = browserify(standalone: "pencilTracer")
    b.add "./lib/index.js"
    b.bundle (err, result) ->
      if not err
        fs.writeFile "pencil-tracer.js", result, (err) ->
          if err
            console.error "browserify failed: " + err
      else
        console.error "failed " + err

task "test", ->
  require "./test/test"

