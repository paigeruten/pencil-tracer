fs = require "fs"
vm = require "vm"

{instrument} = require "./instrument"

printUsage = ->
  console.log "Usage: coffee-tracer <command> <infile>"
  console.log "  where <command> is one of:"
  console.log "    'instrument'       outputs instrumented JavaScript"
  console.log "    'trace'            runs instrumented JS and outputs trace"
  console.log "  and <infile> is the CoffeeScript program to instrument"

exports.main = (args) ->
  if args.length is 4
    [command, infile] = args[2..]
    code = fs.readFileSync infile, "utf-8"

    if command is "instrument"
      js = instrument infile, code
      console.log js
    else if command is "trace"
      js = instrument infile, code

      Module = require "module"
      sandbox =
        ide:
          events: [],
          trace: (event) -> sandbox.ide.events.push(event)
        console: console

      vm.runInContext(js, vm.createContext(sandbox));

      console.log sandbox.ide.events
    else
      printUsage()
  else
    printUsage()

