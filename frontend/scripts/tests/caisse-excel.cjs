// Vrais handlers du panier et cellules SearchSelect ; transport et DOM simulés, sans écriture métier.
const path = require('node:path'), Module = require('node:module'), assert = require('node:assert/strict');
const front = path.resolve(__dirname, '../..'), esbuild = require(path.join(front, 'node_modules/esbuild'));
let checks = 0;
const eq = (actual, expected) => {assert.deepEqual(actual, expected); checks++;};
const ok = value => {assert(value); checks++;};
const rejects = (fn, pattern) => {assert.throws(fn, pattern); checks++;};
const tick = () => new Promise(resolve => setImmediate(resolve));
async function bundle(contents, entries = []) {
  const result = await esbuild.build({stdin:{contents, resolveDir:front, loader:'jsx'}, bundle:true, jsx:'automatic',
    external:['react/jsx-runtime'], platform:'node', format:'cjs', write:false, loader:{'.css':'empty'}, logLevel:'error',
    plugins:[{name:'fixtures', setup(build) {for (const [filter, name, source] of entries) {
      build.onResolve({filter}, () => ({path:name, namespace:name}));
      build.onLoad({filter:/.*/, namespace:name}, () => ({contents:source, loader:'jsx', resolveDir:front}));
    }}}]});
  const compiled = new Module(path.join(front, 'caisse-excel-proof.cjs'), module);
  compiled.filename = path.join(front, 'caisse-excel-proof.cjs');
  compiled.paths = Module._nodeModulePaths(front);
  compiled._compile(result.outputFiles[0].text, compiled.filename);
  return compiled.exports;
}
class Hooks {
  constructor() {this.slots = []; this.cursor = 0; this.effects = []; this.updates = 0;}
  state(initial) {const index = this.cursor++;
    if (!this.slots[index]) this.slots[index] = {value:typeof initial === 'function' ? initial() : initial};
    return [this.slots[index].value, next => {this.updates++; this.slots[index].value = typeof next === 'function' ? next(this.slots[index].value) : next;}];
  }
  ref(initial) {const index = this.cursor++; return this.slots[index] ||= {current:initial};}
  effect(fn, deps = []) {const index = this.cursor++, old = this.slots[index];
    if (!old || old.deps.length !== deps.length || deps.some((value, position) => !Object.is(value, old.deps[position]))) {
      this.effects.push(() => {old?.clean?.(); this.slots[index] = {deps, clean:fn()};});
    }
  }
  render(component, props) {this.cursor = 0; globalThis.__hooks = this; return component(props);}
  flush() {this.effects.splice(0).forEach(fn => fn());}
  unmount() {this.slots.forEach(slot => slot?.clean?.());}
}
function nodes(node, result = []) {
  if (!node || typeof node !== 'object') return result;
  if (Array.isArray(node)) {node.forEach(child => nodes(child, result)); return result;}
  if (node.type) result.push(node);
  nodes(node.props?.children, result);
  return result;
}
const named = (tree, name) => nodes(tree).find(node => node.type?.name === name);
function content(node) {return Array.isArray(node) ? node.map(content).join('') : node && typeof node === 'object' ? content(node.props?.children) : node ?? '';}
const button = (tree, label) => nodes(tree).find(node => node.type?.name === 'Button' && content(node) === label);
const headers = ['Caisse', 'Devise', 'Type de caisse', 'Responsable', 'Active', 'Motif'];
const cells = [headers, ['Caisse du site', 'USD', 'ESPECES', 'Utilisateur habilité', 'Non', 'Ouverture']];
const references = {devises:[{id:'451', abbr:'USD', label:'Dollar'}], typesCaisses:[{id:'800', abbr:'ESPECES', label:'Espèces'}],
  responsables:[{id:'9007199254740993', label:'Utilisateur habilité'}], caisses:[], typesPaiements:[], tiers:[]};
const scope = {scopeKey:'compte:2:entreprise:7', entityId:'7'};
const user = {IdUser:2, permissions:{canWriteData:true}};
const context = {canManage:true, readOnly:false};
const entries = [
  [/^react$/, 'hooks', `export const useState=v=>globalThis.__hooks.state(v),useRef=v=>globalThis.__hooks.ref(v),useId=()=>"excel-"+globalThis.__hooks.cursor++,useEffect=(f,d)=>globalThis.__hooks.effect(f,d);`],
  [/\/contexts\/AuthContext$/, 'auth', `export const useAuth=()=>({user:globalThis.__user});`],
  [/\/contexts\/EntityScopeContext$/, 'scope', `export const useEntityScope=()=>globalThis.__scope;`],
  [/\/services\/api$/, 'api', `export const requestJson=(path,options)=>globalThis.__request(path,options),downloadApiFile=(path,options)=>globalThis.__download(path,options);`],
  [/\/components\/RecordEditorFrame$/, 'frame', `export default function Frame(){}`],
  [/\/components\/ActionButton$/, 'button', `export default function Button(){}`],
  [/\/components\/SearchSelect$/, 'select', `export default function Select(){}`],
  [/\/components\/AppIcon$/, 'icon', `export default function Icon(){}`],
  [/\/logistique\/logistiqueShared$/, 'table', `export function SimpleTable(){}`],
];
globalThis.document = {getElementById:id => ({focus(){globalThis.__focused = id;}, scrollIntoView(){}})};
globalThis.requestAnimationFrame = fn => {fn(); return 1;};
function deferred() {let resolve, reject; const promise = new Promise((yes, no) => {resolve = yes; reject = no;}); return {promise, resolve, reject};}
function fileEvent(file = new Blob(['xlsx'])) {
  if (!file.name) Object.defineProperty(file, 'name', {value:'caisses.xlsx'});
  return {currentTarget:{files:[file], value:'C:\\fakepath\\'+file.name}};
}
(async () => {
  const domain = await bundle("export * from './src/pages/caisse/caisseBatch';");
  let imported = domain.caisseBatchFromMatrix('caisses', cells, references);
  eq(imported.length, 1);
  eq(imported[0].values, {NomCaisse:'Caisse du site', IdDeviseFk:'451', IdTypeCaisseFk:'800', IdResponsableFk:'9007199254740993', Actif:false, motif:'Ouverture'});
  eq(imported[0].pristine, false);
  eq(domain.caisseBatchErrors('caisses', imported, references), {});
  imported = domain.caisseBatchFromMatrix('caisses', [headers, ['Caisse active', '451', '', '', '', '']], references);
  eq(imported[0].values.Actif, true);
  eq(imported[0].values.IdTypeCaisseFk, '');
  const pasted = domain.caisseBatchPaste('caisses', 'Nom de la caisse\tDevise\tÉtat\n"Caisse\nmultiligne"\tUSD\tInactive', references);
  eq(pasted[0].values.NomCaisse, 'Caisse\nmultiligne'); eq(pasted[0].values.Actif, false);
  for (const invalid of [undefined, {}, [['Caisse'], [true]], [['Caisse'], [23]]]) rejects(() => domain.caisseBatchFromMatrix('caisses', invalid, references), /contenu du fichier/);
  rejects(() => domain.caisseBatchFromMatrix('caisses', [['Caisse', 'NomCaisse'], ['A', 'B']], references), /en-têtes en double/);
  rejects(() => domain.caisseBatchFromMatrix('caisses', [['Colonne inconnue'], ['A']], references), /noms des colonnes/);
  rejects(() => domain.caisseBatchFromMatrix('caisses', [['constructor'], ['A']], references), /noms des colonnes/);
  rejects(() => domain.caisseBatchFromMatrix('caisses', [headers], references), /au moins une ligne/);
  rejects(() => domain.caisseBatchFromMatrix('caisses', [headers, ...Array.from({length:101}, () => cells[1])], references), /100 lignes/);
  eq(domain.caisseBatchFromMatrix('caisses', [headers, ...Array.from({length:100}, () => cells[1])], references).length, 100);
  const component = (await bundle("export {default} from './src/pages/caisse/CaisseBatchEditor';", entries)).default;
  let requests = [], downloads = [], saved = [];
  function reset() {
    globalThis.__scope = {...scope}; globalThis.__user = {...user};
    requests = []; downloads = []; saved = []; globalThis.__focused = '';
    globalThis.__request = async (path, options) => {requests.push({path, options}); return {success:true, data:{cells}};};
    globalThis.__download = async (path, options) => {downloads.push({path, options}); return {filename:'modele-import-caisses.xlsx'};};
  }
  function mount(kind = 'caisses', overrides = {}) {
    const hooks = new Hooks(), props = {kind, references, context, onClose(){}, onSaved:result => saved.push(result), ...overrides};
    const render = () => hooks.render(component, props);
    const tree = render(); hooks.flush();
    return {hooks, props, render, tree, table:() => named(render(), 'SimpleTable'), frame:() => named(render(), 'Frame'),
      input:() => nodes(render()).find(node => node.type === 'input' && node.props.type === 'file'),
      import:file => nodes(render()).find(node => node.type === 'input' && node.props.type === 'file').props.onChange(fileEvent(file))};
  }
  function setField(view, field, value, index = 0) {
    const table = view.table(), row = table.props.rows[index], cell = table.props.columns.find(column => column.key === field).render(row);
    const input = nodes(cell).find(node => node.type === 'input'), select = named(cell, 'Select');
    if (input) input.props.onChange({target:{value}}); else select.props.onChange(value);
  }
  reset(); let view = mount();
  ok(button(view.tree, 'Télécharger le modèle Excel')); ok(button(view.tree, 'Importer un fichier Excel'));
  eq(view.input().props.accept, '.xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  eq(view.input().props.hidden, true); ok(button(view.tree, 'Importer un fichier Excel').props['aria-describedby']);
  await button(view.render(), 'Télécharger le modèle Excel').props.onClick();
  eq(downloads.length, 1); eq(downloads[0].path, '/api/caisse/caisses/modele-excel');
  eq(downloads[0].options.filename, 'modele-import-caisses.xlsx'); ok(downloads[0].options.signal instanceof AbortSignal);
  ok(nodes(view.render()).some(node => node.props?.role === 'status' && content(node).includes('Modèle Excel téléchargé')));
  const event = fileEvent(); await view.input().props.onChange(event);
  eq(event.currentTarget.value, ''); eq(requests.length, 1); eq(requests[0].path, '/api/caisse/caisses/import-excel');
  eq(requests[0].options.method, 'POST'); eq(requests[0].options.requiresAuth, true);
  ok(requests[0].options.body instanceof FormData); eq([...requests[0].options.body.keys()], ['fichier']);
  eq(saved.length, 0); eq(view.table().props.rows.length, 1); eq(view.table().props.rows[0].values.Actif, false);
  const selected = named(view.table().props.columns.find(column => column.key === 'IdResponsableFk').render(view.table().props.rows[0]), 'Select');
  eq(selected.props.value, '9007199254740993'); eq(selected.props.options.find(option => option.value === selected.props.value).label, 'Utilisateur habilité');
  ok(nodes(view.render()).some(node => node.props?.role === 'status' && content(node).includes('1 ligne ajoutée au panier.')));
  globalThis.__request = async (path, options) => {requests.push({path, options}); const payload = JSON.parse(options.body);
    return {success:true, data:{requestId:payload.requestId, count:payload.rows.length, records:payload.rows.map(row => ({clientRowId:row.clientRowId, id:17}))}};};
  await view.frame().props.onSubmit();
  eq(requests.length, 2); eq(requests[1].path, '/api/caisse/caisses'); eq(saved.length, 1);
  eq(JSON.parse(requests[1].options.body).rows[0].data.IdResponsableFk, '9007199254740993'); view.hooks.unmount();

  // Ajout aux lignes déjà préparées ; valeurs invalides corrigeables dans le panier sans sauvegarde.
  reset(); view = mount(); setField(view, 'NomCaisse', 'Saisie conservée');
  globalThis.__request = async (path, options) => {requests.push({path, options}); return {success:true, data:{cells:[headers, ['Nouvelle caisse', 'INCONNUE', '', '', 'Oui', '']]}};};
  await view.import(); eq(view.table().props.rows.length, 2); eq(view.table().props.rows[0].values.NomCaisse, 'Saisie conservée');
  const invalidRow = view.table().props.rows[1], invalidSelect = named(view.table().props.columns.find(column => column.key === 'IdDeviseFk').render(invalidRow), 'Select');
  eq(invalidSelect.props.invalid, true); eq(invalidSelect.props.value, 'INCONNUE');
  ok(invalidSelect.props.options.find(option => option.value === 'INCONNUE').disabled);
  ok(globalThis.__focused.endsWith(invalidRow.clientRowId+'IdDeviseFk'));
  await view.frame().props.onSubmit(); eq(requests.length, 1); eq(saved.length, 0);
  setField(view, 'IdDeviseFk', '451', 1); eq(named(view.table().props.columns.find(column => column.key === 'IdDeviseFk').render(view.table().props.rows[1]), 'Select').props.invalid, false);
  view.hooks.unmount();

  // Échecs de fichier, de réponse et de capacité : aucune ligne préparée n’est retirée.
  reset(); view = mount(); setField(view, 'NomCaisse', 'Saisie à préserver');
  for (const invalid of [{name:'caisses.xls', size:100}, {name:'caisses.xlsx', size:0}, {name:'caisses.xlsx', size:4*1024*1024+1}]) {
    await view.import(invalid); eq(requests.length, 0); eq(view.table().props.rows[0].values.NomCaisse, 'Saisie à préserver');
    ok(nodes(view.render()).some(node => node.props?.role === 'alert' && content(node).includes('4 Mo maximum')));
  }
  for (const response of [{success:false, status:422, message:'Classeur non reconnu'}, {success:false, status:413},
    {success:true, data:{cells:[headers, ['Nom', 451]]}}, {success:true, data:{cells:[headers]}},
    {success:true, data:{cells:[headers, ...Array.from({length:100}, () => cells[1])]}}]) {
    globalThis.__request = async () => response;
    await view.import(); eq(view.table().props.rows.length, 1); eq(view.table().props.rows[0].values.NomCaisse, 'Saisie à préserver');
    ok(nodes(view.render()).some(node => node.props?.role === 'alert'));
    eq(view.frame().props.canSubmit, true);
  }
  globalThis.__request = async () => {throw new Error('Réseau interrompu');};
  await view.import(); ok(nodes(view.render()).some(node => node.props?.role === 'alert' && content(node).includes('Réseau interrompu')));
  view.hooks.unmount();

  // La lecture fige les modifications et la sauvegarde, même avant le prochain rendu.
  reset(); view = mount(); setField(view, 'NomCaisse', 'Avant lecture');
  const pending = deferred(); globalThis.__request = (path, options) => {requests.push({path, options}); return pending.promise;};
  const staleFrame = view.frame(), staleTable = view.table(), staleInput = nodes(staleTable.props.columns.find(column => column.key === 'NomCaisse').render(staleTable.props.rows[0])).find(node => node.type === 'input');
  const reading = view.import(); await staleFrame.props.onSubmit(); eq(requests.length, 1);
  staleInput.props.onChange({target:{value:'Mutation rejetée'}}); eq(view.table().props.rows[0].values.NomCaisse, 'Avant lecture');
  eq(view.frame().props.canSubmit, false); eq(button(view.render(), 'Ajouter une ligne').props.disabled, true);
  eq(button(view.render(), 'Télécharger le modèle Excel').props.disabled, true);
  await view.import(); eq(requests.length, 1);
  pending.resolve({success:true, data:{cells}}); await reading; eq(view.table().props.rows.length, 2);
  eq(view.frame().props.canSubmit, true); view.hooks.unmount();

  // Le téléchargement est relançable après erreur, et les doubles clics partagent la demande.
  reset(); view = mount(); const downloading = deferred();
  globalThis.__download = (path, options) => {downloads.push({path, options}); return downloading.promise;};
  const downloadButton = button(view.render(), 'Télécharger le modèle Excel');
  const firstDownload = downloadButton.props.onClick(); await downloadButton.props.onClick(); eq(downloads.length, 1);
  downloading.reject(new Error('Modèle indisponible')); await firstDownload;
  ok(nodes(view.render()).some(node => node.props?.role === 'alert' && content(node).includes('Modèle indisponible')));
  eq(button(view.render(), 'Télécharger le modèle Excel').props.disabled, false); view.hooks.unmount();

  // Changement de compte/entreprise, retrait des droits ou fermeture : réponses tardives ignorées.
  for (const operation of ['import', 'download']) for (const change of ['scope', 'account', 'permissions', 'unmount']) {
    reset(); view = mount(); const delayed = deferred(); let signal;
    const handler = (path, options) => {signal = options.signal; return delayed.promise;};
    globalThis.__request = handler; globalThis.__download = handler;
    const started = operation === 'import' ? view.import() : button(view.render(), 'Télécharger le modèle Excel').props.onClick();
    if (change === 'unmount') view.hooks.unmount();
    else {
      if (change === 'scope') globalThis.__scope = {scopeKey:'entreprise:8', entityId:'8'};
      if (change === 'account') globalThis.__user = {...user, IdUser:99};
      if (change === 'permissions') globalThis.__user = {...user, permissions:{canWriteData:false}};
      view.render(); view.hooks.flush();
    }
    eq(signal.aborted, true); const updates = view.hooks.updates;
    delayed.resolve({success:true, data:{cells}}); await started; await tick();
    eq(view.hooks.updates, updates); eq(saved.length, 0);
    if (change !== 'unmount') {eq(view.table().props.rows.length, 1); eq(view.frame().props.readOnly, true); view.hooks.unmount();}
  }

  reset(); view = mount();
  globalThis.__request = async () => ({success:true, data:{cells:[headers, ...Array.from({length:100}, () => cells[1])]}});
  await view.import(); eq(view.table().props.rows.length, 100); eq(view.input().props.disabled, true);
  eq(button(view.render(), 'Importer un fichier Excel').props.disabled, true); view.hooks.unmount();
  reset(); view = mount(); setField(view, 'NomCaisse', 'Demande incertaine');
  globalThis.__request = async () => ({success:false, status:503}); await view.frame().props.onSubmit();
  eq(button(view.render(), 'Importer un fichier Excel').props.disabled, true);
  eq(button(view.render(), 'Télécharger le modèle Excel').props.disabled, true);
  eq(view.frame().props.submitLabel, 'Vérifier l’enregistrement'); view.hooks.unmount();
  // Un retrait temporaire des droits pendant l’écriture conserve le ticket et permet sa vérification au retour.
  for (const reply of ['unavailable', 'success']) {
    reset(); view = mount(); setField(view, 'NomCaisse', 'Droits momentanément retirés');
    const delayedSave = deferred();
    globalThis.__request = (path, options) => {requests.push({path, options}); return delayedSave.promise;};
    const saving = view.frame().props.onSubmit();
    const originalBody = requests[0].options.body, payload = JSON.parse(originalBody);
    const receipt = {success:true, data:{requestId:payload.requestId, count:payload.rows.length, records:payload.rows.map(row => ({clientRowId:row.clientRowId, id:91}))}};
    globalThis.__user = {...user, permissions:{canWriteData:false}}; view.render(); view.hooks.flush();
    delayedSave.resolve(reply === 'success' ? receipt : {success:false, status:503}); await saving;
    eq(view.frame().props.busy, false); eq(view.frame().props.readOnly, true); eq(saved.length, 0);
    globalThis.__user = {...user}; view.render(); view.hooks.flush();
    eq(view.frame().props.readOnly, false); eq(view.frame().props.submitLabel, 'Vérifier l’enregistrement');
    eq(button(view.render(), 'Importer un fichier Excel').props.disabled, true);
    globalThis.__request = async (path, options) => {requests.push({path, options}); return receipt;};
    await view.frame().props.onSubmit(); eq(requests.length, 2); eq(requests[1].options.body, originalBody);
    eq(saved.length, 1); view.hooks.unmount();
  }
  // Écritures et clôtures utilisent les mêmes contrôles, avec un modèle propre au registre.
  const journalReferences = {...references, caisses:[{IdCaisse:'31', CodeCaisse:'CAI-31', NomCaisse:'Site', DeviseCode:'USD', Actif:true, SoldeTheorique:'120.00', _version:'8'}],
    typesPaiements:[{id:'81', abbr:'VIR', label:'Virement complet'}]};
  const journalCells = {
    ecritures:[['IdCaisseFk','DatePaiement','SensMouvement','LibellePaiement','MontantPaiement','IdTypePaiementFk'],
      ['CAI-31','07/11/2026 14:05:03','Encaissement','Recette','20,00','VIR']],
    clotures:[['IdCaisseFk','ClotureLe','MontantCompte','motif'], ['CAI-31','2026-11-07T15:00:03','0','Comptage justifié']],
  };
  for (const kind of ['ecritures', 'clotures']) {
    reset(); view = mount(kind, {references:journalReferences});
    ok(view.input()); ok(button(view.render(), 'Télécharger le modèle Excel')); ok(button(view.render(), 'Importer un fichier Excel'));
    await button(view.render(), 'Télécharger le modèle Excel').props.onClick();
    eq(downloads[0].path, '/api/caisse/'+kind+'/modele-excel'); eq(downloads[0].options.filename, 'modele-import-'+kind+'.xlsx');
    globalThis.__request = async (path, options) => {requests.push({path, options}); return {success:true, data:{cells:journalCells[kind]}};};
    await view.import(); eq(requests[0].path, '/api/caisse/'+kind+'/import-excel'); eq(saved.length, 0);
    const row = view.table().props.rows[0]; eq(row.values.IdCaisseFk, '31');
    eq(row.values[kind === 'clotures' ? 'ClotureLe' : 'DatePaiement'], kind === 'clotures' ? '2026-11-07T15:00:03' : '2026-11-07T14:05:03');
    eq(domain.caisseBatchErrors(kind, [row], journalReferences), {});
    if (kind === 'clotures') {
      eq(row.values.MontantCompte, '0'); eq(row.balance.version, '8'); eq(row.balance.record.SoldeTheorique, '120.00');
      await view.frame().props.onSubmit(); eq(requests.length, 1); eq(saved.length, 0);
      ok(view.frame().props.error.includes('Confirmez'));
      nodes(view.render()).find(node => node.type === 'input' && node.props.id?.endsWith('confirm')).props.onChange({target:{checked:true}});
    } else {
      eq(row.values.SensMouvement, '1'); eq(row.values.IdTypePaiementFk, '81');
      eq(nodes(view.render()).find(node => node.type === 'input' && node.props.type === 'checkbox').props.checked, false);
    }
    globalThis.__request = async (path, options) => {requests.push({path, options}); const payload = JSON.parse(options.body);
      return {success:true, data:{requestId:payload.requestId, count:payload.rows.length, records:payload.rows.map(item => ({clientRowId:item.clientRowId, id:77}))}};};
    await view.frame().props.onSubmit(); eq(saved.length, 1); eq(requests.length, 2);
    const payload = JSON.parse(requests[1].options.body); eq(payload.rows[0].data.IdCaisseFk, '31');
    eq(payload.rows[0].data[kind === 'clotures' ? 'ClotureLe' : 'DatePaiement'], row.values[kind === 'clotures' ? 'ClotureLe' : 'DatePaiement']+'+01:00');
    if (kind === 'clotures') eq(payload.rows[0]._version, '8'); else {eq(payload.valider, false); eq(payload.rows[0].data.MontantPaiement, '20.00');}
    view.hooks.unmount();
  }
  // Les dates importées invalides restent visibles et corrigeables ; ni code ni validation ne viennent du fichier.
  reset(); view = mount('ecritures', {references:journalReferences});
  const incorrect = [journalCells.ecritures[0], ['31','31/02/2026 14:00','inconnu','Libellé','20,001','VIR']];
  globalThis.__request = async (path, options) => {requests.push({path, options}); return {success:true, data:{cells:incorrect}};};
  await view.import();
  let invalidEntry = view.table().props.rows[0];
  const dateCell = () => view.table().props.columns.find(column => column.key === 'DatePaiement').render(view.table().props.rows[0]);
  eq(nodes(dateCell()).find(node => node.type === 'input').props.type, 'text');
  eq(nodes(dateCell()).find(node => node.type === 'input').props.value, '2026-02-31T14:00');
  eq(nodes(dateCell()).find(node => node.type === 'input').props['aria-invalid'], true);
  await view.frame().props.onSubmit(); eq(requests.length, 1); eq(saved.length, 0);
  setField(view, 'DatePaiement', '2026-11-07T14:00'); setField(view, 'SensMouvement', '-1'); setField(view, 'MontantPaiement', '20.00');
  eq(domain.caisseBatchErrors('ecritures', view.table().props.rows, journalReferences), {});
  eq(nodes(dateCell()).find(node => node.type === 'input').props.type, 'datetime-local'); view.hooks.unmount();
  for (const kind of ['ecritures','clotures']) for (const field of ['_version','SoldeTheorique','CodeCaisse','valider','IdEntiteFk']) {
    rejects(() => domain.caisseBatchFromMatrix(kind, [[...journalCells[kind][0], field], [...journalCells[kind][1], '999']], journalReferences), /noms des colonnes/);
  }
  for (const kind of ['ecritures','clotures']) {
    const date = kind === 'clotures' ? 'ClotureLe' : 'DatePaiement';
    const matrix = [['IdCaisseFk'], ['31']];
    eq(domain.caisseBatchFromMatrix(kind, matrix, journalReferences)[0].values[date], '');
  }
  const repeatedClose = domain.caisseBatchFromMatrix('clotures', [...journalCells.clotures, journalCells.clotures[1]], journalReferences);
  const repeatedIssues = domain.caisseBatchErrors('clotures', repeatedClose, journalReferences);
  ok(repeatedIssues[repeatedClose[0].clientRowId].IdCaisseFk); ok(repeatedIssues[repeatedClose[1].clientRowId].IdCaisseFk);
  // Un rechargement de solde ne peut réécrire une autre caisse ni une autre entreprise.
  for (const change of ['scope','account','permissions','unmount','cash']) {
    reset(); view = mount('clotures', {references:journalReferences});
    setField(view, 'IdCaisseFk', '31');
    const row = view.table().props.rows[0], delayed = deferred(); let signal;
    globalThis.__request = (path, options) => {signal=options.signal; return delayed.promise;};
    const reload = nodes(view.table().props.columns.find(column => column.key === 'balance').render(row)).find(node => node.type?.name === 'Button').props.onClick();
    if (change === 'unmount') view.hooks.unmount();
    else {
      if (change === 'scope') globalThis.__scope = {scopeKey:'autre',entityId:'10'};
      if (change === 'account') globalThis.__user = {...user, IdUser:99};
      if (change === 'permissions') globalThis.__user = {...user,permissions:{canWriteData:false}};
      if (change === 'cash') setField(view, 'IdCaisseFk', '');
      view.render(); view.hooks.flush();
    }
    eq(signal.aborted, true); const updates = view.hooks.updates;
    delayed.resolve({success:true,data:{canManage:true, record:{IdCaisse:'31',Actif:true,SoldeTheorique:'999'},_version:'999'}});
    await reload; eq(view.hooks.updates, updates); if (change !== 'unmount') view.hooks.unmount();
  }
  console.log(JSON.stringify({success:true, checks, coverage:['Modèle authentifié, import multipart et matrice Excel', 'Saisie et références conservées, validation des champs et sauvegarde atomique existante', 'Limites 4 Mo/100 lignes, fichiers et réponses invalides', 'Gel pendant lecture et réponse incertaine, doubles clics', 'Annulation et réponses tardives après changement de contexte ou fermeture'], limits:['Transport et DOM simulés ; aucun enregistrement métier réel']}));
})().catch(error => {console.error(error); process.exitCode = 1;});
