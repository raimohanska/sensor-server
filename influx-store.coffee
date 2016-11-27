log = require "./log"
R=require "ramda"

initSite = (site) ->
  config = site.config.influx
  if config
    client = (require "influx")(config)

    log "Connecting to InfluxDB"
      
    store = (event) ->
      influxEvent =
        key: event.type
        tags: R.fromPairs(R.toPairs(event).filter(([key, value]) ->
          !R.contains(key)(["type", "value", "timestamp"]) && typeof value != "object"
        ))
        fields: {
          value: event.value
        }

      if event.timestamp
        influxEvent.fields.time = new Date(event.timestamp)

      #log "storing to InfluxDB", JSON.stringify(influxEvent)
      client.writePoint influxEvent.key, influxEvent.fields, influxEvent.tags, (err, response) ->
        if (err)
          log "ERROR: " + err.stack.split("\n")

    { store }
  else
    { store: -> }

module.exports = { initSite }
