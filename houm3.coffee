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
  else
    if b then 255 else 0


initSite = (site) ->
  siteConfig = site.config
  houmConfig = siteConfig.houm3
  if not houmConfig
    return null
  houmSocket = io.connect('https://houmkolmonen.herokuapp.com', {
    reconnectionDelay: 1000,
    reconnectionDelayMax: 3000,
    transports: ['websocket']
  })
  houmConnectE = B.fromEvent(houmSocket, "connect")
  houmDisconnectE = B.fromEvent(houmSocket, "disconnect")
  tcpDevices = R.toPairs(siteConfig.devices)
    .map ([deviceId, {properties}]) -> { deviceId, properties}
    .filter ({properties}) -> properties?.tcp
  siteKey = houmConfig.siteKey
  houmConfigUrl = "https://houmkolmonen.herokuapp.com/api/site/" + siteKey
  houmLightsP = B.fromPromise(rp(houmConfigUrl))
    .map(JSON.parse)
    .map((config) -> 
          roomNames = R.fromPairs(config.locations.rooms.map((room) -> [room.id, room.name]))
          config.devices.map(({name,roomId,id})=>{light:name,room: roomNames[roomId],lightId:id})
        )
    .toProperty()
  houmLightsP
    .forEach log, "HOUM lights found"
  houmConnectE.onValue =>
    houmSocket.emit('subscribe', { siteKey })
    log "Connected to HOUM"
  houmReadyE = B.combineAsArray(houmConnectE, houmLightsP).map(true)
  houmReadyP = B.once(false).concat(houmReadyE).toProperty()
  houmReadyE.forEach -> log "HOUM ready"
  B.fromEvent(houmSocket, 'siteKeyFound').log("Site found")

  B.fromEvent(houmSocket, 'noSuchSiteKey').log("HOUM site not found by key")
  lightE = B.fromEvent(houmSocket, "site")
    .map(".data.devices")
    .map((devices) -> devices.map((d) -> {id: d.id, bri: d.state.bri || 0}))
    .diff([], R.flip(R.difference))
    .changes()
    .skip(1)
    .flatMap(B.fromArray)

  lightStateE = lightE
    .combine houmLightsP, ({id, bri}, lights) ->
      light = findById id, lights
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
            houmSocket.emit('apply/device', {
              siteKey,
              data: { id: light.lightId, state: { on: lightOn, bri } }
            })
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
