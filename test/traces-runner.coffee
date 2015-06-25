# This script goes through each test in the test/traces directory, does a trace
# on that test program, and compares the result with an expected trace that is
# specified in a special comment in the test program.
#
# The special comment looks like "# Expected: [1, 2, enter 3, leave 3]", where
# the array is an array of line numbers and enter/leave events that's expected
# to correspond to the actual events array.

fs = require "fs"
path = require "path"
Contextify = require "contextify"

{instrumentJs, instrumentCoffee} = require "../lib/index"
coffeeScript = require "coffee-script"
icedCoffeeScript = require "iced-coffee-script"

# From http://stackoverflow.com/questions/11142666
arrayEqual = (a, b) ->
  a.length is b.length and a.every (elem, i) -> elem is b[i]

# Path to test/traces.
tracesDir = path.join(path.dirname(__filename), "traces")

# Compare an expected trace with the actual trace of a file. Returns { success:
# true } on success, and { success: false, expected: ..., actual: ... } on
# failure.
testTrace = (expectedTrace, traceEvents) ->
  # Evaluate the expected value, which is written in a tiny DSL.
  enter = (lineNum) -> "enter #{lineNum}"
  leave = (lineNum) -> "leave #{lineNum}"
  expected = eval(expectedTrace)

  # The actual array of events will be mapped over with this function.
  summarizeEvent = (event) ->
    if event.type is "code"
      event.location.first_line
    else
      "#{event.type} #{event.location.first_line}"

  # Put the actual result in the same form as the expected one, so they can be
  # compared.
  actual = (summarizeEvent(event) for event in traceEvents)

  # Compare actual and expected.
  if arrayEqual(actual, expected)
    { success: true }
  else
    { success: false, expected: expected, actual: actual }

# Perform all tests for a file. `language` is either 'js' or 'coffee'. Returns
# true only if all tests passed, otherwise false.
testFile = (traceFile, language) ->
  # Get code and instrument it.
  code = fs.readFileSync path.join(tracesDir, language, traceFile), "utf-8"
  instrumentedCode =
    if language is "js"
      instrumentJs traceFile, code
    else
      instrumentCoffee traceFile, code, coffee, bare: true

  # Run instrumented code in sandbox, collecting the events.
  sandbox =
    pencilTrace: (event) -> sandbox.pencilTraceEvents.push(event)
    pencilTraceEvents: []
    console: console
  Contextify sandbox
  sandbox.run instrumentedCode

  # Loop through lines, looking for special Trace or Assert comments.
  success = true
  foundTrace = false
  lineNum = 1
  for line in code.split '\n'
    traceMatch = line.match /^(#|\/\/) Trace: (.+)$/
    assertMatch = line.match /^(#|\/\/) Assert: (.+)$/
    if traceMatch
      foundTrace = true

      # Perform the trace test.
      result = testTrace(traceMatch[2], sandbox.pencilTraceEvents)
      if result.success
        process.stdout.write "."
      else
        success = false
        console.log "\nFAILED: test/traces/#{language}/#{traceFile}:#{lineNum}"
        console.log "  Expected: #{result.expected}"
        console.log "  Actual:   #{result.actual}"
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

  # Clean up Contextified sandbox.
  sandbox.dispose()

  # Display warning if there wasn't a special Trace comment.
  if not foundTrace
    console.log "\nWARNING: test/traces/#{language}/#{traceFile} doesn't contain an expected trace."

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

