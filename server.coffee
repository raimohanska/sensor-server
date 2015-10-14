R = require "ramda"
TcpSimple = require "./tcp-simple-protocol"
log = require "./log"
B=require "baconjs"
KeenSender = require "./keen-sender"

TcpSimple.sensorEvents
  .onValue(KeenSender.send)
