const net = require('net');
const B = require('baconjs');
const R = require('ramda');
const log = require("./log");
const rp = require('request-promise');

const args = process.argv.slice(2);
const host = args[0] || "localhost";
const port = args[1] || 5080;
const event = { type: "test", value: 600 };
rp({method: "post", uri: "http://" + host + ":" + port + "/event", body: event, json: true})
    .then(() => console.log("posted"));
