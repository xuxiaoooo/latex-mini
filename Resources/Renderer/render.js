#!/usr/bin/env node

const fs = require("fs");
const { mathjax } = require("./mathjax-full/js/mathjax.js");
const { TeX } = require("./mathjax-full/js/input/tex.js");
const { SVG } = require("./mathjax-full/js/output/svg.js");
const { liteAdaptor } = require("./mathjax-full/js/adaptors/liteAdaptor.js");
const { RegisterHTMLHandler } = require("./mathjax-full/js/handlers/html.js");
const { AllPackages } = require("./mathjax-full/js/input/tex/AllPackages.js");
const { SerializedMmlVisitor } = require("./mathjax-full/js/core/MmlTree/SerializedMmlVisitor.js");
const { STATE } = require("./mathjax-full/js/core/MathItem.js");

function readStdin() {
  return fs.readFileSync(0, "utf8");
}

function main() {
  try {
    const payload = JSON.parse(readStdin() || "{}");
    const latex = typeof payload.latex === "string" ? payload.latex : "";

    const adaptor = liteAdaptor();
    RegisterHTMLHandler(adaptor);

    const tex = new TeX({ packages: AllPackages });
    const svg = new SVG({ fontCache: "none" });
    const html = mathjax.document("", { InputJax: tex, OutputJax: svg });

    const svgNode = html.convert(latex, { display: true });
    const svgMarkup = adaptor.outerHTML(svgNode)
      .replace(/^<mjx-container[^>]*>/, "")
      .replace(/<\/mjx-container>$/, "")
      .trim();

    const mathNode = html.convert(latex, { display: true, end: STATE.COMPILED });
    const mathml = new SerializedMmlVisitor().visitTree(mathNode);

    process.stdout.write(JSON.stringify({
      ok: true,
      svg: svgMarkup,
      mathml
    }));
  } catch (error) {
    process.stdout.write(JSON.stringify({
      ok: false,
      error: error && error.message ? error.message : String(error)
    }));
    process.exitCode = 1;
  }
}

main();
