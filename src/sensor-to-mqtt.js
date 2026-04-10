const mqtt = require('mqtt')
const log = require("./log")
const tcp = require("./tcp-server")
const time = require("./time")
const intertechno = require("./intertechno")

const SENSOR_TYPES = {
  temperature: {
    discovery: {
      device_class: "temperature",
      unit_of_measurement: '°C'
    },
    mapValue(value) {
      return String(value)
    }
  },
  motion: {
    discovery: {
      device_class: 'motion',
      payload_on: 'ON',
      payload_off: 'OFF',      
    },
    mapValue(value) {
      return value ? "ON" : "OFF"
    }
  }
}

function init(mqttConfig) {
  const discovered = new Set()
  const client = mqtt.connect(mqttConfig.brokerUrl, {
    username: mqttConfig.username,
    password: mqttConfig.password
  })
  client.on('error', function(err) {
    console.error('MQTT error', err)
  })

  return { sendSensorEventToMqtt, publishMqttLight }

  function publishDiscovery(device, name, nodeId, stateTopic, type) {
    const payload = {
      name: nodeId,
      state_topic: stateTopic,
      unique_id: nodeId,
      device: {
        identifiers: [device],
        name
      },
      ...SENSOR_TYPES[type].discovery
    }

    client.publish('homeassistant/sensor/' + nodeId + '/config', JSON.stringify(payload), { retain: true })
    log("MQTT publish discovery", 'homeassistant/sensor/' + nodeId + '/config', JSON.stringify(payload))
  }

  function sendSensorEventToMqtt(event) {    
    
    const { device, name, value, type } = event
    const sensorType = SENSOR_TYPES[type]

    if (value === undefined || !sensorType || !device) return

    const nodeId = device + '_' + type
    const stateTopic = 'sensors/' + device + '/' + type

    if (!discovered.has(nodeId)) {
      publishDiscovery(device, name, nodeId, stateTopic, type)
      discovered.add(nodeId)
    }

    const mapped = sensorType.mapValue(value)
    log("MQTT publish value", stateTopic, value, "mapped to", mapped)
    client.publish(stateTopic, mapped, { retain: true })
  }

  function publishLightDiscovery(device, properties) {
    const commandTopic = 'lights/' + device + '/set'
    const stateTopic = 'lights/' + device + '/brightness'
    const availabilityTopic = 'lights/' + device + '/availability'
    const name = properties.name || device
    const dimmable = !properties.intertechnoId && properties.dimmable !== false
    const payload = {
      unique_id: device + '_light',
      schema: 'json',
      name,
      state_topic: stateTopic,
      brightness: dimmable,
      ...(dimmable && { brightness_scale: 255 }),
      command_topic: commandTopic,
      availability_topic: availabilityTopic,
      payload_available: 'online',
      payload_not_available: 'offline',
      device: {
        identifiers: [device],
        name: device
      },
    }
    client.publish('homeassistant/light/' + device + '/config', JSON.stringify(payload), { retain: true })
    log("MQTT publish light discovery", 'homeassistant/light/' + device + '/config', JSON.stringify(payload))
    return { commandTopic, stateTopic, availabilityTopic }
  }


  function TCPLight(deviceId, properties, onConnect, onDisconnect) {
    tcp.deviceConnectedE.filter(id => id === deviceId).onValue(onConnect)
    tcp.deviceDisconnectedE.filter(id => id === deviceId).onValue(onDisconnect)
    return {
      setBrightness(brightness) {
        log("MQTT received light state for TCP device " + deviceId + " brightness=" + brightness)
        tcp.sendBrightnessToDevice(deviceId, properties, brightness)
      },
    }
  }

  function IntertechnoLight(deviceId, properties, onConnect) {
    log("MQTT init Intertechno light", deviceId)
    onConnect()
    let timeout = null
    return {
      setBrightness(brightness) {
        log("MQTT received light state for Intertechno device " + deviceId + " brightness=" + brightness)
        const sendIt = () => {
          log("MQTT send brightness to Intertechno device " + deviceId + " brightness=" + brightness)
          intertechno.sendIntertechnoState(properties.intertechnoId, brightness > 0)
          if (timeout) clearTimeout(timeout)
          // Re-send each 10 minutes for extra reliability
          timeout = setTimeout(sendIt, 10 * 60000)
        }
        // Some randomness to avoid conflict
        setTimeout(sendIt, Math.random() * 5000)
      },
    }
  }

  function publishMqttLight(deviceId, properties) {
    const { commandTopic, stateTopic, availabilityTopic } = publishLightDiscovery(deviceId, properties)
    const isIntertechno = properties.intertechnoId !== undefined
    const onConnect = () => {
      client.subscribe(commandTopic)
      // Subscribe for initial state only
      client.subscribe(stateTopic)      
      client.publish(availabilityTopic, "online", { retain: true })      
      log("MQTT publish light available", deviceId)
    }

    const onDisconnect = () => {
      client.unsubscribe(commandTopic)
      client.unsubscribe(stateTopic)
      client.publish(availabilityTopic, "offline", { retain: true })      
      log("MQTT publish light unavailable", deviceId)
    }

    const light = isIntertechno
      ? IntertechnoLight(deviceId, properties, onConnect, onDisconnect) 
      : TCPLight(deviceId, properties, onConnect, onDisconnect)

    
    client.on('message', function(topic, message) {
        const str = message.toString()
      if (topic === commandTopic) {
        parseAndApplyState()
        client.publish(stateTopic, str, { retain: true })
      } else if (topic === stateTopic) {
        // Get initial state for device
        parseAndApplyState()
        client.unsubscribe(stateTopic)
      }

      function parseAndApplyState() {
        const msg = JSON.parse(str)
        const brightness = msg.state === "OFF" ? 0 : msg.brightness !== undefined ? msg.brightness : 255
        light.setBrightness(brightness)
      }
    })    
  }
}


module.exports = { init }
