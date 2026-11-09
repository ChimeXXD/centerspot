const { chromium } = require('playwright');
(async () => {
  const [svg, png] = process.argv.slice(2);
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1024, height: 1024 } });
  await p.goto('file://' + svg);
  await p.screenshot({ path: png, omitBackground: false });
  await b.close();
})();
