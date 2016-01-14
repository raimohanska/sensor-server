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
  .map((lights) => lights.map(({name,room,_id})=>{name,room,id:_id}))
  .toProperty()
houmLightsP
  .forEach log, "HOUM lights found"
houmConnectE.onValue =>
  houmSocket.emit('clientReady', { siteKey: houmConfig.siteKey})
  log "Connected to HOUM"
houmReadyP = B.once(false).concat(B.combineAsArray(houmConnectE, houmLightsP).map(true)).toProperty()
houmReadyP.filter(B._.id) .forEach -> log "HOUM ready"

lightE= B.fromEvent(houmSocket, 'setLightState')
lightStateE = lightE 
  .combine houmLightsP, ({_id, bri}, lights) ->
    light = findById _id, lights
    { lightId: light.id, room: light.room, light: light.name, type:"brightness", value:bri }
  .sampledBy(lightE)

setLight = (name) -> (bri) ->
  houmLightsP.take(1).forEach (lights) ->
    light = findByName name, lights
    lightOn = bri
    if typeof bri == "number"
      lightOn = bri>0
    else
      bri = if lightOn then 255 else 0
    log "Set", name, "bri="+bri, "on="+lightOn
    if light
      houmSocket.emit('apply/light', {_id: light.id, on: lightOn, bri })
    else
      log "ERROR: light", name, " not found"

quadraticBrightness = (bri) -> Math.ceil(bri * bri / 255)

findByName = (name, lights) -> R.find(((light) -> light.name.toLowerCase() == name.toLowerCase()), lights)
findById = (id, lights) -> R.find(((light) -> light.id == id), lights)

module.exports = { houmReadyP, setLight, quadraticBrightness, houmLightsP, lightStateE }
