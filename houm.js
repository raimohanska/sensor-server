"use strict";
const util = require("util");
const B = require('baconjs');
const R = require('ramda');
const L = require('partial.lenses');
const scale = require('./scale');
const time = require("./time");
const moment = require('moment');
const io = require('socket.io-client');
const log = (...msg) => console.log(new Date().toString(), ...Array.from(msg));
const rp = require('request-promise');
const tcpServer = require('./tcp-server');
const mock = require("./mock");

const quadraticBrightness = (bri, max) => Math.ceil((bri * bri) / (max || 255));
const booleanToBri = function(b) { 
  if (typeof b === "number") {
    return b;
  } else if (typeof b === "string") {
    return b === "true";
  } else {
    if (b) { return 255; } else { return 0; }
  }
};


const initSite = function(site) {
  const siteConfig = site.config;
  const houmConfig = siteConfig.houm;
  if (!houmConfig) {
    return null;
  }
  const houmSocket = io('http://houmi.herokuapp.com');
  const houmConnectE = B.fromEvent(houmSocket, "connect");
  const houmDisconnectE = B.fromEvent(houmSocket, "disconnect");
  const tcpDevices = R.toPairs(siteConfig.devices)
    .map(function(...args) { const [deviceId, {properties}] = Array.from(args[0]); return { deviceId, properties}; })
    .filter(({properties}) => properties != null ? properties.tcp : undefined);
  const houmLightsP = B.fromPromise(rp("https://houmi.herokuapp.com/api/site/" + houmConfig.siteKey))
    .map(JSON.parse)
    .map(".lights")
    .map(lights => lights.map(({name,room,_id})=> ({light:name,room,lightId:_id})))
    .toProperty();
  houmLightsP
    .forEach(log, "HOUM lights found");
  houmConnectE.onValue(() => {
    houmSocket.emit('clientReady', { siteKey: houmConfig.siteKey});
    return log("Connected to HOUM");
  });
  const houmReadyE = B.combineAsArray(houmConnectE, houmLightsP).map(true);
  const houmReadyP = B.once(false).concat(houmReadyE).toProperty();
  houmReadyE.forEach(() => log("HOUM ready"));

  const lightE= B.fromEvent(houmSocket, 'setLightState');
  const lightStateE = lightE
    .combine(houmLightsP, function({_id, bri}, lights) {
      const light = findById(_id, lights);
      return { lightId: light.lightId, room: light.room, light: light.light, type:"brightness", value:bri };
  })
    .sampledBy(lightE);

  const fullLightStateP = lightStateE
    .scan({}, function(state, light) {
      state = R.clone(state);
      state[light.lightId]=light;
      return state;
  }).combine(houmLightsP, function(state, allLights) {
      state = R.clone(state);
      allLights.forEach(function(light) {
        if (!state[light.lightId]) {
          return state[light.lightId] = light;
        }
      });
      return state;
  });

  const lightStateP = query => lightStateE
    .filter(matchLight(query))
    .toProperty();

  const totalBrightnessP = query => fullLightStateP
    .map(filterLightState(query))
    .map(state => R.sum(R.values(state).map(light => light.value)));

  var filterLightState = query => fullLightState => R.indexBy(R.prop("lightId"), R.values(fullLightState).filter(matchLight(query)));

  var matchLight = query => (function(light) {
    if (!(query instanceof Array)) {
      query = [query];
    }
    const matchSingle = q => (light.lightId === q) || (light.light.toLowerCase() === q.toLowerCase()) || (light.room.toLowerCase() === q.toLowerCase());
    return R.any(matchSingle, query);
  });

  const setLight = query => bri => houmLightsP.take(1).forEach(function(lights) {
    lights = findByQuery(query, lights);
    if (lights.length > 0) {
      return lights.forEach(function(light) {
        let lightOn = bri;
        if (typeof bri === "number") {
          lightOn = bri>0;
        } else {
          bri = booleanToBri(lightOn);
        }
        log("Set", light.light, "bri="+bri, "on="+lightOn);
        if (!mock) {
          return houmSocket.emit('apply/light', {_id: light.lightId, on: lightOn, bri });
        }
      });
    } else {
      return log("ERROR: light", query, " not found");
    }
  });

  const fadeLight = query => (function(bri, duration) {
    if (duration == null) { duration = time.seconds(10); }
    return fullLightStateP.take(1).forEach(function(lights) {
      lights = findByQuery(query, R.values(lights));
      if (lights.length > 0) {
        return lights.forEach(function(light) {
          //log "fading light", light.light, "from", light.value, "to", bri, "in", time.formatDuration(duration)
          if (!light.value) {
            return setLight(light.lightId)(bri);
          } else {
            const distance = Math.abs(bri - light.value);
            const steps = 100;
            let stepSize = distance / steps;
            let stepDuration = duration / stepSize;
            if (stepDuration < 100) {
              stepDuration = 100;
              stepSize = (distance * duration) / stepDuration;
            }
            return B.fade(light.value, bri, stepDuration, stepSize)
              .forEach(nextBri => // TODO: abort on external event
            setLight(light.lightId)(nextBri));
          }
        });
      } else {
        return log("ERROR: light", query, " not found");
      }
    });
  });

  tcpDevices.forEach(function({deviceId, properties}) {
    const lightId = properties != null ? properties.lightId : undefined;
    if (lightId) {
      const sendState = function(state) {
        const transform = bri => { 
          const max = (properties.brightness != null ? properties.brightness.max : undefined) || 255;
          const scaled = Math.round(scale(0, 255, 0, max)(bri));
          if ((properties.brightness != null ? properties.brightness.quadratic : undefined)) { return quadraticBrightness(scaled, max); } else { return scaled; }
        };

        const mappedState = L.modify(L.prop("value"), transform, state);
        log("send light state to tcp device " + deviceId + ": " + JSON.stringify(mappedState) + ", mapped from " + state.value + " to " + mappedState.value);
        return tcpServer.sendToDevice(deviceId)(mappedState);
      };
      lightStateP(lightId).forEach(sendState);
      lightStateP(lightId).debounce(2000).forEach(sendState);
      return tcpServer.deviceConnectedE
        .filter(id => id === deviceId)
        .map(lightStateP(lightId))
        .delay(1000)
        .forEach(sendState);
    }
  });

  const controlLight = function(query, controlP, manualOverridePeriod) {
    if (manualOverridePeriod == null) { manualOverridePeriod = time.hours(3); }
    const valueDiffersFromControl = (v, c) => v !== booleanToBri(c);
    const setValueE = lightStateP(query)
      .map(".value")
      .changes();
    const ackP = controlP.flatMapLatest(c => B.once(false).concat(setValueE.skipWhile(v => valueDiffersFromControl(v, c)).take(1).map(true))).toProperty();
    ackP.log(query + " control ack");
    const manualOverrideE = ackP.changes().filter(B._.id).flatMapLatest(function(v) {
      console.log("start monitoring " + query + " overrides");
      return setValueE.takeUntil(controlP.changes());
    }).withLatestFrom(controlP, valueDiffersFromControl);
    const manualOverrideP = manualOverrideE
      .flatMapLatest(function(override) { 
        if (override) {
          return B.once(true).concat(B.later(manualOverridePeriod, false));
        } else {
          return B.once(false);
        }})
      .toProperty(false)
      .skipDuplicates()
      .log("manual override active for " + query);

    controlP.filter(manualOverrideP.not()).forEach(setLight(query));
    return manualOverrideP.changes().filter(x => !x).map(controlP).skipDuplicates().forEach(setLight(query));
  };


  const findByName = (name, lights) => R.find((light => light.name.toLowerCase() === name.toLowerCase()), lights);
  var findById = (id, lights) => R.find((light => light.lightId === id), lights);
  var findByQuery = (query, lights) => R.filter(matchLight(query), lights);

  const siteApi = {
    houmReadyE, houmReadyP, houmLightsP, lightStateE, lightStateP, totalBrightnessP,
    controlLight, fadeLight, setLight,
    quadraticBrightness, booleanToBri 
  };
  return siteApi;
};

module.exports = { initSite, quadraticBrightness, booleanToBri };
