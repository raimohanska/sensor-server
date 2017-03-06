log = require "./log"
R=require "ramda"
B=require "baconjs"
time=require "./time"

initSite = (site) ->
  config = site.config.influx
  if config
    client = (require "influx")(config)

    log "Connecting to InfluxDB at " + config.protocol + "://" + config.host + ":" + config.port + "/" + config.database
    eventBus = B.Bus()
      
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
      eventBus.push(influxEvent)
      
    resultE = eventBus.flatMap (influxEvent) ->
      B.fromNodeCallback client, "writePoint", influxEvent.key, influxEvent.fields, influxEvent.tags
    errorE = resultE.errors().mapError(B._.id)
    errorE.debounceImmediate(time.oneHour).onValue (err) ->
      log "Influx storage error: " + err.stack.split("\n")
    inErrorP = errorE.awaiting(resultE.skipErrors())
    inErrorP.changes().onValue (error) ->
      if error
        site.mail.send("Influx storage error", "Couldn't save event to the Influx Database")
      else
        site.mail.send("Influx storage OK", "Influx storage seems to be up again")

    { store }
  else
    { store: -> }

module.exports = { initSite }
