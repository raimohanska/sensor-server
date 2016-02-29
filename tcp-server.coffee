net = require 'net'
B = require 'baconjs'
R = require 'ramda'
log = require "./log"
carrier = require "carrier"
config = require('./config').tcp
sensors = require './sensors'
port = config?.port

addSocketE = B.Bus()
addSocketE.map(".id").forEach log, "TCP device connected"
removeSocketE = B.Bus()
removeSocketE.map(".id").forEach log, "TCP device disconnected"
messageFromDeviceE = B.Bus()

devicesP = B.update([],
  addSocketE, ((xs, x) -> xs.concat(x)),
  removeSocketE, ((xs, x) -> xs.filter ((d) -> d.id != x.id)))

deviceIdsP = devicesP.map (devices) -> devices.map(({id}) -> id)
deviceIdsP.log("Connected devices")

if port?
  net.createServer((socket) ->
    log 'connected', socket.remoteAddress
    id = null
    discoE = B.fromEvent(socket, 'close').take(1).map(() => ({ socket, id }))
    discoE.forEach => log 'disconnected', socket.remoteAddress
    errorE = B.fromEvent(socket, 'error').log("Error reading from " + socket.remoteAddress)
    removeSocketE.plug(discoE.filter(".id"))
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
          log 'Message from device ' + id
          messageFromDeviceE.push(msg)
        addSocketE.push {id, socket}
  ).listen(port)
  log "TCP listening on port", port

messageFromDeviceE
  .filter((m) -> m.value?)
  .onValue(sensors.pushEvent)

sendToDevice = (id) -> (msg) ->
  devicesP.take(1).onValue (devices) ->
    device = R.find(R.propEq('id', id), devices)
    if device
      device.socket.write(JSON.stringify(msg)+"\n", "utf-8")
    else
      log "unknown device", id

module.exports = { devicesP, sendToDevice, messageFromDeviceE }
