Keen = require "keen.io"
keenConfig = require "./keen-config"
keenClient = Keen.configure keenConfig
log = require "./log"

send = (event) ->
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
