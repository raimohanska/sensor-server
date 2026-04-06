module.exports = {
  tcp: {
    port: 8001
  },
  sites: {
    default: {
      influx: {
        database: "mydb",
        username: "",
        password: "",
        protocol: "http",
        host: "localhost",
        port: 8086
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
      houm: {
        siteKey: "my_site_key"
      },
      init: ({log, time, sun, houm, sensors, motion, R, B}) => {
        const nightTimeP = time.hourOfDayP.map((hours) => hours <= 6 || hours >= 21);
        nightTimeP.log("nighttime");
      }
    }
  }
};
