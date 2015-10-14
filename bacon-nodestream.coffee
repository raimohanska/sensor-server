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
