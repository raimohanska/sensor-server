#!/usr/bin/env coffee
"use strict"
B = require('baconjs')
R = require('ramda')
moment = require 'moment'
io = require('socket.io-client')
log = (msg...) -> console.log new Date().toString(), msg...
rp = require('request-promise')
houmSocket = io('http://houmi.herokuapp.com')
houmConnectE = B.fromEvent(houmSocket, "connect")
houmDisconnectE = B.fromEvent(houmSocket, "disconnect")
houmConfig = require('./config').houm
houmLightsP = B.fromPromise(rp("https://houmi.herokuapp.com/api/site/" + houmConfig.siteKey))
  .map(JSON.parse)
  .map(".lights")
  .map((lights) => lights.map(({name,_id})=>{name,id:_id}))
  .toProperty()
houmLightsP
  .forEach log, "HOUM lights found"
houmConnectE.onValue =>
  houmSocket.emit('clientReady', { siteKey: houmConfig.siteKey})
  log "Connected to HOUM"
houmReadyP = B.once(false).concat(B.combineAsArray(houmConnectE, houmLightsP).map(true)).toProperty()
houmReadyP.filter(B._.id) .forEach -> log "HOUM ready"

setLight = ({id, name}, bri) ->
  log "Set", name, "brightness to",  bri
  houmSocket.emit('apply/light', {_id: id, on: bri>0, bri })

quadraticBrightness = (bri) -> Math.ceil(bri * bri / 255)

findLight = (name, lights) -> R.find(((light) -> light.name.toLowerCase() == name.toLowerCase()), lights)

module.exports = { houmReadyP, setLight, findLight, quadraticBrightness, houmLightsP }
