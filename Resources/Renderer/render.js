#!/usr/bin/env node

const fs = require("fs");
const { mathjax } = require("./mathjax-full/js/mathjax.js");
const { TeX } = require("./mathjax-full/js/input/tex.js");
const { SVG } = require("./mathjax-full/js/output/svg.js");
const { liteAdaptor } = require("./mathjax-full/js/adaptors/liteAdaptor.js");
const { RegisterHTMLHandler } = require("./mathjax-full/js/handlers/html.js");
const { SerializedMmlVisitor } = require("./mathjax-full/js/core/MmlTree/SerializedMmlVisitor.js");
const { STATE } = require("./mathjax-full/js/core/MathItem.js");

require("./mathjax-full/js/input/tex/base/BaseConfiguration.js");
require("./mathjax-full/js/input/tex/action/ActionConfiguration.js");
require("./mathjax-full/js/input/tex/ams/AmsConfiguration.js");
require("./mathjax-full/js/input/tex/amscd/AmsCdConfiguration.js");
require("./mathjax-full/js/input/tex/bbox/BboxConfiguration.js");
require("./mathjax-full/js/input/tex/boldsymbol/BoldsymbolConfiguration.js");
require("./mathjax-full/js/input/tex/braket/BraketConfiguration.js");
require("./mathjax-full/js/input/tex/bussproofs/BussproofsConfiguration.js");
require("./mathjax-full/js/input/tex/cancel/CancelConfiguration.js");
require("./mathjax-full/js/input/tex/cases/CasesConfiguration.js");
require("./mathjax-full/js/input/tex/centernot/CenternotConfiguration.js");
require("./mathjax-full/js/input/tex/color/ColorConfiguration.js");
require("./mathjax-full/js/input/tex/colorv2/ColorV2Configuration.js");
require("./mathjax-full/js/input/tex/colortbl/ColortblConfiguration.js");
require("./mathjax-full/js/input/tex/configmacros/ConfigMacrosConfiguration.js");
require("./mathjax-full/js/input/tex/empheq/EmpheqConfiguration.js");
require("./mathjax-full/js/input/tex/enclose/EncloseConfiguration.js");
require("./mathjax-full/js/input/tex/extpfeil/ExtpfeilConfiguration.js");
require("./mathjax-full/js/input/tex/gensymb/GensymbConfiguration.js");
require("./mathjax-full/js/input/tex/html/HtmlConfiguration.js");
require("./mathjax-full/js/input/tex/mathtools/MathtoolsConfiguration.js");
require("./mathjax-full/js/input/tex/newcommand/NewcommandConfiguration.js");
require("./mathjax-full/js/input/tex/noerrors/NoErrorsConfiguration.js");
require("./mathjax-full/js/input/tex/noundefined/NoUndefinedConfiguration.js");
require("./mathjax-full/js/input/tex/physics/PhysicsConfiguration.js");
require("./mathjax-full/js/input/tex/setoptions/SetOptionsConfiguration.js");
require("./mathjax-full/js/input/tex/tagformat/TagFormatConfiguration.js");
require("./mathjax-full/js/input/tex/textcomp/TextcompConfiguration.js");
require("./mathjax-full/js/input/tex/textmacros/TextMacrosConfiguration.js");
require("./mathjax-full/js/input/tex/upgreek/UpgreekConfiguration.js");
require("./mathjax-full/js/input/tex/unicode/UnicodeConfiguration.js");
require("./mathjax-full/js/input/tex/verb/VerbConfiguration.js");

const SUPPORTED_PACKAGES = [
  "base",
  "action",
  "ams",
  "amscd",
  "bbox",
  "boldsymbol",
  "braket",
  "bussproofs",
  "cancel",
  "cases",
  "centernot",
  "color",
  "colortbl",
  "empheq",
  "enclose",
  "extpfeil",
  "gensymb",
  "html",
  "mathtools",
  "newcommand",
  "noerrors",
  "noundefined",
  "upgreek",
  "unicode",
  "verb",
  "configmacros",
  "tagformat",
  "textcomp",
  "textmacros",
  "setoptions",
  "physics"
];

function readStdin() {
  return fs.readFileSync(0, "utf8");
}

function main() {
  try {
    const payload = JSON.parse(readStdin() || "{}");
    const latex = typeof payload.latex === "string" ? payload.latex : "";

    const adaptor = liteAdaptor();
    RegisterHTMLHandler(adaptor);

    const tex = new TeX({ packages: SUPPORTED_PACKAGES });
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
