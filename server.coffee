PORT=5000
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
console.log "Listening on port", PORT

connE = B.fromEvent server, "connection"
dataE = connE.flatMap (conn) ->
  B.fromNodeStream(conn)
    .map(".toString")
    .fold("", (a, b) -> a + b)
    .flatMap(tryParse)
    .map (x) ->
      x.timestamp = new Date()
      x

tryParse = (str) ->
  try
    JSON.parse str
  catch e
    new B.Error { error: e, input: str }

dataE.log()
