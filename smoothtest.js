const B=require("baconjs");
require("./bacon-extensions");
const houm=require("./houm");
const log=require("./log");

log("begin");

B.repeatedly(1000, [0,1]).toProperty()
  .smooth({ stepTime: 50, step: 0.2 })
  .log();
