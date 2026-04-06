const mqtt = require('mqtt')
const log = require("./log")
const tcp = require("./tcp-server")

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
  const commandTopic = 'lights/' + device + '/set'
  const stateTopic = 'lights/' + device + '/brightness'
  const payload = {
    schema: 'json',
    name: device,
    state_topic: stateTopic,
    brightness: true,
    brightness_scale: 255,
    command_topic: commandTopic,
    unique_id: device + '_light',
    retain: true,
  }
  client.publish('homeassistant/light/' + device + '/config', JSON.stringify(payload), { retain: true })
  log("MQTT publish light discovery", 'homeassistant/light/' + device + '/config', JSON.stringify(payload))
  return { commandTopic, stateTopic }
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

function publishMqttLight(deviceId, properties) {
  if (!client) return
  const { commandTopic, stateTopic } = publishLightDiscovery(deviceId)
  // Expected message on commandTopic (JSON schema):
  //   {"state": "ON", "brightness": 128}
  //   {"state": "OFF"}
  client.subscribe(commandTopic)
  client.on('message', function(topic, message) {
    if (topic === commandTopic) {
      const str = message.toString()
      const msg = JSON.parse(str)
      const brightness = msg.state === "OFF" ? 0 : msg.brightness !== undefined ? msg.brightness : 255
      log("MQTT received light state for TCP device " + deviceId + " brightness=" + brightness)
      tcp.sendBrightnessToDevice(deviceId, properties, brightness)
      client.publish(stateTopic, str)
    }
  })
}

module.exports = { init, sendToMqtt, publishMqttLight }
