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
