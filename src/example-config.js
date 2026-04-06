module.exports = {
  tcp: {
    port: 8001
  },
  sites: {
    default: {
      /*
      influx: {
        url: "https://localhost:8086",
        token: "",
        org: "",
        bucket: "default",
      },
      */
      mqtt: {
        brokerUrl: "mqtt://localhost:1883",
        username: "",
        password: ""
      },
      intertechno: {
        transmitPin: 18
      },
      devices: {
        "sensor1": {
          properties: { location: "livingroom" }
        },
        "testdevice": {
          properties: { location: "olohuone", lightId: "56d1815c36bae20300614d31" }
        }
      },
      latitude: 60.2695100,
      longitude: 25.9557500,
      init: ({log, time, sun, houm, sensors, motion, R, B}) => {
        const nightTimeP = time.hourOfDayP.map((hours) => hours <= 6 || hours >= 21);
        nightTimeP.log("nighttime");
      }
    }
  }
};
