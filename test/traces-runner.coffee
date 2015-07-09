# This script goes through each test in the test/traces directory, does a trace
# on that test program, and compares the result with an expected trace that is
# specified in a special comment in the test program.

fs = require "fs"
path = require "path"
Contextify = require "contextify"

{instrumentJs, instrumentCoffee} = require "../lib/index"
coffeeScript = require "coffee-script"
icedCoffeeScript = require "iced-coffee-script"

# Path to test/traces.
tracesDir = path.join(path.dirname(__filename), "traces")

# Abbreviate undefined as a slash and functions as "<func>", for printing and
# comparing values in traces.
abbrevValue = (value) ->
  if value is undefined
    "/"
  else if typeof value is "function"
    "<func>"
  else
    value

# Print out a trace, for comparing expected and actual traces.
traceToString = (trace) ->
  str = ""
  for event in trace
    line = event.location.first_line
    type = if event.type is "code" then "     " else event.type
    activeVars = (name for name of event.vars when event.vars[name].active).join(" ")
    vars = ("#{name}=#{abbrevValue(event.vars[name].value)}" for name of event.vars).join(" ")
    str += "\n    #{line}: #{type} [#{activeVars}] #{vars}"
  str

# Compare an expected trace with the actual trace of a file.
testTrace = (expectedTrace, traceEvents) ->
  success = false
  if expectedTrace.length is traceEvents.length
    success = true
    for idx in [0...traceEvents.length]
      success = false unless expectedTrace[idx].location.first_line is traceEvents[idx].location.first_line
      success = false unless expectedTrace[idx].type is traceEvents[idx].type

      expectedVars = expectedTrace[idx].vars
      actualVars = traceEvents[idx].vars
      for name of expectedVars
        unless actualVars[name]
          success = false
          break

        if expectedVars[name].value is "<func>"
          success = false unless typeof actualVars[name].value is "function"
        else
          success = false unless expectedVars[name].value is actualVars[name].value
        success = false unless expectedVars[name].active is actualVars[name].active

  success

# Perform all tests for a file. `language` is either 'js' or 'coffee'. Returns
# true only if all tests passed, otherwise false.
testFile = (traceFile, language) ->
  # Get code and instrument it.
  code = fs.readFileSync path.join(tracesDir, language, traceFile), "utf-8"
  instrumentedCode =
    if language is "js"
      instrumentJs traceFile, code
    else
      instrumentCoffee traceFile, code, coffee, bare: true, trackVariables: true

  # Run instrumented code in sandbox, collecting the events.
  sandbox =
    pencilTrace: (event) -> sandbox.pencilTraceEvents.push(event)
    pencilTraceEvents: []
    console: console
  Contextify sandbox
  sandbox.run instrumentedCode

  # Don't collect any more events when the asserts are eval'd later.
  sandbox.pencilTrace = (event) ->

  # Loop through lines, looking for special Trace or Assert comments.
  success = true
  expectedTrace = []
  inTrace = false
  lineNum = 1
  for line in code.split '\n'
    traceMatch = line.match /^(#|\/\/)\s*Trace:\s*$/
    traceLineMatch = line.match /^(#|\/\/)\s*(\d+):\s*(enter|leave)?\s*\[([^\]]*)\]\s*(.*)$/
    assertMatch = line.match /^(#|\/\/)\s*Assert: ?(.+)$/

    if traceMatch
      inTrace = true
    else if inTrace and traceLineMatch
      activeVars = traceLineMatch[4].split(/\s+/)
      expectedVars = {}
      for expr in traceLineMatch[5].split(/\s+/)
        exprMatch = expr.match /^([a-zA-Z0-9_$]+)=(.+)$/
        exprMatch[2] = "undefined" if exprMatch[2] is "/"
        exprMatch[2] = "'<func>'" if exprMatch[2] is "<func>"
        expectedVars[exprMatch[1]] =
          name: exprMatch[1]
          value: eval(exprMatch[2])
          active: activeVars.indexOf(exprMatch[1]) isnt -1
      expectedEvent =
        location:
          first_line: parseInt(traceLineMatch[2], 10)
        type: traceLineMatch[3] || "code"
        vars: expectedVars
      expectedTrace.push expectedEvent
    else if inTrace and not traceLineMatch
      inTrace = false
    else if assertMatch
      # Perform the assert test.
      try
        # Use a with statement to make local variables of the program available
        # to the assert expression.
        result = eval "with (sandbox) { #{assertMatch[2]} }"
        if result
          process.stdout.write "."
        else
          success = false
          console.log "\nFAILED: test/traces/#{language}/#{traceFile}:#{lineNum}"
          console.log "  Assertion: #{assertMatch[2]}"
          console.log "  Result:    #{result}"
      catch err
        success = false
        console.log "\nFAILED: test/traces/#{language}/#{traceFile}:#{lineNum}"
        console.log "  Exception: #{err}"

    lineNum += 1

  if expectedTrace.length > 0
    if testTrace(expectedTrace, sandbox.pencilTraceEvents)
      process.stdout.write "."
    else
      success = false
      console.log "\nFAILED: test/traces/#{language}/#{traceFile}"
      console.log "  Expected: #{traceToString(expectedTrace)}"
      console.log "  Actual:   #{traceToString(sandbox.pencilTraceEvents)}"
  else
    # Display warning if there wasn't a special Trace comment.
    console.log "\nWARNING: test/traces/#{language}/#{traceFile} doesn't contain an expected trace."

  # Clean up Contextified sandbox.
  sandbox.dispose()

  # Returns true only if all tests for this file passed.
  success

# Keeps track of whether any tests failed.
anyFailures = false

# Loop through files in test/traces/js directory.
console.log "\nRunning trace tests for JavaScript"
traceFiles = fs.readdirSync path.join(tracesDir, "js")
for traceFile in traceFiles
  # Skip non-JS files that might be in there (like .swp files).
  continue unless /\.js$/.test traceFile

  # Perform all tests in the file.
  result = testFile traceFile, "js"
  anyFailures = true if not result

# Run all coffeescript tests with both CoffeeScript and Iced CoffeeScript.
for coffee in [coffeeScript, icedCoffeeScript]
  compilerName = if coffee is coffeeScript then "CoffeeScript" else "Iced CoffeeScript"
  console.log "\nRunning trace tests for #{compilerName}"

  # Loop through files in test/traces/coffee directory.
  traceFiles = fs.readdirSync path.join(tracesDir, "coffee")
  for traceFile in traceFiles
    # Skip non-CS files that might be in there (like .swp files).
    continue unless /\.coffee/.test traceFile

    # Skip Iced CoffeeScript tests if we're not on Iced CoffeeScript.
    continue if traceFile is "iced.coffee" and coffee isnt icedCoffeeScript

    # Perform all tests in the file.
    result = testFile traceFile, "coffee"
    anyFailures = true if not result

process.stdout.write "\n"

# Return non-zero exit code if any tests failed.
process.exit 1 if anyFailures

