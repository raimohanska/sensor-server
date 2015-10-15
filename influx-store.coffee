config = (require "./config").influx
log = require "./log"

if config
  influent = require "influent"
  R=require "ramda"

  createClient = influent.createClient config
  log "Connecting to InfluxDB"
    
  createClient.then (client) ->
    log "Connected to InfluxDB"

  store = (event) ->
    createClient
      .then (client) ->
        influxEvent =
          key: event.type
          tags: R.fromPairs(R.toPairs(event).filter(([key, value]) -> !R.contains(key)(["type", "value", "timestamp"])))
          fields: {
            value: event.value
          }
        if event.timestamp
          influxEvent.timestamp = new Date(event.timestamp).getTime()
        log "storing to InfluxDB", influxEvent
        client.writeOne influxEvent
      .then -> log "stored event to InfluxDB"
      .catch (e) -> 
        log "ERROR: " + e.stack.split("\n")

  module.exports = { store }
else
  module.exports = { store: -> }
