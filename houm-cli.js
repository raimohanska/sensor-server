const houm = require("./houm3");
const siteKey = process.env.HOUMIO_SITEKEY;
const args = process.argv;
const cmd = args[2];
const fail = function(msg) {
  console.error(msg);
  return process.exit(1);
};
const exit = () => process.exit(0);
const doHoum = function(f) {
  const site = {
    config: {
      houm3: { siteKey }
    }
  };
  return f(houm.initSite(site));
};
if ((siteKey == null)) {
  fail("HOUMIO_SITEKEY environment variable missing");
}

if ((cmd === "set") && (args.length === 5)) {
  const light = args[3];
  const targetValue = parseInt(args[4]);
  doHoum(function(houm) { 
    houm.lightStateP(light)
      .filter(({value}) => value === targetValue)
      .onValue(exit);
    return houm.setLight(light)(targetValue);
  });
} else {
  doHoum(houm => fail(`\
Usage: houm-cli set [light] [value]\
`));
}
