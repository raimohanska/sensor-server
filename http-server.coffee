express = require "express"
app = express()
http = require('http').Server(app)
io = require('socket.io')(http)
log = require "./log"
bodyParser = require "body-parser"
devices = require "./devices"
sites = require "./sites"
Bacon = require "baconjs"
config = require "./read-config"

port = process.env.PORT || config.http?.port || 5080

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

io.on "connection", (socket) ->
  socket.on "login", (login) ->
    error = (msg) ->
      log msg, "from", login
      socket.emit "login-error", msg
    if !login.siteId?
      error "siteId missing"
    else
      site = sites.findSiteByEvent login
      if !site?
        error "invalid siteId/siteKey"
      else
        log "Sourcing server logged in for site " + login.siteId + " at " + socket.conn.remoteAddress
        socket.emit "login-success", "welcome"
        site.sensors.sensorE.forEach (event) ->
          socket.emit "sensor-event", event

module.exports = { sensorE }
