#!/usr/bin/env coffee
"use strict"
util = require "util"
B = require('baconjs')
R = require('ramda')
L = require 'partial.lenses'
scale = require './scale'
time = require "./time"
moment = require 'moment'
io = require('socket.io-client')
log = (msg...) -> console.log new Date().toString(), msg...
rp = require('request-promise')
tcpServer = require './tcp-server'
mock = require "./mock"

quadraticBrightness = (bri, max) -> Math.ceil(bri * bri / (max || 255))
booleanToBri = (b) -> 
  if typeof b == "number"
    b
  else if typeof b == "string"
    b == "true"
  else
    if b then 255 else 0


initSite = (site) ->
  siteConfig = site.config
  houmConfig = siteConfig.houm
  if not houmConfig
    return null
  houmSocket = io('http://houmi.herokuapp.com')
  houmConnectE = B.fromEvent(houmSocket, "connect")
  houmDisconnectE = B.fromEvent(houmSocket, "disconnect")
  tcpDevices = R.toPairs(siteConfig.devices)
    .map ([deviceId, {properties}]) -> { deviceId, properties}
    .filter ({properties}) -> properties?.tcp
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
            bri = booleanToBri(lightOn)
          log "Set", light.light, "bri="+bri, "on="+lightOn
          if !mock
            houmSocket.emit('apply/light', {_id: light.lightId, on: lightOn, bri })
      else
        log "ERROR: light", query, " not found"

  fadeLight = (query) -> (bri, duration = time.seconds(10)) ->
    fullLightStateP.take(1).forEach (lights) ->
      lights = findByQuery query, R.values(lights)
      if lights.length > 0
        lights.forEach (light) ->
          #log "fading light", light.light, "from", light.value, "to", bri, "in", time.formatDuration(duration)
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

  tcpDevices.forEach ({deviceId, properties}) ->
    lightId = properties?.lightId
    if lightId
      sendState = (state) ->
        transform = (bri) => 
          max = properties.brightness?.max || 255
          scaled = Math.round(scale(0, 255, 0, max)(bri))
          if properties.brightness?.quadratic then quadraticBrightness(scaled, max) else scaled

        mappedState = L.modify(L.prop("value"), transform, state)
        log "send light state to tcp device " + deviceId + ": " + JSON.stringify(mappedState) + ", mapped from " + state.value + " to " + mappedState.value
        tcpServer.sendToDevice(deviceId)(mappedState)
      lightStateP(lightId).forEach(sendState)
      lightStateP(lightId).debounce(2000).forEach(sendState)
      tcpServer.deviceConnectedE
        .filter((id) -> id == deviceId)
        .map(lightStateP(lightId))
        .delay(1000)
        .forEach(sendState)

  controlLight = (query, controlP, manualOverridePeriod = time.hours(3)) ->
    valueDiffersFromControl = (v,c) -> v != booleanToBri(c)
    setValueE = lightStateP(query)
      .map(".value")
      .changes()
    ackP = controlP.flatMapLatest((c) -> 
      B.once(false).concat(setValueE.skipWhile((v) -> valueDiffersFromControl(v, c)).take(1).map(true))
    ).toProperty()
    ackP.log(query + " control ack")
    manualOverrideE = ackP.changes().filter(B._.id).flatMapLatest((v) ->
      console.log "start monitoring " + query + " overrides"
      setValueE.takeUntil(controlP.changes()).log("override event for " + query)
    ).withLatestFrom(controlP, valueDiffersFromControl)
    manualOverrideP = manualOverrideE
      .flatMapLatest((override) -> 
        if override
          B.once(true).concat(B.later(manualOverridePeriod, false))
        else
          B.once(false))
      .toProperty(false)
      .skipDuplicates()
      .log("manual override active for " + query)

    controlP.filter(manualOverrideP.not()).forEach(setLight query)
    manualOverrideP.changes().filter((x) -> !x).map(controlP).skipDuplicates().forEach(setLight query)


  findByName = (name, lights) -> R.find(((light) -> light.name.toLowerCase() == name.toLowerCase()), lights)
  findById = (id, lights) -> R.find(((light) -> light.lightId == id), lights)
  findByQuery = (query, lights) -> R.filter(matchLight(query), lights)

  siteApi = {
    houmReadyE, houmReadyP, houmLightsP, lightStateE, lightStateP, totalBrightnessP,
    controlLight, fadeLight, setLight,
    quadraticBrightness, booleanToBri 
  }
  siteApi

module.exports = { initSite, quadraticBrightness, booleanToBri }
