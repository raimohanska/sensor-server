Keen = require "keen.io"
config = (require "./config").keen
log = require "./log"
R = require "ramda"

if config
  keenClient = Keen.configure config
  log = require "./log"
  log "Keen.IO client configured"

  send = (event) ->
    event = R.clone(event)
    if event.timestamp
      event.keen = { timestamp: event.timestamp }
      delete event.timestamp
    collection = (event.collection||"sensors")
    delete event.collection

    log "Send to keen", collection, event
    if process.env.dont_send
      log "skip send"
    else
      keenClient.addEvent collection, event, (err, res) ->
        if err
          log "Keen error:  " + err

  module.exports = { send }
else
  module.exports = { send: -> }
