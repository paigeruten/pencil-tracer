# This instruments each test file from CoffeeScript's test suite and runs the
# result. Most of the code in this file is borrowed from CoffeeScript's
# Cakefile.

fs = require "fs"
path = require "path"
Contextify = require "contextify"
assert = require "assert"

{instrumentCoffee} = require "../lib/index"
coffeeScript = if process.argv[2] is "iced" then require("iced-coffee-script") else require("coffee-script")

bold = red = green = reset = ''
unless process.env.NODE_DISABLE_COLORS
  bold  = '\x1B[0;1m'
  red   = '\x1B[0;31m'
  green = '\x1B[0;32m'
  reset = '\x1B[0m'

log = (message, color, explanation) ->
  console.log color + message + reset + ' ' + (explanation or '')

runTests = (CoffeeScript, testsDir) ->
  CoffeeScript.register()
  startTime   = Date.now()
  currentFile = null
  passedTests = 0
  failures    = []
  attemptedTests = 0
  pendingTests = {}

  global.CoffeeScript = CoffeeScript

  global.pencilTrace = (event) ->

  global[name] = func for name, func of assert

  track = (fn, running) ->
    t = fn.test
    key = "#{t.currentFile} (#{t.attemptedTests}): #{t.description}"
    pendingTests[key] = running

  # Our test helper function for delimiting different test cases.
  global.test = (description, fn) ->
    try
      ++attemptedTests
      fn.test = {description, currentFile, attemptedTests}
      track fn, true
      fn.call(fn)
      ++passedTests
      track fn, false
    catch e
      failures.push
        filename: currentFile
        error: e
        description: description if description?
        source: fn.toString() if fn.toString?

  # An async testing primitive
  global.atest = (description, fn) ->
    ++attemptedTests
    fn.test = { description, currentFile, attemptedTests }
    track fn, true
    fn.call fn, (ok, e) =>
      if ok
        ++passedTests
        track fn, false
      else
        e.description = description if description?
        e.source      = fn.toString() if fn.toString?
        failures.push filename : currentFile, error : e

  # See http://wiki.ecmascript.org/doku.php?id=harmony:egal
  egal = (a, b) ->
    if a is b
      a isnt 0 or 1/a is 1/b
    else
      a isnt a and b isnt b

  # A recursive functional equivalence helper; uses egal for testing equivalence.
  arrayEgal = (a, b) ->
    if egal a, b then yes
    else if a instanceof Array and b instanceof Array
      return no unless a.length is b.length
      return no for el, idx in a when not arrayEgal el, b[idx]
      yes

  global.eq      = (a, b, msg) -> assert.ok egal(a, b), msg ? "Expected #{a} to equal #{b}"
  global.arrayEq = (a, b, msg) -> assert.ok arrayEgal(a,b), msg ? "Expected #{a} to deep equal #{b}"

  # When all the tests have run, collect and print errors.
  # If a stacktrace is available, output the compiled function source.
  process.on 'exit', ->
    time = ((Date.now() - startTime) / 1000).toFixed(2)
    message = "passed #{passedTests} tests in #{time} seconds#{reset}"
    if passedTests != attemptedTests
      log("Only #{passedTests} of #{attemptedTests} came back; some went missing!", red)
      for desc, pending of pendingTests when pending
        log(desc, red)
    return log(message, green) unless failures.length
    log "failed #{failures.length} and #{message}", red
    for fail in failures
      {error, filename, description, source}  = fail
      console.log ''
      log "  #{description}", red if description
      log "  #{error.stack}", red
      console.log "  #{source}" if source
    process.exit(1)
    return

  # Run every test in the `coffee` folder, recording failures.
  files = fs.readdirSync testsDir

  for file in files when CoffeeScript.helpers.isCoffee file
    console.log "XX #{file}"
    literate = CoffeeScript.helpers.isLiterate file
    currentFile = filename = path.join testsDir, file
    code = fs.readFileSync filename
    try
      mainModule = require.main
      mainModule.filename = fs.realpathSync filename
      mainModule.moduleCache and= {}
      mainModule.paths = require("module")._nodeModulePaths fs.realpathSync(testsDir)
      code = instrumentCoffee filename, code.toString(), CoffeeScript, { literate: literate, trackVariables: false }
      mainModule._compile code, mainModule.filename
    catch error
      failures.push {filename, error}
  return !failures.length

if coffeeScript.iced?
  console.log "\nRunning Iced CoffeeScript test suite"
else
  console.log "\nRunning CoffeeScript test suite"

runTests coffeeScript, path.join(path.dirname(__filename), "suite/coffee")

