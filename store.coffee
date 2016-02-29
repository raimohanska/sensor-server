fs = require "fs"
B = require "baconjs"
log = require "./log"

storage = (name) ->
  filename = name + ".json"
  storedValuesP = B.fromNodeCallback(fs, "readFile", filename, "utf-8")
      .mapError("{}")
      .map(JSON.parse)
      .toProperty()
  write = (key, value) ->
    storedValuesP
      .flatMap (storedValues) ->
        storedValues[key] = value
        B.fromNodeCallback(fs, "writeFile", filename, JSON.stringify(storedValues), "utf-8")
      .onValue ->
  read = (key) -> storedValuesP.map((values) -> values[key]).filter(B._.id)
  { write, read }

module.exports = storage
