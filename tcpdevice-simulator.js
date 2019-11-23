const net = require('net');
const B = require('baconjs');
const R = require('ramda');
const log = require("./log");

const args = process.argv.slice(2);
const host = args[0] || "localhost";
const port = args[1] || 8001;

const client = new net.Socket();
client.connect(port, host, function() {
  console.log("connected");
  const carrier = (require("carrier")).carry(client);
  client.write(JSON.stringify({ device: "testdevice" }) + "\n");
  carrier.on("line", line => log(line));
});
