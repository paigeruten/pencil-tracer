fs = require "fs"
{spawn} = require "child_process"
browserify = require "browserify"
{instrumentJs, instrumentCoffee} = require "./src/index"

build = (callback) ->
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
            callback?()
      else
        console.error "failed " + err

task "build", ->
  build()

task "test", ->
  build ->
    mocha = spawn "./node_modules/.bin/mocha", ["--no-colors", "--compilers", "coffee:coffee-script/register", "test/unit"], stdio: "inherit"

    mocha.on "exit", (code) ->
      process.exit code if code isnt 0
      require "./test/traces-runner"

option "-f", "--file [FILENAME]", "program to instrument"
task "instrument", (options) ->
  code = fs.readFileSync options.file, "utf-8"
  if /\.coffee$/.test options.file
    coffee = require "coffee-script"
    console.log instrumentCoffee(options.file, code, coffee)
  else if /\.js$/.test options.file
    console.log instrumentJs(options.file, code)
  else
    console.log "Error: file must end in .js or .coffee."

