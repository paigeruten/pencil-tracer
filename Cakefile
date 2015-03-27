{spawn} = require "child_process"

task "build", ->
  spawn "./node_modules/.bin/coffee", ["-c", "-o", "lib", "src"]

task "test", ->
  require "./test/test"

