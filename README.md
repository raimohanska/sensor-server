## sensor-server

Local proxy server for collecting sensor events and sending them
to Keen.io. The local proxy is needed because at least my sensors
don't have SSL/TLS capabilities.

### Install

Install

    npm install

Create the file `keen-config.coffee` in this  directory and add your Keen.IO configuration there. Like this:

```coffeescript
module.exports = {
  projectId: "YOURPROJECTIT"
  writeKey: "YOURWRITEKEY"
}
```

### Run

Run normally

    npm run serve

Run, restart on file changes

    npm run watch

Test it without actually sending to Keen

    dont_send=true npm run watch

### HTTP POST Sensor Protocol

Send sensor events using HTTP POST. Try this:

    curl -H "Content-Type: application/json" -X POST -d '{"type": "temperature", "location": "bedroom", "value": 100}' http://localhost:5080/event

### Simple TCP Sensor protocol

Sensors are supposed to connect via TCP and send a one-liner JSON message and disconnect.

The JSON message has this format:

    {"location":"?","device": "?","temperature":?,"humidity":?}

Only the `location` and `device` fields are kinda required. A Keen.IO event
will be generated for each of the other values, and the `location` and `device`
fields are included in each generated event.
