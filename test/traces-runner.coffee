# This script goes through each test in the test/traces directory, does a trace
# on that test program, and compares the result with an expected trace that is
# specified in a special comment in the test program.

fs = require "fs"
path = require "path"
util = require "util"
Contextify = require "contextify"
{isEqual, sortBy} = require "underscore"

{instrumentJs, instrumentCoffee} = require "../lib/index"
coffeeScript = require "coffee-script"
icedCoffeeScript = require "iced-coffee-script"

# Path to test/traces.
tracesDir = path.join(path.dirname(__filename), "traces")

# Parse a string like "x=1 f=<function> o={ary: [1, 2, 3]}" into an object like
# { x: "1", f: "<function>", o: "{ary: [1, 2, 3]}" }.
parseVars = (str) ->
  vars = []
  while str.length > 0
    matches = str.match /^(@?[a-zA-Z0-9_$.()<>]+)=/
    return false unless matches

    varName = matches[1]
    str = str.slice(matches[0].length)

    openers = "([{<"
    closers = ")]}>"
    quotes = "'\""
    if str[0] in openers + quotes
      stack = str[0]
      i = 1
      while stack.length > 0
        return false if i is str.length
        if str[i] in openers or (str[i] in quotes and stack[stack.length - 1] isnt str[i])
          stack += str[i]
        else if str[i] in closers or (str[i] in quotes and stack[stack.length - 1] is str[i])
          stack = stack.slice(0, stack.length - 1)
        i += 1
      vars.push {name: varName, value: str.slice(0, i)}
      str = str.slice(i)
    else
      valueMatch = str.match /^\S+/
      return false unless valueMatch
      vars.push {name: varName, value: valueMatch[0]}
      str = str.slice(valueMatch[0].length)

    spaceMatch = str.match /^\s*/
    str = str.slice(spaceMatch[0].length)

  vars

# Parse a string like "# 1: before  x=1 y=2" into an event object like
# { type: "before", location: { first_line: 1 }, vars: { x: "1", y: "2" } }.
parseTraceLine = (line) ->
  matches = line.match /^(#|\/\/)\s*(\d+):\s*(before|after|enter|leave)\s*(.*)$/
  return false unless matches

  vars = parseVars(matches[4])
  return false if vars is false

  event = {}
  event.type = matches[3]
  event.location = { first_line: parseInt(matches[2], 10) }
  switch event.type
    when "before", "after", "enter"
      event.vars = vars
    when "leave"
      event.returnOrThrow = { type: vars[0].name, value: vars[0].value }
  event

abbrevValue = (val, isActual) ->
  if typeof val is "undefined"
    "/"
  else if typeof val is "function"
    "<function>"
  else if isActual
    util.inspect val
  else
    val

# Print out a trace, for comparing expected and actual traces.
traceToString = (trace) ->
  isActual = trace.length > 0 && typeof trace[0].location.first_column isnt "undefined"
  str = ""
  for event in trace
    line = "#{event.location.first_line}: "
    line += " " unless line.length is 4
    type = event.type
    type += " " unless type is "before"
    vars =
      switch event.type
        when "before", "after", "enter" then event.vars
        when "leave"
          if event.returnOrThrow.type is "return"
            [{name: "return", value: event.returnOrThrow.value}]
          else
            [{name: "throw", value: event.returnOrThrow.value}]
    varsStr = ("#{v.name}=#{abbrevValue(v.value, isActual)}" for v in vars).join(" ")
    if event.functionCalls
      varsStr += " " if varsStr.length > 0
      varsStr += ("#{f.name}()=#{abbrevValue(f.value, isActual)}" for f in event.functionCalls).join(" ")
    str += "\n    #{line}#{type}  #{varsStr}"
  str

varsEq = (expected, actual) ->
  return false if expected.length isnt actual.length

  expected = sortBy(expected, "name")
  actual = sortBy(actual, "name")
  for expectedVar, i in expected
    actualVar = actual[i]
    return false if expectedVar.name isnt actualVar.name

    actualValue = actualVar.value
    expectedValue = expectedVar.value
    expectedValue = "<undefined>" if expectedValue is "/"
    if expectedValue[0] is "<"
      expectedType = expectedValue.slice(1, expectedValue.length - 1)
      return false if typeof actualValue isnt expectedType
    else
      expectedValue = (0;eval)(expectedValue)
      return false if not isEqual(expectedValue, actualValue)

  true

eventEq = (expected, actual) ->
  return false unless expected.type is actual.type
  return false unless expected.location.first_line is actual.location.first_line

  switch expected.type
    when "before", "enter"
      varsEq(expected.vars, actual.vars)
    when "after"
      varsAndFunctions = actual.vars.slice()
      for f in actual.functionCalls
        varsAndFunctions.push({name: "#{f.name}()", value: f.value})
      varsEq(expected.vars, varsAndFunctions)
    when "leave"
      expected.returnOrThrow.type is actual.returnOrThrow.type and
      varsEq([{name: "returnOrThrow", value: expected.returnOrThrow.value}], [{name: "returnOrThrow", value: actual.returnOrThrow.value}])

# Compare an expected trace with the actual trace of a file.
traceEq = (expected, actual) ->
  return false unless expected.length is actual.length
  for i in [0...expected.length]
    return false unless eventEq(expected[i], actual[i])
  true

# Perform all tests for a file. `language` is either 'js' or 'coffee'. Returns
# true only if all tests passed, otherwise false.
testFile = (traceFile, language) ->
  # Get code and instrument it.
  code = fs.readFileSync path.join(tracesDir, language, traceFile), "utf-8"
  instrumentedCode =
    if language is "js"
      instrumentJs code
    else
      instrumentCoffee code, coffee, bare: true, trackVariables: true

  # Run instrumented code in sandbox, collecting the events.
  sandbox =
    pencilTrace: (event) -> sandbox.pencilTraceEvents.push(event)
    pencilTraceEvents: []
    console: console
  Contextify sandbox
  sandbox.run instrumentedCode

  expectedTrace = []
  inTrace = false
  for line in code.split '\n'
    traceMatch = line.match /^(#|\/\/)\s*Trace:\s*$/

    if inTrace
      event = parseTraceLine(line)
      if event
        expectedTrace.push event
      else
        inTrace = false
    else
      if line.match /^(#|\/\/)\s*Trace:\s*$/
        inTrace = true

  success = true
  if expectedTrace.length > 0
    if traceEq(expectedTrace, sandbox.pencilTraceEvents)
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

