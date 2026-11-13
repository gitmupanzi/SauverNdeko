const assert = require("node:assert/strict");
const path = require("node:path");
const {buildSync} = require("esbuild");

const {outputFiles} = buildSync({
  stdin: {
    contents: [
      "export * from './src/utils/categoricalValues';",
      "export * from './src/utils/stockDocumentTypes';",
      "export * from './src/pages/logistique/bonComposerForm';",
      "export * from './src/pages/logistique/lineForm';",
    ].join("\n"),
    resolveDir: path.resolve(__dirname, "../.."),
  },
  bundle: true,
  write: false,
  platform: "node",
  format: "cjs",
  logLevel: "silent",
});
const subject = {exports: {}};
new Function("module", outputFiles[0].text)(subject);
const {
  sameCategory,
  stockDocumentKind,
  cataloguePrice,
  compositionCatalogueParams,
  compositionDirection,
  compositionLine,
  compositionLineErrors,
  lineForm,
  linePrice,
  lineErrors,
  closedBon,
  canCreateStockInvoice,
} = subject.exports;

assert.equal(sameCategory("Sortie", "SORTIE"), true);
assert.equal(sameCategory("Périmé", "PE\u0301RIME\u0301"), true);
assert.equal(sameCategory("Périmé", "PERIME"), false);

const article = {ID_Article: 4, ID_DeviseFk: 2, PUArticle: "6.00", PVArticle: "12.00", QteArticle: "3"};
const values = {ID_TypeCmdFk: "7", ID_DeviseFk: "2"};
for (const label of ["Sortie", "sortie", "SORTIE"]) {
  const option = Object.freeze({id: 7, abbr: label});
  const references = {commandeTypes: [option]};
  const bon = {NatureBon: label, ID_DeviseFk: 2};
  assert.equal(stockDocumentKind({kind: label}), "sortie");
  assert.equal(stockDocumentKind(option), "sortie");
  assert.equal(stockDocumentKind(bon), "sortie");
  assert.equal(canCreateStockInvoice(bon), true);
  const params = compositionCatalogueParams({
    query: "Article test", grid: {take: 10, skip: 0}, depotId: "5",
    outgoing: compositionDirection(option) === "sortie",
  });
  assert.equal(params.get("depotId"), "5");
  assert.deepEqual(JSON.parse(params.get("columnFilters")), {QteArticle: ">0"});
  assert.equal(cataloguePrice(article, values, references), "12.00");
  assert.equal(linePrice(article, bon), "12.00");
  assert.equal(linePrice({...article, ID_DeviseFk: 99}, bon), "");

  const line = compositionLine(article, values, references);
  assert.deepEqual(compositionLineErrors(line, stockDocumentKind(option)), {});
  const excessive = {...line, QteCmdDetail: "4"};
  assert.match(compositionLineErrors(excessive, stockDocumentKind(option)).QteCmdDetail, /stock disponible/);
  const editValues = {...lineForm(), ID_CmdFk: "1", ID_ArticleFk: "4", QteCmdDetail: "4", PUCmdDetail: "12.00"};
  assert.match(lineErrors(editValues, bon, article).QteCmdDetail, /stock disponible/);
  assert.deepEqual(lineErrors(editValues, bon, article, {QteCmdDetail: "1"}), {});
  assert.equal(option.abbr, label);
}
assert.equal(stockDocumentKind({AbrGenerique: "BS"}), "sortie");
assert.equal(stockDocumentKind({NatureBon: " ENTRÉE "}), "entree");
assert.equal(stockDocumentKind({abbr: "cmd", sign: 0}), "commande");
assert.equal(stockDocumentKind({sign: 0}), "");
for (const type of [{abbr: "CMD"}, {abbr: "ENTRÉE"}]) {
  const params = compositionCatalogueParams({
    query: "", grid: {}, depotId: "5", outgoing: compositionDirection(type) === "sortie",
  });
  assert.equal(params.has("columnFilters"), false);
}
assert.equal(stockDocumentKind({abbr: "Sôrtie"}), "");
assert.equal(cataloguePrice(article, values, {commandeTypes: [{id: 7, abbr: "ENTRÉE"}]}), "6.00");
assert.equal(cataloguePrice(article, values, {commandeTypes: [{id: 7, abbr: "CMD"}]}), "");
assert.equal(closedBon({StatusFacture: "CLÔTURÉE"}), true);
assert.equal(closedBon({StatusFacture: "cloturee"}), true);

console.log("Comparaisons catégorielles et règles des bons vérifiées.");
