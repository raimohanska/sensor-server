PORT=5000

Keen = require "keen.io"
keenConfig = require "./keen-config"

keenClient = Keen.configure keenConfig

log = (msg...) ->
  console.log new Date(), msg...

B=require "baconjs"
B.fromNodeStream = (stream) ->
  B.fromBinder (sink) ->
    listeners = {}
    addListener = (event, listener) ->
      listeners[event] = listener
      stream.on event, listener
    addListener "data", (chunk) -> sink(chunk)
    addListener "end", () -> sink(new B.End())
    addListener "error", (error) -> sink(new B.Error(error))
    -> for event,listener of listeners
         stream.removeListener event,listener

server=require("net").createServer().listen(PORT)
log "Listening on port", PORT

connE = B.fromEvent server, "connection"
dataE = connE.flatMap (conn) ->
  B.fromNodeStream(conn)
    .map(".toString")
    .fold("", (a, b) -> a + b)
    .flatMap(tryParse)

tryParse = (str) ->
  try
    JSON.parse str
  catch e
    new B.Error { error: e, input: str }

extractEvents = (type, event) ->
  if event[type]?
   [{
      location: (event.location||"kylpyhuone"),
      device: (event.device||"custom-sensor"),
      type,
      value: event[type]
   }]
  else
   []

temperatureEvents = (event) ->
  extractEvents "temperature", event

humidityEvents = (event) ->
  extractEvents "humidity", event

toKeenEvents = (event) ->
  B.fromArray temperatureEvents(event).concat(humidityEvents(event))

keenSend = (collection) -> (event) ->
  log "Send to keen", collection, event
  if process.env.dont_send
    log "skip send"
  else
    keenClient.addEvent collection, event, (err, res) ->
      if err
        log "Keen error:  " + err

dataE
  .flatMap(toKeenEvents)
  .onValue(keenSend "sensors")
