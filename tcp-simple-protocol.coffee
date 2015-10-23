PORT=parseInt(process.env.TCP_SIMPLE_PORT||5000)

R = require "ramda"
log = require "./log"
B=require "baconjs"
require "./bacon-nodestream"

server=require("net").createServer().listen(PORT)
log "TCP simple protocol server listening on port", PORT

connE = B.fromEvent server, "connection"
dataE = connE.flatMap (conn) ->
  B.fromNodeStream(conn)
    .map((x) -> x.toString().split(""))
    .flatMap(B.fromArray)
    .takeWhile((x) -> x != "\n")
    .fold("", (a, b) -> a + b)
    .flatMap(tryParse)
    .doEnd(-> conn.destroy())

tryParse = (str) ->
  try
    JSON.parse str
  catch e
    new B.Error { error: e, input: str }

extractEvents = (event) ->
  values = {}
  properties = {
    location: "kylpyhuone"
    device: "custom-sensor"
    collection: "sensors"
  }
  R.keys(event).forEach (key) ->
    if R.contains(key)(R.keys(properties))
      properties[key]=event[key]
    else
      values[key]=event[key]
  R.keys(values).map (key) ->
    value = values[key]
    R.merge(properties)({type: key, value})

toSensorEvents = (event) ->
  B.fromArray extractEvents(event)

sensorEvents = dataE
  .doAction(log, "Received")
  .doError(log, "Error") 
  .flatMap(toSensorEvents)

module.exports = { sensorEvents }
