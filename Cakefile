fs = require "fs"
{spawn} = require "child_process"
browserify = require "browserify"

task "build", ->
  # Compile CoffeeScript to JavaScript
  coffee = spawn "./node_modules/.bin/coffee", ["-c", "-o", "lib", "src"], stdio: "inherit"

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
  mocha = spawn "./node_modules/.bin/mocha", ["--no-colors", "--compilers", "coffee:coffee-script/register", "test/unit"], stdio: "inherit"

  mocha.on "exit", (code) ->
    process.exit code if code isnt 0
    require "./test/traces-runner"

