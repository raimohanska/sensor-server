#!/usr/bin/env node
// Usage: node src/mqtt-send.js <topic> <json>
// Example: node src/mqtt-send.js lights/device1/set '{"state":"ON","brightness":128}'

const mqtt = require('mqtt')

const [,, topic, json] = process.argv

if (!topic || !json) {
  console.error('Usage: mqtt-send.js <topic> <json>')
  process.exit(1)
}

try {
  JSON.parse(json)
} catch (e) {
  console.error('Invalid JSON:', e.message)
  process.exit(1)
}

const brokerUrl = process.env.MQTT_BROKER || 'mqtt://localhost:1883'
const client = mqtt.connect(brokerUrl)

client.on('connect', function() {
  client.publish(topic, json, { retain: false }, function(err) {
    if (err) console.error('Publish error:', err.message)
    else console.log('Sent to', topic + ':', json)
    client.end()
  })
})

client.on('error', function(err) {
  console.error('MQTT error:', err.message)
  process.exit(1)
})
