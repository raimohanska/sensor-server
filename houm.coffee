#!/usr/bin/env coffee
"use strict"
B = require('baconjs')
R = require('ramda')
time = require "./time"
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
  .map((lights) => lights.map(({name,room,_id})=>{light:name,room,lightId:_id}))
  .toProperty()
houmLightsP
  .forEach log, "HOUM lights found"
houmConnectE.onValue =>
  houmSocket.emit('clientReady', { siteKey: houmConfig.siteKey})
  log "Connected to HOUM"
houmReadyE = B.combineAsArray(houmConnectE, houmLightsP).map(true)
houmReadyP = B.once(false).concat(houmReadyE).toProperty()
houmReadyE.forEach -> log "HOUM ready"

lightE= B.fromEvent(houmSocket, 'setLightState')
lightStateE = lightE
  .combine houmLightsP, ({_id, bri}, lights) ->
    light = findById _id, lights
    { lightId: light.lightId, room: light.room, light: light.light, type:"brightness", value:bri }
  .sampledBy(lightE)

fullLightStateP = lightStateE
  .scan {}, (state, light) ->
    state = R.clone(state)
    state[light.lightId]=light
    state
  .combine houmLightsP, (state, allLights) ->
    state = R.clone(state)
    allLights.forEach (light) ->
      if !state[light.lightId]
        state[light.lightId] = light
    state

lightStateP = (query) ->
  lightStateE
    .filter(matchLight(query))
    .toProperty()

totalBrightnessP = (query) ->
  fullLightStateP
    .map(filterLightState(query))
    .map (state) -> R.sum(R.values(state).map((light) -> light.value))

filterLightState = (query) -> (fullLightState) ->
  R.indexBy(R.prop("lightId"), R.values(fullLightState).filter(matchLight(query)))

matchLight = (query) -> (light) ->
  if !(query instanceof Array)
    query = [query]
  matchSingle = (q) ->
    (light.lightId == q) || (light.light.toLowerCase() == q.toLowerCase()) || (light.room.toLowerCase() == q.toLowerCase())
  R.any matchSingle, query

setLight = (query) -> (bri) ->
  houmLightsP.take(1).forEach (lights) ->
    lights = findByQuery query, lights
    if lights.length > 0
      lights.forEach (light) ->
        lightOn = bri
        if typeof bri == "number"
          lightOn = bri>0
        else
          bri = if lightOn then 255 else 0
        log "Set", light.light, "bri="+bri, "on="+lightOn
        houmSocket.emit('apply/light', {_id: light.lightId, on: lightOn, bri })
    else
      log "ERROR: light", query, " not found"

fadeLight = (query) -> (bri, duration = time.oneSecond * 10) ->
  fullLightStateP.take(1).forEach (lights) ->
    lights = findByQuery query, R.values(lights)
    if lights.length > 0
      lights.forEach (light) ->
        if !light.value
          setLight(light.lightId)(bri)
        else
          distance = Math.abs(bri - light.value)
          steps = 100
          stepSize = distance / steps
          stepDuration = duration / stepSize
          if stepDuration < 100
            stepDuration = 100
            stepSize = distance * duration / stepDuration
          B.fade(light.value, bri, stepDuration, stepSize)
            .forEach (nextBri) -> # TODO: abort on external event
              setLight(light.lightId)(nextBri)
    else
      log "ERROR: light", query, " not found"

quadraticBrightness = (bri) -> Math.ceil(bri * bri / 255)

findByName = (name, lights) -> R.find(((light) -> light.name.toLowerCase() == name.toLowerCase()), lights)
findById = (id, lights) -> R.find(((light) -> light.lightId == id), lights)
findByQuery = (query, lights) -> R.filter(matchLight(query), lights)

module.exports = { houmReadyE, houmReadyP, fadeLight, setLight, quadraticBrightness, houmLightsP, lightStateE, lightStateP, totalBrightnessP }
