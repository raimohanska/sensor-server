"use strict";
const B = require('baconjs');
const R = require('ramda');
const scale = require('./scale');
const time = require("./time");
const io = require('socket.io-client');
const log = (...msg) => console.log(new Date().toString(), ...Array.from(msg));
const rp = require('request-promise');
const tcpServer = require('./tcp-server');
const mock = require("./mock");

const quadraticBrightness = (bri, max) => Math.ceil((bri * bri) / (max || 255));
const booleanToBri = function(b) { 
  if (typeof b === "number") {
    return b;
  } else {
    if (b) { return 255; } else { return 0; }
  }
};


const initSite = function(site) {
  const siteConfig = site.config;
  const houmConfig = siteConfig.houm3;
  if (!houmConfig) {
    return null;
  }
  const houmSocket = io.connect('https://houmkolmonen.herokuapp.com', {
    reconnectionDelay: 1000,
    reconnectionDelayMax: 3000,
    transports: ['websocket']
  });
  const houmConnectE = B.fromEvent(houmSocket, "connect");
  //const houmDisconnectE = B.fromEvent(houmSocket, "disconnect");
  const tcpDevices = R.toPairs(siteConfig.devices)
    .map(function(...args) { const [deviceId, {properties}] = Array.from(args[0]); return { deviceId, properties}; })
    .filter(({properties}) => properties != null ? properties.tcp : undefined);
  const {
    siteKey
  } = houmConfig;
  const houmConfigUrl = "https://houmkolmonen.herokuapp.com/api/site/" + siteKey;
  const houmLightsP = B.fromPromise(rp(houmConfigUrl))
    .map(JSON.parse)
    .map(function(config) { 
          const roomNames = R.fromPairs(config.locations.rooms.map(room => [room.id, room.name]));
          return config.devices.map(({name,roomId,id})=> ({light:name,room: roomNames[roomId],lightId:id}));
        })
    .toProperty();
  houmLightsP
    .forEach(log, "HOUM lights found");
  houmConnectE.onValue(() => {
    houmSocket.emit('subscribe', { siteKey });
    log("Connected to HOUM");
  });
  const houmReadyE = B.combineAsArray(houmConnectE, houmLightsP).map(true);
  const houmReadyP = B.once(false).concat(houmReadyE).toProperty();
  houmReadyE.forEach(() => log("HOUM ready"));
  B.fromEvent(houmSocket, 'siteKeyFound').log("Site found");

  B.fromEvent(houmSocket, 'noSuchSiteKey').log("HOUM site not found by key");
  const houmUpdateE = B.fromEvent(houmSocket, "site")
  const houmConnectionStaleE = houmUpdateE.map(true).debounce(time.minutes(1))
    .log("Houm connection stale. Reconnecting...")
    .forEach(() => { 
      houmSocket.disconnect() 
      houmSocket.connect()
    })

  const lightE = houmUpdateE
    .map(".data.devices")
    .map(devices => devices.map(d => ({
    id: d.id,
    bri: d.state.on ? ((d.state.bri !== undefined) ? d.state.bri : 255) : 0
  })))
    .diff([], R.flip(R.difference))
    .changes()
    .skip(1)
    .flatMap(B.fromArray);

  const lightStateE = lightE
    .combine(houmLightsP, function({id, bri}, lights) {
      const light = findById(id, lights);
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
      lights.forEach(function(light) {
        let lightOn = bri;
        if (typeof bri === "number") {
          lightOn = bri>0;
        } else {
          bri = booleanToBri(lightOn);
        }
        log("Set", light.light, "bri="+bri, "on="+lightOn);
        if (!mock) {
          houmSocket.emit('apply/device', {
            siteKey,
            data: { id: light.lightId, state: { on: lightOn, bri } }
          });
        }
        tcpDevices.forEach(function(device) {
          const lightId = device.properties != null ? device.properties.lightId : undefined;
          if (lightId === light.lightId) {
            log("Shortcut send to tcp device");
            sendToTcpDevice(device, bri);
          }
        });
      });
    } else {
      log("ERROR: light", query, " not found");
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

  tcpDevices.forEach(function(device) {
    const lightId = device.properties != null ? device.properties.lightId : undefined;
    if (lightId) {
      const sendState = state => sendToTcpDevice(device, state.value);
      lightStateP(lightId).forEach(sendState);
      lightStateP(lightId).debounce(2000).forEach(sendState);
      return tcpServer.deviceConnectedE
        .filter(id => id === device.deviceId)
        .map(lightStateP(lightId))
        .delay(1000)
        .forEach(sendState);
    }
  });

  var sendToTcpDevice = function({deviceId, properties}, bri) {
    const transform = bri => { 
      const max = (properties.brightness != null ? properties.brightness.max : undefined) || 255;
      const scaled = Math.round(scale(0, 255, 0, max)(bri));
      if ((properties.brightness != null ? properties.brightness.quadratic : undefined)) { return quadraticBrightness(scaled, max); } else { return scaled; }
    };

    const mappedState = { type: "brightness", value: transform(bri) };
    log("send light state to tcp device " + deviceId + ": " + JSON.stringify(mappedState) + ", mapped from " + bri + " to " + mappedState.value);
    return tcpServer.sendToDevice(deviceId)(mappedState);
  };

  const controlLight = function(query, controlP, manualOverridePeriod, manualOverridePeriodOffState) {
    if (manualOverridePeriod == null) { manualOverridePeriod = time.hours(3); }
    if (manualOverridePeriodOffState == null) { manualOverridePeriodOffState = manualOverridePeriod; }
    const valueDiffersFromControl = (v, c) => v !== booleanToBri(c) ? v : undefined;
    const setValueE = lightStateP(query)
      .map(".value")
      .changes();
    const ackP = controlP.flatMapLatest(c => B.once(false).concat(setValueE.skipWhile(v => valueDiffersFromControl(v, c)).take(1).map(true))).toProperty();
    ackP.log(query + " control ack");
    const manualOverrideE = ackP.changes().filter(B._.id).flatMapLatest(function() {
      console.log("start monitoring " + query + " overrides");
      return setValueE.takeUntil(controlP.changes()).log("override event for " + query);
    }).withLatestFrom(controlP, valueDiffersFromControl);
    const manualOverrideP = manualOverrideE
      .flatMapLatest(function(override) { 
        if (override != undefined) {
          const period = override > 0 ? manualOverridePeriod : manualOverridePeriodOffState
          log("Manual override started for " + query + " and active for " + time.formatDuration(period))
          return B.once(true).concat(B.later(period, false));
        } else {
          return B.once(false);
        }})
      .toProperty(false)
      .skipDuplicates()

    manualOverrideP.filter(o => !o)
      .onValue(()=> log("manual override ended for " + query));

    controlP.filter(manualOverrideP.not()).forEach(setLight(query));
    return manualOverrideP.changes().filter(x => !x).map(controlP).skipDuplicates().forEach(setLight(query));
  };


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
