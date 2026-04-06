const mqtt = require('mqtt')
const log = require("./log")

const UNIT_BY_TYPE = {
  temperature: '°C',
  humidity: '%'
}

const discovered = new Set()
let client = null


function init(mqttConfig) {
  client = mqtt.connect(mqttConfig.brokerUrl, {
    username: mqttConfig.username,
    password: mqttConfig.password
  })
  client.on('error', function(err) {
    console.error('MQTT error', err)
  })
}

function publishDiscovery(nodeId, stateTopic, type) {
  const payload = {
    name: nodeId,
    state_topic: stateTopic,
    unique_id: nodeId
  }
  const unit = UNIT_BY_TYPE[type]
  if (unit) payload.unit_of_measurement = unit

  client.publish('homeassistant/sensor/' + nodeId + '/config', JSON.stringify(payload), { retain: true })
  log("MQTT publish discovery", 'homeassistant/sensor/' + nodeId + '/config', JSON.stringify(payload))
}

function publishLightDiscovery(device) {
  const payload = {
    name: device,
    state_topic: 'sensors/' + device + '/brightness',
    brightness_state_topic: 'sensors/' + device + '/brightness',
    brightness_scale: 255,
    unique_id: device + '_light'
  }
  client.publish('homeassistant/light/' + device + '/config', JSON.stringify(payload), { retain: true })
  log("MQTT publish light discovery", 'homeassistant/light/' + device + '/config', JSON.stringify(payload))
}

const SUPPORTED_TYPES = ["temperature", "motion"]

function sendToMqtt(event) {
  if (!client) return

  const { device, value, type } = event
  if (value === undefined || !SUPPORTED_TYPES.includes(type) || !device) return

  const nodeId = device + '_' + type
  const stateTopic = 'sensors/' + device + '/' + type

  if (!discovered.has(nodeId)) {
    publishDiscovery(nodeId, stateTopic, type)
    discovered.add(nodeId)
  }

  log("MQTT publish value", stateTopic, value)
  client.publish(stateTopic, String(value))
}

function publishMqttLight(device) {
  if (!client) return
  publishLightDiscovery(device)
}

module.exports = { init, sendToMqtt, publishMqttLight }
