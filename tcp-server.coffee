net = require 'net'
B = require 'baconjs'
R = require 'ramda'
log = require "./log"
carrier = require "carrier"
config = require('./read-config').tcp
sites = require "./sites"
port = config?.port

addSocketE = B.Bus()
removeSocketE = B.Bus()
removeSocketE.map(".id").forEach log, "TCP device disconnected"
messageFromDeviceE = B.Bus()

deviceConnectedE = addSocketE.map(".id")
deviceConnectedE.forEach log, "TCP device connected"

devicesP = B.update([],
  addSocketE, ((xs, x) -> xs.concat(x)),
  removeSocketE, ((xs, x) -> xs.filter ((d) -> d.socket != x.socket)))

deviceIdsP = devicesP.map (devices) -> devices.map(({id}) -> id)
deviceIdsP.log("Connected devices")

if port?
  net.createServer((socket) ->
    log 'connected', socket.remoteAddress
    id = null
    discoE = B.fromEvent(socket, 'close').take(1).map(() => ({ socket, id }))
    discoE.forEach => log 'disconnected', socket.remoteAddress
    errorE = B.fromEvent(socket, 'error').log("Error reading from " + socket.remoteAddress)
    removeSocketE.plug(discoE)
    lineE = B.fromEvent((carrier.carry socket), "line")
    jsonE = lineE.flatMap(B.try(JSON.parse))
    jsonE.onError (err) ->
      log socket.remoteAddress,  err
      socket.end()
    jsonE.take(1).onValue (login) ->
      if !login.device?
        log "invalid login message", login
        socket.end()
      else
        id = login.device
        B.interval(30000).map({"ping":"ping"}).takeUntil(discoE).forEach(sendToDevice(id))
        messageFromDeviceE.push(login)
        jsonE.onValue (msg) ->
          msg.device = id
          log 'Message from device ' + id + ": " + JSON.stringify(msg)
          messageFromDeviceE.push(msg)
        addSocketE.push {id, socket}
  ).listen(port)
  log "TCP listening on port", port

messageFromDeviceE
  .onValue (message) ->
    site = sites.findSiteByEvent message
    if site?
      site.devices.reportDeviceSeen message.device
      if message.value?
        site.sensors.pushEvent(message)

sendToDevice = (id) -> (msg) ->
  devicesP.take(1).onValue (devices) ->
    devices = R.filter(R.propEq('id', id), devices)
    devices.forEach (device) ->
      device.socket.write(JSON.stringify(msg)+"\n", "utf-8")

module.exports = { devicesP, deviceConnectedE, sendToDevice, messageFromDeviceE }
