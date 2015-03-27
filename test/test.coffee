fs = require "fs"
path = require "path"
vm = require "vm"

{instrument} = require "../lib/index"

arrayEqual = (a, b) ->
  a.length is b.length and a.every (elem, i) -> elem is b[i]

tracesDir = path.join(path.dirname(__filename), "traces")

traceFiles = fs.readdirSync tracesDir
for traceFile in traceFiles
  continue unless /\.coffee$/.test traceFile

  code = fs.readFileSync path.join(tracesDir, traceFile), "utf-8"
  js = instrument traceFile, code

  sandbox =
    ide:
      events: [],
      trace: (event) -> sandbox.ide.events.push(event)

  vm.runInContext(js, vm.createContext(sandbox))

  matches = code.match /^# Expected: (.+)$/m

  enter = (lineNum) -> "enter #{lineNum}"
  leave = (lineNum) -> "leave #{lineNum}"
  expected = eval(matches[1])

  summarizeEvent = (event) ->
    if event.type is ""
      event.location.first_line
    else
      "#{event.type} #{event.location.first_line}"

  actual = (summarizeEvent(event) for event in sandbox.ide.events)

  if arrayEqual(actual, expected)
    console.log "PASSED: traces/#{traceFile}"
  else
    console.log "FAILED: traces/#{traceFile}"
    console.log "  Expected: #{expected}"
    console.log "  Actual: #{actual}"

