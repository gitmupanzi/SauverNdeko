// Cycle React réel, requête HTTP simulée ; aucune ouverture d'annuaire ni écriture.
// NODE_PATH=frontend/node_modules node catalogue-metrics.cjs /chemin/react-test-renderer/index.js
const path = require('node:path'), Module = require('node:module'), assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../..'), front = path.join(root, 'frontend');
const React = require(path.join(front, 'node_modules/react')), esbuild = require(path.join(front, 'node_modules/esbuild'));
const rendererPath = process.argv[2];
if (!rendererPath) throw Error('Indiquez le react-test-renderer correspondant à la version de React.');
const Renderer = require(path.resolve(rendererPath)), { act } = React;
let checks = 0;
const eq = (actual, expected) => { assert.deepEqual(actual, expected); checks++; };
const ok = (value, message) => { assert(value, message); checks++; };
globalThis.IS_REACT_ACT_ENVIRONMENT = true;
const originalError = console.error;
console.error = (...args) => { if (!String(args[0]).includes('react-test-renderer is deprecated')) originalError(...args); };
const timers = new Map(), nativeTimeout = globalThis.setTimeout, nativeClear = globalThis.clearTimeout;
let sequence = 0;
globalThis.setTimeout = (fn, delay, ...args) => {
  if (delay !== 12000) return nativeTimeout(fn, delay, ...args);
  const id = `summary-${++sequence}`;
  timers.set(id, () => { timers.delete(id); fn(...args); });
  return id;
};
globalThis.clearTimeout = id => { if (!timers.delete(id)) nativeClear(id); };
async function bundle() {
  const entries = [
    [/^react-router-dom$/, 'router', 'export function Link({to,...props}) { return <a href={to} {...props}/>; }'],
    [/\/services\/api$/, 'api', 'export const requestJson=(...args)=>globalThis.__request(...args);'],
  ];
  const built = await esbuild.build({ stdin: { contents: "export {default as Metrics} from './src/components/CatalogueMetrics';export * from './src/services/catalogueSummary';", loader: 'jsx', resolveDir: front }, bundle: true, platform: 'node', format: 'cjs', jsx: 'automatic', write: false, external: ['react', 'react/jsx-runtime'], loader: { '.css': 'empty' }, plugins: [{ name: 'fixtures', setup(build) { for (const [filter, name, source] of entries) { build.onResolve({filter}, () => ({path: name, namespace: name})); build.onLoad({filter: /.*/, namespace: name}, () => ({contents: source, loader: 'jsx', resolveDir: front})); } } }], logLevel: 'error' });
  const compiled = new Module(path.join(front, 'catalogue-metrics-proof.cjs'));
  compiled.filename = path.join(front, 'catalogue-metrics-proof.cjs');
  compiled.paths = Module._nodeModulePaths(front);
  compiled._compile(built.outputFiles[0].text, compiled.filename);
  return compiled.exports;
}
function text(node) { if (node == null) return ''; if (typeof node === 'string' || typeof node === 'number') return String(node); if (Array.isArray(node)) return node.map(text).join(' '); return text(node.children); }
const valid = { success: true, data: { productsCount: 12345, expertsCount: 0, structuresCount: 521, calculatedAt: '2026-11-07T12:00:00+00:00' } };
(async () => {
  const { Metrics, normalizeCatalogueSummary, formatCatalogueCount } = await bundle();
  eq(formatCatalogueCount(0), '0'); eq(formatCatalogueCount(12345), new Intl.NumberFormat('fr-FR').format(12345));
  for (const value of [undefined, null, true, -1, '12', Infinity]) eq(formatCatalogueCount(value), '—');
  eq(normalizeCatalogueSummary({...valid, data: {...valid.data, privateNote: 'never show'}}), valid.data);
  for (const payload of [null, {}, {success: false, data: valid.data}, {...valid, data: {...valid.data, expertsCount: null}}, {...valid, data: {...valid.data, structuresCount: -1}}, {...valid, data: {...valid.data, productsCount: true}}, {...valid, data: {...valid.data, productsCount: '12'}}, {...valid, data: {...valid.data, calculatedAt: 'invalid'}}]) eq(normalizeCatalogueSummary(payload), null);

  const calls = [];
  globalThis.__request = (url, options) => new Promise(resolve => calls.push({ url, options, resolve }));
  const anonymous = path => '/login?redirect=' + encodeURIComponent(path), signed = path => path;
  let component;
  await act(async () => { component = Renderer.create(React.createElement(Metrics, {destination: anonymous})); });
  eq(calls.length, 1); eq(calls[0].url, '/api/public/catalogue/synthese');
  eq(calls[0].options.requiresAuth, undefined); eq(calls[0].options.body, undefined);
  eq(component.root.findByProps({className: 'catalogue-metric-grid'}).props['aria-busy'], true);
  eq(component.root.findAllByProps({className: 'catalogue-metric-skeleton'}).length, 3);
  eq(component.root.findAllByProps({className: 'catalogue-metric-value'}).length, 0);
  eq(component.root.findAllByType('a').map(a => a.props.href), ['/produits', '/experts', '/pharmacies'].map(anonymous));
  await act(async () => calls[0].resolve(valid));
  eq(timers.size, 0);
  eq(component.root.findAllByProps({className: 'catalogue-metric-value'}).map(node => text(node.toJSON?.() || {children: node.children})), [formatCatalogueCount(12345), '0', '521']);
  ok(text(component.toJSON()).includes('Les prochains profils publiés apparaîtront ici.'));
  eq(component.root.findByProps({className: 'catalogue-metric-grid'}).props['aria-busy'], false);
  ok(text(component.toJSON()).includes('la disponibilité reste à confirmer'));
  await act(async () => component.update(React.createElement(Metrics, {destination: signed})));
  eq(calls.length, 1); // Changer la session ne déclenche pas de lecture de dossiers privés.
  eq(component.root.findAllByType('a').map(a => a.props.href), ['/produits', '/experts', '/pharmacies']);
  await act(async () => component.unmount());

  await act(async () => { component = Renderer.create(React.createElement(Metrics, {destination: signed})); });
  await act(async () => calls[1].resolve({success: false, message: 'private database detail'}));
  ok(text(component.toJSON()).includes('momentanément indisponibles'));
  ok(!text(component.toJSON()).includes('private database detail'));
  eq(component.root.findAllByProps({className: 'catalogue-metric-value'}).map(node => node.children.join('')), ['—', '—', '—']);
  eq(component.root.findAllByType('a').length, 3);
  await act(async () => component.root.findByType('button').props.onClick());
  eq(calls.length, 3);
  eq(component.root.findAllByProps({className: 'catalogue-metric-skeleton'}).length, 3);
  await act(async () => calls[2].resolve({...valid, data: {...valid.data, productsCount: 0}}));
  ok(text(component.toJSON()).includes('Les prochaines offres apparaîtront ici.'));
  eq(component.root.findAllByType('button').length, 0);
  await act(async () => component.unmount());

  await act(async () => { component = Renderer.create(React.createElement(Metrics, {destination: signed})); });
  await act(async () => { for (const fire of [...timers.values()]) fire(); });
  eq(calls[3].options.signal.aborted, true);
  ok(text(component.toJSON()).includes('momentanément indisponibles'));
  await act(async () => calls[3].resolve(valid));
  ok(!text(component.toJSON()).includes(formatCatalogueCount(12345))); // Réponse après délai ignorée.
  await act(async () => component.root.findByType('button').props.onClick());
  eq(calls.length, 5);
  await act(async () => calls[4].resolve({...valid, data: {...valid.data, expertsCount: null}}));
  ok(text(component.toJSON()).includes('momentanément indisponibles'));
  await act(async () => component.unmount());

  await act(async () => { component = Renderer.create(React.createElement(Metrics, {destination: signed})); });
  await act(async () => component.unmount());
  eq(calls[5].options.signal.aborted, true); eq(timers.size, 0);
  await act(async () => calls[5].resolve(valid));
  console.log(JSON.stringify({success: true, checks, coverage: ['Totaux entiers réels et zéro distinct de l’absence', 'Chargement, panne, nouvelle tentative et réponse incomplète', 'Délai, abandon et réponses tardives', 'Liens anonymes/authentifiés et requête limitée aux agrégats'], limits: ['Cycle React avec réseau simulé ; pas de recette navigateur']}));
})().catch(error => { console.error(error); process.exitCode = 1; });
