const B=require("baconjs");

const log = function(...msg) {
  console.log(new Date(), ...Array.from(msg));
  return msg[msg.length - 1];
};

module.exports = log;

B.Observable .prototype. log = function(...msg) {
  this.forEach(value => log(...Array.from(msg), value));
  return this;
};
