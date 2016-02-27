"use strict";
net = require 'net'
B = require 'baconjs'
R = require 'ramda'
log = require "./log"
carrier = require "carrier"

addSocketE = B.Bus()
addSocketE.map(".id").forEach log, "TCP device connected"
removeSocketE = B.Bus()
removeSocketE.map(".id").forEach log, "TCP device disconnected"

devicesP = B.update([],
  addSocketE, ((xs, x) -> xs.concat(x)),
  removeSocketE, ((xs, x) -> xs.filter ((d) -> d.id != x.id)))

deviceIdsP = devicesP.map (devices) -> devices.map(({id}) -> id)
deviceIdsP.log("Connected devices")

net.createServer((socket) ->
  log 'connected', socket.remoteAddress
  id = null
  discoE = B.fromEvent(socket, 'close').take(1).map(() => ({ socket, id }))
  discoE.forEach => log 'disconnected', socket.remoteAddress
  removeSocketE.plug(discoE.filter(".id"))
  lineE = B.fromEvent((carrier.carry socket), "line")
  jsonE = lineE.flatMap(B.try(JSON.parse))
  jsonE.onError log
  jsonE.map(".device").filter(B._.id).take(1).onValue (device) ->
    id = device
    addSocketE.push {id, socket}
  jsonE.log 'received'
).listen(8000)

sendToDevice = (id, msg) ->
  devicesP.take(1).onValue (devices) ->
    device = R.find(R.propEq('id', id), devices)
    if device
      device.socket.send(msg)
    else
      log "unknown device", id

module.exports = { devicesP, sendToDevice }