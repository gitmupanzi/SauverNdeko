const assert = require('node:assert/strict');
const Module = require('node:module');
const path = require('node:path');
const {buildSync} = require('esbuild');

const frontend = path.resolve(__dirname, '../..');
const result = buildSync({
  stdin: {
    contents: [
      "export * from './src/utils/categoricalValues';",
      "export {referenceDuplicateKey} from './src/pages/referentiels/referenceBatch';",
      "export {caisseBatchFromMatrix} from './src/pages/caisse/caisseBatch';",
      "export {expertExcelRows} from './src/pages/experts/expertBatch';",
      "export {supportExcelRows} from './src/pages/support/supportBatch';",
      "export {SupportStatus, SupportPriority} from './src/pages/support/SupportBadge.jsx';",
      "export {territoryBatchFromMatrix} from './src/pages/territoires/territorialBatch';",
    ].join('\n'),
    resolveDir: frontend,
  },
  bundle: true,
  define: {'import.meta.env': '{}', 'import.meta.hot': 'undefined'},
  external: ['react/jsx-runtime'],
  format: 'cjs',
  jsx: 'automatic',
  platform: 'node',
  write: false,
});
const filename = path.join(frontend, 'categorical-imports-test.cjs');
const compiled = new Module(filename, module);
compiled.filename = filename;
compiled.paths = Module._nodeModulePaths(frontend);
compiled._compile(result.outputFiles[0].text, filename);

const {
  categoricalKey, sameCategory, referenceDuplicateKey, caisseBatchFromMatrix, expertExcelRows,
  supportExcelRows, SupportStatus, SupportPriority, territoryBatchFromMatrix,
} = compiled.exports;

assert.equal(categoricalKey(' SORTIE '), 'sortie');
assert.equal(sameCategory('ÉLEVE\u0301E', 'élevée'), true);
assert.equal(sameCategory('État', 'Etat'), false);
assert.equal(referenceDuplicateKey('Très  élevée'), referenceDuplicateKey(' TRÈS ÉLEVÉE '));
assert.notEqual(referenceDuplicateKey('TRÈS ÉLEVÉE'), referenceDuplicateKey('TRES ELEVEE'));

const cashReferences = {
  caisses: [{IdCaisse: 7, CodeCaisse: 'Caiss-X', NomCaisse: 'Dépôt principal'}],
};
const cashRows = caisseBatchFromMatrix('ecritures', [
  ['Mouvement', 'Caisse', 'Libellé'],
  ['Sortie', 'Caiss-X', 'Sortie à conserver'],
  ['SORTIE', 'caiss-x', 'SORTIE à conserver'],
  ['DÉCAISSEMENT', 'DÉPÔT PRINCIPAL', 'Vérification'],
], cashReferences);
assert.deepEqual(cashRows.map(row => row.values.SensMouvement), ['-1', '-1', '-1']);
assert.deepEqual(cashRows.map(row => row.values.IdCaisseFk), ['7', 'caiss-x', '7']);
assert.equal(cashRows[1].values.LibellePaiement, 'SORTIE à conserver');

const labels = [{id: 4, abbr: 'Élevée'}, {id: 5, abbr: 'Sensible'}, {id: 6, abbr: 'SENSIBLE'}, {id: 7, abbr: '4'}];
const support = supportExcelRows([
  ['ID_PrioriteFk', 'Objet'], ['ÉLEVÉE', 'LIBELLÉ'], ['ELEvee', 'Autre'], ['sensible', 'Autre'], ['4', 'Autre'],
], {references: {priorities: labels}}, () => 'test');
assert.deepEqual(support.map(row => row.data.ID_PrioriteFk), ['4', 'ELEvee', 'sensible', '4']);
assert.equal(support[0].data.Objet, 'LIBELLÉ');
const supportLinks = supportExcelRows([
  ['ID_CommandeFk', 'ID_PrioriteFk', 'ID_ImmobilisationFk'],
  ['CMD-X', 'support.priority.normal', 'IMM-X · Écran'],
  ['cmd-x', 'SUPPORT.PRIORITY.NORMAL', 'imm-x · écran'],
], {
  links: {bons:[{id:12,label:'CMD-X'}], immobilisations:[{id:14,label:'IMM-X · Écran'}]},
  references: {priorities:[{id:13,abbr:'support.priority.normal'}]},
}, () => 'test');
assert.deepEqual(supportLinks.map(row => row.data.ID_CommandeFk), ['12', 'cmd-x']);
assert.deepEqual(supportLinks.map(row => row.data.ID_PrioriteFk), ['13', 'SUPPORT.PRIORITY.NORMAL']);
assert.deepEqual(supportLinks.map(row => row.data.ID_ImmobilisationFk), ['14', '14']);
assert.deepEqual(SupportPriority({value:'ÉLEVÉE'}).props, {value:'ÉLEVÉE', tone:'warning'});
assert.deepEqual(SupportStatus({value:'RÉSOLU'}).props, {value:'RÉSOLU', tone:'success'});
assert.equal(SupportStatus({value:'RÉSOLU', code:'Resolved'}).props.tone, 'neutral');
assert.equal(SupportStatus({value:'Historique', options:[{id:'5', abbr:'support.status.resolved'}], id:'5'}).props.tone, 'success');

const experts = expertExcelRows([
  ['IdSpecialiteFk'], ['ÉLEVÉE'], ['ELEvee'], ['Sensible'], ['4'],
], {specialites: labels}, () => 'test');
assert.deepEqual(experts.map(row => row.values.IdSpecialiteFk), ['4', 'ELEvee', 'Sensible', '4']);

const territories = territoryBatchFromMatrix('niveaux3', [
  ['NomNiveau_3', 'ID_TypeNiveau_2_Fk'],
  ['Libellé conservé', 'ÉLEVÉE'],
  ['Autre', 'ELEvee'],
  ['Autre', 'sensible'],
  ['Autre', '4'],
], {}, {options:{niveau3Types: labels}});
assert.deepEqual(territories.map(row => row.values.ID_TypeNiveau_2_Fk), ['4', 'ELEvee', 'sensible', '4']);
assert.equal(territories[0].values.NomNiveau_3, 'Libellé conservé');

console.log('Comparaison des catégories et imports Excel : OK');
