fs = require "fs"
util = require "util"
{spawn} = require "child_process"
browserify = require "browserify"
Contextify = require "contextify"
{instrumentJs, instrumentCoffee} = require "./src/index"

option "-f", "--file [FILENAME]", "input program for 'instrument', 'ast', and 'trace' tasks"
option "-i", "--iced", "use Iced CoffeeScript for 'instrument', 'ast', and 'trace' tasks"
option "-v", "--vars", "track variables for 'instrument', 'ast', and 'trace' tasks"

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
      suite = spawn "./node_modules/.bin/coffee", ["test/suite-runner.coffee"], stdio: "inherit"
      suite.on "exit", (code) ->
        process.exit code if code isnt 0
        require "./test/traces-runner"

task "instrument", (options) ->
  code = fs.readFileSync options.file, "utf-8"
  if /\.coffee$/.test options.file
    coffee = if options.iced then require("iced-coffee-script") else require("coffee-script")
    console.log instrumentCoffee(options.file, code, coffee, bare: true, trackVariables: options.vars)
  else if /\.js$/.test options.file
    console.log instrumentJs(options.file, code)
  else
    console.log "Error: file must end in .js or .coffee."
    process.exit 1

task "ast", (options) ->
  code = fs.readFileSync options.file, "utf-8"
  if /\.coffee$/.test options.file
    coffee = if options.iced then require("iced-coffee-script") else require("coffee-script")
    console.log instrumentCoffee(options.file, code, coffee, ast: true, bare: true, trackVariables: options.vars).toString()
  else
    console.log "Error: file must end in .coffee."
    process.exit 1

task "trace", (options) ->
  code = fs.readFileSync options.file, "utf-8"
  if /\.coffee$/.test options.file
    coffee = if options.iced then require("iced-coffee-script") else require("coffee-script")
    code = instrumentCoffee(options.file, code, coffee, bare: true, trackVariables: options.vars)
  else if /\.js$/.test options.file
    code = instrumentCoffee(options.file, code)
  else
    console.log "Error: file must end in .js or .coffee."
    process.exit 1

  sandbox =
    pencilTrace: (event) -> sandbox.pencilTraceEvents.push(event)
    pencilTraceEvents: []
    console: console
  Contextify sandbox
  sandbox.run code

  console.log util.inspect(sandbox.pencilTraceEvents, showHidden: false, depth: null)

