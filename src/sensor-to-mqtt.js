const mqtt = require('mqtt')
const log = require("./log")
const tcp = require("./tcp-server")
const time = require("./time")
const intertechno = require("./intertechno")

const UNIT_BY_TYPE = {
  temperature: '°C',
  humidity: '%'
}

const SUPPORTED_TYPES = ["temperature", "motion"]



function init(mqttConfig) {
  const discovered = new Set()
  const client = mqtt.connect(mqttConfig.brokerUrl, {
    username: mqttConfig.username,
    password: mqttConfig.password
  })
  client.on('error', function(err) {
    console.error('MQTT error', err)
  })

  return { sendToMqtt, publishMqttLight }

  function publishDiscovery(device, name, nodeId, stateTopic, type) {
    const payload = {
      name: nodeId,
      state_topic: stateTopic,
      unique_id: nodeId,
      device: {
        identifiers: [device],
        name
      },      
    }
    const unit = UNIT_BY_TYPE[type]
    if (unit) payload.unit_of_measurement = unit

    client.publish('homeassistant/sensor/' + nodeId + '/config', JSON.stringify(payload), { retain: true })
    log("MQTT publish discovery", 'homeassistant/sensor/' + nodeId + '/config', JSON.stringify(payload))
  }

  function publishLightDiscovery(device, properties) {
    const commandTopic = 'lights/' + device + '/set'
    const stateTopic = 'lights/' + device + '/brightness'
    const name = properties.name || device
    const payload = {
      schema: 'json',
      name,
      state_topic: stateTopic,
      brightness: true,
      brightness_scale: 255,
      command_topic: commandTopic,
      unique_id: device + '_light',
      device: {
        identifiers: [device],
        name: device
      },
      retain: true,
    }
    client.publish('homeassistant/light/' + device + '/config', JSON.stringify(payload), { retain: true })
    log("MQTT publish light discovery", 'homeassistant/light/' + device + '/config', JSON.stringify(payload))
    return { commandTopic, stateTopic }
  }

  function sendToMqtt(event) {    
    const { device, name, value, type } = event
    if (value === undefined || !SUPPORTED_TYPES.includes(type) || !device) return

    const nodeId = device + '_' + type
    const stateTopic = 'sensors/' + device + '/' + type

    if (!discovered.has(nodeId)) {
      publishDiscovery(device, name, nodeId, stateTopic, type)
      discovered.add(nodeId)
    }

    log("MQTT publish value", stateTopic, value)
    client.publish(stateTopic, String(value))
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

  function IntertechnoLight(deviceId, properties, onConnect, onDisconnect) {
    log("MQTT init Intertechno light", deviceId)
    onConnect()
    setInterval(() => {
      // Request re-transmit each minute
      onDisconnect()
      setTimeout(onConnect, 1000)
    }, time.oneMinute * 1)
    return {
      setBrightness(brightness) {
        log("MQTT received light state for Intertechno device " + deviceId + " brightness=" + brightness)
        intertechno.sendIntertechnoState(properties.intertechnoId, brightness > 0)
      },
    }
  }

  function publishMqttLight(deviceId, properties) {
    const { commandTopic, stateTopic } = publishLightDiscovery(deviceId, properties)
    const onConnect = () => {
      client.subscribe(commandTopic)
      // Subscribe for initial state only
      client.subscribe(stateTopic)
    }

    const onDisconnect = () => {
      client.unsubscribe(commandTopic)
      client.unsubscribe(stateTopic)
    }

    const light = properties.intertechnoId 
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
