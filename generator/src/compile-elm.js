const { compileToString } = require("node-elm-compiler");
XMLHttpRequest = require("xhr2");

module.exports = runElm;
function runElm(callback) {
  const elmBaseDirectory = "./elm-stuff/elm-pages";
  const mainElmFile = "../../src/Main.elm";
  const startingDir = process.cwd();
  process.chdir(elmBaseDirectory);
  compileToString([mainElmFile], {}).then(function(data) {
    (function() {
      const warnOriginal = console.warn;
      console.warn = function() {};
      eval(data.toString());
      const app = Elm.Main.init({ flags: { imageAssets: {} } });

      app.ports.toJsPort.subscribe(payload => {
        process.chdir(startingDir);

        if (payload.tag === "Success") {
          callback(payload.args[0]);
        } else {
          console.log("ERROR bad payload", payload);
          process.exit(1);
        }
        delete Elm;
        console.warn = warnOriginal;
      });
    })();
  });
}
