{spawn} = require "child_process"

task "build", ->
  coffee = spawn "./node_modules/.bin/coffee", ["-c", "-o", "lib", "src"]
  coffee.stderr.on "data", (data) ->
    process.stderr.write data.toString()
  coffee.stdout.on "data", (data) ->
    print data.toString()

task "test", ->
  require "./test/test"

