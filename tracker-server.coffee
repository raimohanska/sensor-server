net = require 'net'
B = require 'baconjs'
R = require 'ramda'
log = require "./log"
carrier = require "carrier"
config = require('./read-config').trackerServer
sites = (require "./sites").sites
port = config?.port


parseTrackerInfo = (s) ->
  lat = s.substring(24,33)
  lon = s.substring(35,44)
  serial = s.substring(1, 17)
  speed = Number.parseFloat(s.substring(45, 50))
  course = Number.parseFloat(s.substring(56, 62))
  
  { lat: strToCoord(lat), lon: strToCoord(lon), speed, course, serial, raw: s }

siteBySerial = (serial) ->
  matching = (site) -> 
    trackers = site.config.trackerServer?.trackers
    trackers && trackers.some((tracker) -> tracker.serial == serial)
  R.find(matching)(R.values(sites))

strToCoord = (str) ->
  num = Number.parseFloat(str.substring(0, 2))
  num + Number.parseFloat(str.substring(2)) / 60.0

if port?
  net.createServer((socket) ->
    log 'connected', socket.remoteAddress
    id = null
    discoE = B.fromEvent(socket, 'close').take(1).map(() => ({ socket, id }))
    discoE.forEach => log 'disconnected', socket.remoteAddress
    errorE = B.fromEvent(socket, 'error').log("Error reading from " + socket.remoteAddress)
    chars = B.fromEvent(socket, 'data')
      .flatMap (buffer) -> B.fromArray(Array.prototype.slice.call(buffer, 0))
      .map(String.fromCharCode)
    chars
      .filter (b) -> b == '('
      .flatMapFirst (b) ->
        chars
             .takeWhile (b) -> b != ')'
             .fold '', (soFar, next) -> soFar + next
      .map (str) -> '(' + str + ')'
      .map(parseTrackerInfo)
      .onValue ({lat, lon, speed, course, serial, raw}) ->
        site = siteBySerial(serial)
        if not site?
          log "Site not found for tracker", serial
        else
          log "Got tracker info from", serial, {lat, lon, speed, course}
          site.sensors.pushEvent({ type: 'latitude', value: lat, serial })
          site.sensors.pushEvent({ type: 'longitude', value: lon, serial })
          site.sensors.pushEvent({ type: 'speed', value: speed, serial })
          site.sensors.pushEvent({ type: 'course', value: course, serial })

  ).listen(port)
  log "Tracker Server listening on port", port
