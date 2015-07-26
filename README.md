## sensor-server

Sends data from local sensors to Keen.io

### Install

Install

    npm install

Create the file `keep-config.coffee` in this  directory and add your Keen.IO configuration there. Like this:

```coffeescript
module.exports = {
  projectId: "YOURPROJECTIT"
  writeKey: "YOURWRITEKEY"
}
```

### Run

    coffee server.coffee

### Test it without actually sending

    dont_send=true coffee server.coffee

### Sensor protocol

Sensors are supposed to connect via TCP and send a one-liner JSON message and disconnect.

The JSON message has this format:

    {"location":"?","device": "?","temperature":?,"humidity":?}
