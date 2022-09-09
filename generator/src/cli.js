#!/usr/bin/env node

const build = require("./build.js");
const dev = require("./dev-server.js");
const generate = require("./codegen-template-module.js");
const init = require("./init.js");
const codegen = require("./codegen.js");
const fs = require("fs");
const path = require("path");

const commander = require("commander");
const Argument = commander.Argument;
const Option = commander.Option;

const packageVersion = require("../../package.json").version;

async function main() {
  const program = new commander.Command();

  program.version(packageVersion);

  program
    .command("build")
    .option("--debug", "Skip terser and run elm make with --debug")
    .option(
      "--base <basePath>",
      "build site to be served under a base path",
      "/"
    )
    .option(
      "--keep-cache",
      "Preserve the HTTP and JS Port cache instead of deleting it on server start"
    )
    .description("run a full site build")
    .action(async (options) => {
      if (!options.keepCache) {
        clearHttpAndPortCache();
      }
      options.base = normalizeUrl(options.base);
      await build.run(options);
    });

  program
    .command("codegen")
    .option(
      "--base <basePath>",
      "build site to be served under a base path",
      "/"
    )
    .description(
      "generate code, useful for CI where you don't want to run a full build"
    )
    .action(async (options) => {
      await codegen.generate(options.base);
    });

  program
    .command("dev")
    .description("start a dev server")
    .option("--port <number>", "serve site at localhost:<port>", "1234")
    .option("--debug", "Run elm make with --debug")
    .option(
      "--keep-cache",
      "Preserve the HTTP and JS Port cache instead of deleting it on server start"
    )
    .option("--base <basePath>", "serve site under a base path", "/")
    .option("--https", "uses a https server")
    .action(async (options) => {
      if (!options.keepCache) {
        clearHttpAndPortCache();
      }
      options.base = normalizeUrl(options.base);
      await dev.start(options);
    });

  program
    .command("add <moduleName>")
    .addOption(
      new Option("--state <state>", "Generate Page Module with state").choices([
        "local",
        "shared",
      ])
    )
    .option("--server-render", "Generate a Page.serverRender Page Module")
    .option(
      "--with-fallback",
      "Generate a Page.preRenderWithFallback Page Module"
    )
    .description("create a new Page module")
    .action(async (moduleName, options, b, c) => {
      await generate.run({
        moduleName,
        withState: options.state,
        serverRender: options.serverRender,
        withFallback: options.withFallback,
      });
    });

  program
    .command("init <projectName>")
    .description("scaffold a new elm-pages project boilerplate")
    .action(async (projectName) => {
      await init.run(projectName);
    });

  program
    .command("scaffold")
    .description("run a generator")
    .allowUnknownOption()
    .allowExcessArguments()
    .action(async (options, options2) => {
      const elmScaffoldProgram = require(path.join(
        process.cwd(),
        "./codegen/elm.js"
      )).Elm.Cli;
      const program = elmScaffoldProgram.init({
        flags: { argv: ["", "", ...options2.args], versionMessage: "1.2.3" },
      });
      // TODO compile `codegen/elm.js` file
      // program.ports.print.subscribe((message) => {
      //   console.log(message);
      // });
      program.ports.printAndExitFailure.subscribe((message) => {
        console.log(message);
        process.exit(1);
      });
      program.ports.printAndExitSuccess.subscribe((message) => {
        console.log(message);
        process.exit(0);
      });
      program.ports.writeFile.subscribe((info) => {
        const filePath = path.join(process.cwd(), "app", info.path);
        fs.writeFileSync(filePath, info.body);
        console.log("Success! Created file", filePath);
        process.exit(0);
      });
    });

  program
    .command("docs")
    .description("open the docs for locally generated modules")
    .option("--port <number>", "serve site at localhost:<port>", "8000")
    .action(async (options) => {
      await codegen.generate("/");
      const DocServer = require("elm-doc-preview");
      const server = new DocServer({
        port: options.port,
        browser: true,
        dir: "./elm-stuff/elm-pages/",
      });

      server.listen();
    });

  program.parse(process.argv);
}

function clearHttpAndPortCache() {
  const directory = ".elm-pages/http-response-cache";
  if (fs.existsSync(directory)) {
    fs.readdir(directory, (err, files) => {
      if (err) {
        throw err;
      }

      for (const file of files) {
        fs.unlink(path.join(directory, file), (err) => {
          if (err) {
            throw err;
          }
        });
      }
    });
  }
}

/**
 * @param {string} rawPagePath
 */
function normalizeUrl(rawPagePath) {
  const segments = rawPagePath
    .split("/")
    // Filter out all empty segments.
    .filter((segment) => segment.length != 0);

  // Do not add a trailing slash.
  // The core issue is that `/base` is a prefix of `/base/`, but
  // `/base/` is not a prefix of `/base`, which can later lead to issues
  // with detecting whether the path contains the base.
  return `/${segments.join("/")}`;
}

main();
