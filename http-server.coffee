express = require "express"
app = express()
http = require('http').Server(app)
log = require "./log"
bodyParser = require "body-parser"
Bacon = require "baconjs"

port = process.env.PORT || 5080

jsonParser = bodyParser.json()

sensorEvents = Bacon.Bus()

app.post "/event", jsonParser, (req, res) ->
  events = if req.body instanceof Array
    req.body
  else
    [req.body]
  events.forEach (event) ->
    sensorEvents.push(event)
  res.send("ok")

http.listen port, ->
  log "HTTP listening on port", port

sensorEvents.log("HTTP sensor event")

module.exports = { sensorEvents }
