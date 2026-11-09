// node shots.js <index.html> <outdir> <width> [theme]  — one PNG per section, plus console errors.
const { chromium } = require('playwright');
(async () => {
  const [file, out, width, theme] = process.argv.slice(2);
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: +width, height: 900 }, deviceScaleFactor: 1, colorScheme: theme || 'dark' });
  const errs = [];
  p.on('console', m => { if (m.type() === 'error') errs.push(m.text()); });
  p.on('pageerror', e => errs.push(String(e)));
  await p.goto('file://' + file);
  await p.addStyleTag({ content: '.topbar,.sidenav{position:static!important}' });
  await p.waitForTimeout(1500);
  const ids = await p.$$eval('section.sec', s => s.map(x => x.id));
  for (const id of ids) {
    const el = await p.$('#' + id);
    await el.screenshot({ path: `${out}/${width}-${theme || 'dark'}-${id}.png` });
  }
  const overflow = await p.evaluate(() => document.documentElement.scrollWidth - innerWidth);
  console.log('sections', ids.length, 'horizontal overflow px', overflow, 'errors', JSON.stringify(errs));
  await b.close();
})();
