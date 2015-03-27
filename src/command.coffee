# Entry point for the coffee-tracer binary.

fs = require "fs"
path = require "path"
vm = require "vm"
colors = require "colors"

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
    else if command in ["trace", "animate"]
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

      if command is "trace"
        # Pretty-print the events.
        for event in sandbox.ide.events
          loc = event.location
          type = if event.type == "" then "     " else event.type
          console.log "#{type} #{loc.first_line}:#{loc.first_column}-#{loc.last_line}:#{loc.last_column}"
      else if command is "animate"
        # Checks if the given line and column are inside the given location.
        withinLocation = (line, col, location) ->
          (line > location.first_line and line < location.last_line) ||
          (line == location.first_line and col >= location.first_column) ||
          (line == location.last_line and col <= location.last_column)

        # For each event, print the original program with the event's location
        # highlighted.
        index = 0
        printFrame = ->
          event = sandbox.ide.events[index]
          loc = event.location
          lineNum = 1
          colNum = 1

          # Print it character by character.
          for ch in code
            if ch is "\n"
              process.stdout.write(ch)
              lineNum++
              colNum = 1
            else
              if withinLocation(lineNum, colNum, event.location)
                if event.type == "enter"
                  process.stdout.write(ch.yellow)
                else if event.type == "leave"
                  process.stdout.write(ch.red)
                else
                  process.stdout.write(ch.green)
              else
                process.stdout.write(ch)
              colNum++

          index++
          unless index == sandbox.ide.events.length
            # Do the next frame in about a second
            setTimeout(printFrame, 1200)

        # Start the animation.
        printFrame 0
    else if command is "ast"
      ast = instrument infile, code, ast: yes
      console.log ast.toString().trim()
    else
      printUsage()
  else
    printUsage()

