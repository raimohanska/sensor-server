express = require "express"
app = express()
http = require('http').Server(app)
log = require "./log"
bodyParser = require "body-parser"
devices = require "./devices"
sites = require "./sites"
Bacon = require "baconjs"

port = process.env.PORT || 5080

jsonParser = bodyParser.json()

sensorE = Bacon.Bus()

app.post "/event", jsonParser, (req, res) ->
  events = if req.body instanceof Array
    req.body
  else
    [req.body]
  events.forEach (event) ->
    sensorE.push(event)
  res.send("ok")

http.listen port, ->
  log "HTTP listening on port", port

sensorE.onValue (event) ->
  site = sites.findSiteByEvent event
  if site?
    log "HTTP sersor event", JSON.stringify(event)
    site.devices.reportDeviceSeen event.device
    site.sensors.pushEvent event

module.exports = { sensorE }
