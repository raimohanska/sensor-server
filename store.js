const fs = require("fs");
const B = require("baconjs");

const storage = function(name) {
  const filename = name + ".json";
  const storedValuesP = B.fromNodeCallback(fs, "readFile", filename, "utf-8")
      .mapError("{}")
      .flatMap(B.try(JSON.parse))
      .toProperty();
  const write = (key, value) => storedValuesP
    .flatMap(function(storedValues) {
      storedValues[key] = value;
      return B.fromNodeCallback(fs, "writeFile", filename, JSON.stringify(storedValues), "utf-8");
    }).onValue(function() {});
  const read = key => 
    storedValuesP.map(values => values[key]).filter(B._.id);
  return { write, read };
};

module.exports = storage;
