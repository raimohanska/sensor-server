## sensor-server

Server platform for collecting events from home automation sensors, transforming and storing data, and controlling lighting and appliances.

Supports event collection through TCP and HTTP POST. The idea is that the sensors connect to the server and send data.

Supports storing events into an InfluxDB database.

Has some APIs that allow you to use Bacon.js for transforming and combining your data and controlling your home.

The platform is not quite documented yet, but I can write some docs if there's interest. Please add a Star and create an Issue if you want more docs!

### FRP IoT

For me, home automation and IoT is about collecting streams of measurement values, storing them for later use and visualization, 
transforming and combining this data into control streams that can then be fed to actuators such as lighting, pumps and valves. To me, 
FRP with a library like Bacon.js seems like the perfect fit.

In Bacon.js, we use `EventStreams` to represent distinct events and `Properties` to represent values that change over time.

For instance, there's an API called `sensors` that will give me any measured value as a Property. So, when I write

```coffeescript
outdoorTempP = sensors.sensorP({type:"temperature", location: "outdoor"})
outdoorTempP.forEach((t) -> console.log("temperature is " + t)
````

... my function on line 2 will be called when the outside temperature property `outdoorTempP` changes and the temperature will be written to standard output. 
Not very useful yet, but let's add more stuff.

```coffeescript
freezingP = outdoorTempP.map((t) -> t < 0)
dayTimeP = time.hourOfDayP.map((hours) -> hours >= 6 || hours <= 22)
````

Here I've used the `map` method of `outdoorTempP` to transform the temperature values into boolean values so that the new 
property `freezingP` will hold `true` when temperature outside is freezing (I'm obviously using Celsius degrees here). 
Then I added a new property `dayTimeP` using a similar `map` call on the `hourOfDayP` property of the `time` API.

Finally, I add one more property from the `motion` API and combine all of the data using boolean logic:

```coffeescript
someoneHomeP = motion.occupiedP("livingroom", time.oneHour * 8)
fountainP = dayTimeP.and(freezingP.not()).and(someoneHomeP)
```

So the final `fountainP` property will hold `true` when it's daytime, not freezing and someone's home. 

Admittedly my "someone home" property is not very accurate, as it's based on whether there's been motion in the livingroom in the last 8 hours. I'll add an outdoor motion sensor later for more accuracy, but this will do for now. It's not fatal to have a fountain running even when I'm not home. But at least it won't be running when I'm on a 2-week vacation in Africa. During which my home automation system will, by the way, give the impression of an occupied house by turning lights on and off every now and then.

Anyways, now that I've defined when the fountain should be running, I can actually make it obey my will by using my reactive HOUM.IO API wrapper:

```coffeescript
houm.controlLight "fountain", fountainP
````

### APIs

- `houm` for controlling lighting and electric appliances
- `time` for time-of-day event streams and Properties, such as `hourOfDayP`
- `sun` for sunrise/sunset information and sun brightness in my location
- `sensors` for sensor input data (temperature, humidity, etc)
- `motion` motion sensor data, room occupied indication with throttling

Further documentaion missing.

### Install

Install

    npm install

Create the file `config.coffee` in this  directory and add InfluxDB configuration there. Like this:

```coffeescript
module.exports = {
  tcp:
    port: 8001
  sites:
    default:
      influx:
        database: "mydb"
        username: ""
        password: ""
        protocol: "http"
        host: "localhost"
        port: 8086
      devices:
        "sensor1":
          properties: { location: "livingroom" }
        "raimo-unit-1":
          properties: { location: "olohuone", lightId: "56d1815c36bae20300614d31"}
      latitude: 60.2695100
      longitude: 25.9557500
      houm:
        siteKey: "my_site_key"
      init: ({log, time, sun, houm, sensors, motion, R, B}) ->
        nightTimeP = time.hourOfDayP.map((hours) -> hours <= 6 || hours >= 21)
        nightTimeP.log("nighttime")
```

You can omit any of the `influx` and `propertyMapping` sections if you don't need one of them.

Then run:

    npm start

Run, restart on file changes

    npm run watch

### Devices

The `devices` section in the configuration file is used to match incoming events and add some extra tags. For instance,
you may use this to recognize a device and add a `location` field for that device. I use this to assign `location` value for my 
several sensors. I use room names as `location` values.

### Event collection

Sensor events are collected using a couple of protocols.

#### HTTP POST Sensor Protocol

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

An array of events is accepted too, so that multiple events can be included in a single POST.

#### TCP Protocol

Sensor event collection with JSON over TCP. Documentation missing.

#### Intertechno switches ####

To enable support, run `npm install --save node-intertechno-sender`