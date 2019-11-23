const B=require("baconjs");

B.fromNodeStream = stream => B.fromBinder(function(sink) {
  const listeners = {};
  const addListener = function(event, listener) {
    listeners[event] = listener;
    stream.on(event, listener);
  };
  addListener("data", chunk => sink(chunk));
  addListener("end", () => sink(new B.End()));
  addListener("error", error => sink(new B.Error(error)));
  return () => (() => {
    const result = [];
    for (let event in listeners) {
      const listener = listeners[event];
       result.push(stream.removeListener(event,listener));
    }
    return result;
  })();
});
