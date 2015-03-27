# Entry point for the coffee-tracer binary.

fs = require "fs"
path = require "path"
vm = require "vm"

{instrument} = require "./instrument"

printUsage = ->
  console.log "Usage: coffee-tracer <command> <infile>"
  console.log "  where <command> is one of:"
  console.log "    'instrument'       outputs instrumented JavaScript"
  console.log "    'trace'            runs instrumented JS and outputs trace"
  console.log "    'ast'              outputs instrumented AST"
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

      # Execute instrumented code in a VM, collecting the events in sandbox.ide.events.
      sandbox =
        ide:
          events: [],
          trace: (event) -> sandbox.ide.events.push(event)
        console: console
      options =
        filename: path.basename(infile),
      m = require "module"
      wrapped = vm.runInContext(m.wrap(js), vm.createContext(sandbox), options)
      wrapped(exports, require, module, path.basename(infile), path.dirname(infile))

      # Pretty-print the events.
      for event in sandbox.ide.events
        loc = event.location
        type = if event.type == "" then "     " else event.type
        console.log "#{type} #{loc.first_line}:#{loc.first_column}-#{loc.last_line}:#{loc.last_column}"
    else if command is "ast"
      ast = instrument infile, code, ast: yes
      console.log ast.toString().trim()
    else
      printUsage()
  else
    printUsage()

