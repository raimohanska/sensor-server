## sensor-server

Server for collecting events from home automation sensors.

Supports sending data over to Keen.IO and storing it into a local InfluxDB database.

## Install

Install

    npm install

Create the file `config.coffee` in this  directory and add your Keen.IO and InfluxDB configuration there. Like this:

```coffeescript
module.exports = {
  keen:
    projectId: "YOURPROJECTIT"
    writeKey: "YOURWRITEKEY"
  influx:
    database: "mydb"
    username: ""
    password: ""
    protocol: "http"
    host: "localhost"
    port: 8086
}
```

You can omit either of the `keen` and `influx` sections if you don't need one of them.

Then run:

    npm run serve

Run, restart on file changes

    npm run watch

Test it without actually sending to Keen

    dont_send=true npm run watch

## Event collection

Sensor events are collected using a couple of protocols.

### HTTP POST Sensor Protocol

Server accepts incoming events as HTTP POST requests to the `/event` path on HTTP port 5080.

Event documents look like this:

```json
{
    "type": "temperature", 
    "location": "bedroom", 
    "value": 100
}
```

The `value` field is required. In addition, there must be at least one other field for identifying the events source. My convention is to use `type` for describing what kind of data is transmitted and `location` for identifying the location of the sensor.

Try this:

    curl -H "Content-Type: application/json" -X POST -d '{"type": "temperature", "location": "bedroom", "value": 100}' http://localhost:5080/event

### Simple TCP Sensor protocol

Sensors are supposed to connect via TCP and send a one-liner JSON message and disconnect.

The JSON message has this format:

    {"location":"?","device": "?","temperature":?,"humidity":?}

Only the `location` and `device` fields are kinda required. A Keen.IO event
will be generated for each of the other values, and the `location` and `device`
fields are included in each generated event.
