# This script goes through each test in the test/traces directory, does a trace
# on that test program, and compares the result with an expected trace that is
# specified in a special comment in the test program.
#
# The special comment looks like "# Expected: [1, 2, enter 3, leave 3]", where
# the array is an array of line numbers and enter/leave events that's expected
# to correspond to the actual events array.

fs = require "fs"
path = require "path"
vm = require "vm"

{instrumentCoffee} = require "../lib/index"
coffeeScript = require "coffee-script"
icedCoffeeScript = require "iced-coffee-script"

# From http://stackoverflow.com/questions/11142666
arrayEqual = (a, b) ->
  a.length is b.length and a.every (elem, i) -> elem is b[i]

# Run each test using CoffeeScript and Iced CoffeeScript.
anyFailures = false
for coffee in [coffeeScript, icedCoffeeScript]
  compilerName = if coffee is coffeeScript then "CoffeeScript" else "Iced CoffeeScript"
  console.log "Running tests for #{compilerName}"

  # Loop through files in test/traces directory.
  tracesDir = path.join(path.dirname(__filename), "traces")
  traceFiles = fs.readdirSync tracesDir
  for traceFile in traceFiles
    # Skip non-CS files that might be in there (like .swp files).
    continue unless /\.coffee$/.test traceFile

    # Skip Iced CoffeeScript tests if we're not on Iced CoffeeScript.
    continue if traceFile is "iced.coffee" and coffee isnt icedCoffeeScript

    # Get code and instrument it.
    code = fs.readFileSync path.join(tracesDir, traceFile), "utf-8"
    js = instrumentCoffee traceFile, code, coffee, bare: true

    # Run instrumented code in sandbox, collecting the events.
    sandbox =
      pencilTrace: (event) -> sandbox.pencilTraceEvents.push(event)
      pencilTraceEvents: [],
    options =
      filename: traceFile,
      timeout: 5000
    vm.runInContext(js, vm.createContext(sandbox), options)

    lineNum = 1
    for line in code.split '\n'
      traceMatch = line.match /^# Trace: (.+)$/
      assertMatch = line.match /^# Assert: (.+)$/
      if traceMatch
        # Evaluate the expected value, which is a tiny DSL.
        enter = (lineNum) -> "enter #{lineNum}"
        leave = (lineNum) -> "leave #{lineNum}"
        expected = eval(traceMatch[1])

        # The actual array of events will be mapped over with this function.
        summarizeEvent = (event) ->
          if event.type is ""
            event.location.first_line
          else
            "#{event.type} #{event.location.first_line}"

        # Put the actual result in the same form as the expected one, so they can be
        # compared.
        actual = (summarizeEvent(event) for event in sandbox.pencilTraceEvents)

        # Compare actual and expected.
        if arrayEqual(actual, expected)
          process.stdout.write "."
        else
          anyFailures = true
          console.log "\nFAILED: test/traces/#{traceFile}:#{lineNum}"
          console.log "  Expected: #{expected}"
          console.log "  Actual:   #{actual}"
      else if assertMatch
        try
          result = eval "with (sandbox) { #{assertMatch[1]} }"
          if result
            process.stdout.write "."
          else
            anyFailures = true
            console.log "\nFAILED: test/traces/#{traceFile}:#{lineNum}"
            console.log "  Expected: #{assertMatch[1]}"
            console.log "  Actual:   #{result}"
        catch err
          anyFailures = true
          console.log "\nFAILED: test/traces/#{traceFile}:#{lineNum}"
          console.log "  Exception: #{err}"

      lineNum += 1
  console.log ""

process.exit 1 if anyFailures

