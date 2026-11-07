// Rendering contract of the actual shared icons and buttons; no browser or API writes.
const path = require('node:path');
const fs = require('node:fs');
const Module = require('node:module');
const assert = require('node:assert/strict');
const front = path.resolve(__dirname, '../..');
const esbuild = require(path.join(front, 'node_modules/esbuild'));
let checks = 0;
function ok(value, message) { assert(value, message); checks++; }
function eq(actual, expected) { assert.deepEqual(actual, expected); checks++; }
(async () => {
  const built = await esbuild.build({
    stdin: { contents: "export {default as Icon} from './src/components/AppIcon';export {default as Button} from './src/components/ActionButton';export {lineAwesomePaths as paths} from './src/components/icons8/lineAwesome';export {createElement} from 'react';export {renderToStaticMarkup} from 'react-dom/server';", resolveDir: front },
    bundle: true, write: false, platform: 'node', format: 'cjs', jsx: 'automatic',
    external: ['react', 'react/jsx-runtime', 'react-dom/server'], loader: { '.css': 'empty' }, logLevel: 'error',
  });
  const mod = new Module(path.join(front, 'app-icons-proof.cjs'), module);
  mod.filename = path.join(front, 'app-icons-proof.cjs');
  mod.paths = Module._nodeModulePaths(front);
  mod._compile(built.outputFiles[0].text, mod.filename);
  const { Icon, Button, paths, createElement: h, renderToStaticMarkup: render } = mod.exports;
  // Every available pictogram can be rendered offline in each inherited theme color.
  for (const name of Object.keys(paths)) {
    const html = render(h(Icon, { name, size: 19 }));
    ok(html.includes('data-icon-provider="icons8-line-awesome"'), name);
    ok(html.includes('viewBox="0 0 32 32"') && html.includes('fill="currentColor"'), name);
    ok(html.includes('aria-hidden="true"') && html.includes('focusable="false"'), name);
    ok(html.includes('width="19"') && html.includes('<path'), name);
    ok(!/https?:|<image|<script|<use|stroke-width=/.test(html), name);
  }
  // Existing API names and semantic names resolve to exactly the same SVG.
  for (const [legacy, semantic] of Object.entries({ grid: 'apps', capsule: 'capsule', hospital: 'hospital', people: 'users', 'chat-dots': 'chat', 'box-seam': 'box', wallet2: 'wallet', 'diagram-3': 'hierarchy', headset: 'headset', gear: 'settings', book: 'book', sliders: 'sliders', 'arrow-counterclockwise': 'reset', 'arrow-clockwise': 'refresh', 'box-arrow-in-down': 'stock-in', 'box-arrow-up': 'stock-out' })) {
    const expected = render(h(Icon, { name: semantic }));
    eq(render(h(Icon, { name: legacy })), expected);
    eq(render(h(Icon, { name: 'bi-' + legacy })), expected);
  }
  const semantics = ['warehouse', 'box', 'hospital', 'users', 'headset', 'hierarchy', 'wallet', 'receipt'];
  eq(new Set(semantics.map(name => render(h(Icon, { name })))).size, semantics.length);
  const filter = render(h(Icon, { name: 'filter' }));
  ok(filter.includes('data-icon="filter"') && filter.includes(paths.filter[0]));
  ok(filter !== render(h(Icon, { name: 'sort' })), 'Filtering and sorting keep distinct pictograms.');
  const action = render(h(Button, { icon: 'download', disabled: true, title: 'Exporter les résultats', 'aria-label': 'Exporter les résultats' }, 'Exporter'));
  ok(action.includes('disabled=""') && action.includes('type="button"'));
  ok(action.includes('aria-label="Exporter les résultats"') && action.endsWith('Exporter</button>'));
  const compact = render(h(Icon, { name: 'menu', size: '1em', className: 'test-icon' }));
  ok(compact.includes('width="1em"') && compact.includes('app-icon test-icon'));
  eq(render(h(Icon, { name: 'nonexistent-icon' })), '');
  // The license is included in Vite's public directory for distribution with the app.
  const license = fs.readFileSync(path.join(front, 'public/licenses/icons8-line-awesome.txt'), 'utf8');
  ok(license.includes('Copyright (c) Icons8') && license.includes('Permission is hereby granted'));
  const sources = JSON.parse(fs.readFileSync(path.join(front, 'src/components/icons8/sources.json'), 'utf8'));
  eq(Object.keys(sources.icons).sort(), Object.keys(paths).sort());
  ok(Object.values(sources.icons).every(source => /^svg\/[a-z0-9-]+\.svg$/.test(source.file) && /^[a-f0-9]{64}$/.test(source.sha256)));
  console.log(`Icons8 shared rendering: ${checks} checks passed (${Object.keys(paths).length} pictograms).`);
})().catch(error => { console.error(error); process.exitCode = 1; });
