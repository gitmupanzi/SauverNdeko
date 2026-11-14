const assert = require("node:assert/strict");
const path = require("node:path");
const Module = require("node:module");
const front = path.resolve(__dirname, "../..");
const esbuild = require(path.join(process.env.DATA_SCIENCE_NODE_MODULES || path.join(front, "node_modules"), "esbuild"));

class Hooks {
  slots = [];
  tasks = [];
  cursor = 0;

  state(initial) {
    const index = this.cursor++;
    if (!this.slots[index]) this.slots[index] = { value: typeof initial === "function" ? initial() : initial };
    const slot = this.slots[index];
    return [slot.value, next => { slot.value = typeof next === "function" ? next(slot.value) : next; }];
  }

  reference(initial) {
    const index = this.cursor++;
    return this.slots[index] ||= { current: initial };
  }

  effect(run, dependencies) {
    const index = this.cursor++;
    const previous = this.slots[index];
    if (previous?.dependencies.length === dependencies.length && previous.dependencies.every((entry, position) => dependencies[position] === entry)) return;
    this.tasks.push(() => {
      previous?.cleanup?.();
      this.slots[index] = { dependencies, cleanup: run() };
    });
  }

  render(Component, props) {
    globalThis.__dataScienceHooks = this;
    this.cursor = 0;
    const tree = Component(props);
    this.tasks.splice(0).forEach(task => task());
    return tree;
  }

  dispose() {
    this.slots.forEach(slot => slot.cleanup?.());
  }
}

const mock = {
  react: 'export const useState=v=>globalThis.__dataScienceHooks.state(v),useMemo=f=>f(),useRef=v=>globalThis.__dataScienceHooks.reference(v),useId=()=>"proof",useEffect=(run,dep)=>globalThis.__dataScienceHooks.effect(run,dep);',
  jsx: 'export const jsx=(type,props,key)=>({type,props,key}),jsxs=jsx,Fragment="fragment";',
  router: 'export const useSearchParams=()=>[new URLSearchParams(globalThis.__dataScienceSearch),next=>{globalThis.__dataScienceSearch=new URLSearchParams(next).toString();}];',
  auth: 'export const useAuth=()=>({user:globalThis.__dataScienceUser});',
  scope: 'export const useEntityScope=()=>globalThis.__dataScienceScope;',
  api: 'import {captureEntityScope} from "./src/services/entityScope"; export const requestJson=(url,options)=>new Promise(resolve=>globalThis.__dataScienceReads.push({url,options,scope:captureEntityScope(url),resolve}));',
  table: 'export const SimpleTable="tableFixture";',
};
const names = new Map([
  ["react", "react"], ["react/jsx-runtime", "jsx"], ["react-router-dom", "router"],
  ["../contexts/AuthContext", "auth"], ["../contexts/EntityScopeContext", "scope"], ["../services/api", "api"], ["../../services/api", "api"], ["./logistique/logistiqueShared", "table"],
]);
function plugin() {
  return { name: "data-science-proof", setup(build) {
    build.onResolve({ filter: /.*/ }, args => {
      if (args.path.endsWith(".css")) return { path: args.path, external: true };
      if (names.has(args.path)) return { path: names.get(args.path), namespace: "data-science" };
      if (/^(?:\.\.\/)+components\/[A-Z]\w+$/.test(args.path)) return { path: path.basename(args.path), namespace: "data-science" };
    });
    build.onLoad({ filter: /.*/, namespace: "data-science" }, args => ({
      resolveDir: front,
      contents: mock[args.path] || "export default " + JSON.stringify(args.path) + ";",
    }));
  } };
}

async function bundle() {
  const output = await esbuild.build({
    stdin: { contents: 'export {default as DataScience} from "./src/pages/DataScience"; export {default as Series} from "./src/pages/datascience/DemandSeries"; export {default as ProvinceMatrix, provinceMatrix} from "./src/pages/datascience/ProvinceMatrix"; export * from "./src/pages/datascience/analysisModel"; export {configureEntityScope, entityScopeIsCurrent} from "./src/services/entityScope"; export {mayOpen} from "./src/services/moduleAccess";', resolveDir: front },
    bundle: true, write: false, platform: "node", format: "cjs", jsx: "automatic", plugins: [plugin()],
  });
  const filename = path.join(front, "data-science-proof.cjs");
  const moduleUnderTest = new Module(filename, module);
  const load = moduleUnderTest.require.bind(moduleUnderTest);
  moduleUnderTest.require = name => name.endsWith(".css") ? {} : load(name);
  moduleUnderTest._compile(output.outputFiles.find(file => file.path.endsWith(".js") || file.path === "<stdout>").text, filename);
  return moduleUnderTest.exports;
}

function nodes(node) {
  if (Array.isArray(node)) return node.flatMap(nodes);
  if (!node || typeof node !== "object") return [];
  return [node, ...nodes(node.props?.children)];
}

function text(node) {
  if (Array.isArray(node)) return node.map(text).join("");
  if (typeof node === "string" || typeof node === "number") return String(node);
  return typeof node === "object" && node ? text(node.props?.children) : "";
}

function find(tree, matches) {
  const result = nodes(tree).find(matches);
  assert(result, "Élément attendu introuvable");
  return result;
}

function mountPage(DataScience) {
  const shell = new Hooks();
  let child = null;
  const renderShell = () => shell.render(DataScience);
  function renderWorkspace() {
    const workspace = find(renderShell(), node => typeof node.type === "function" && Object.hasOwn(node.props, "active"));
    if (child?.key !== workspace.key || child?.type !== workspace.type) {
      child?.hooks.dispose();
      child = { key: workspace.key, type: workspace.type, hooks: new Hooks() };
    }
    return child.hooks.render(workspace.type, workspace.props);
  }
  return { renderShell, renderWorkspace, dispose() { child?.hooks.dispose(); shell.dispose(); } };
}

const period = { debut: "2026-01", fin: "2026-03" };
const demand = {
  mois: "2026-01", produitId: "108", produitLibelle: "Hygiène", territoireId: 2, territoireLibelle: "Kinshasa",
  source: "product", nature: "demande_suivie", demandes: "11", satisfaites: null, nonSatisfaites: null,
};
const unmet = { ...demand, mois: "2026-03", nature: "besoin_sans_resultat", demandes: 5 };
const search = {
  mois: "2026-03", pathologieId: 309, pathologieLibelle: "Terme de référence", territoireId: 2, territoireLibelle: "Kinshasa",
  source: "product", nature: "recherche", recherches: 10, avecResultat: null, sansResultat: null,
};
const data = {
  periode: period, statutCollecte: "disponible", cellules: [demand, unmet, search],
  rapprochementDisponible: false, associationMaladieProduitDisponible: false, seuilConfidentialite: 5,
};
const nextTurn = () => new Promise(resolve => setImmediate(resolve));

(async () => {
  const {
    analysisPath, analysisPayload, periodError, periodMonths, reportDatePeriod, reportPeriodDates, reportToday, seriesRows, configureEntityScope, entityScopeIsCurrent, mayOpen, DEMAND_MEASURES, SEARCH_MEASURES, Series, DataScience, ProvinceMatrix, provinceMatrix,
  } = await bundle();
  assert.equal(analysisPath(period), "/api/data-science/indicateurs/demandes?debut=2026-01&fin=2026-03");
  assert.deepEqual(periodMonths(period), ["2026-01", "2026-02", "2026-03"]);
  assert.match(periodError({ debut: "2026-02", fin: "2026-01" }), /fin/);
  assert.match(periodError({ debut: "2026-01", fin: "2027-01" }), /12/);
  assert.match(periodError({ debut: "2026-21", fin: "2026-22" }), /AAAA-MM/);
  const today = "2026-11-14";
  assert.equal(reportToday(new Date("2026-11-13T23:00:00Z")), today);
  assert.deepEqual(reportPeriodDates(period, today), { debut: "2026-01-01", fin: "2026-03-31" });
  assert.deepEqual(reportPeriodDates({ debut: "2025-12", fin: "2026-11" }, today), { debut: "2025-12-01", fin: today });
  assert.deepEqual(reportDatePeriod({ debut: "2024-02-29", fin: "2024-02-29" }, today).period, { debut: "2024-02", fin: "2024-02" });
  assert.match(reportDatePeriod({ debut: "", fin: today }, today).error, /dates valides/);
  assert.match(reportDatePeriod({ debut: "2026-02-29", fin: today }, today).error, /dates valides/);
  assert.match(reportDatePeriod({ debut: "2026-11-13", fin: "2026-11-12" }, today).error, /précéder/);
  assert.match(reportDatePeriod({ debut: "2026-11-01", fin: "2026-11-15" }, today).error, /passé/);
  assert.match(reportDatePeriod({ debut: "2025-11-30", fin: today }, today).error, /12 mois/);
  assert.equal(reportDatePeriod({ debut: "2025-12-01", fin: today }, today).error, "");
  const model = analysisPayload(data);
  assert(model.collecteDisponible);
  assert.equal(model.associationMaladieProduitDisponible, false);
  assert.equal(model.cellules[0].demandes, 11);
  assert.equal(model.cellules[0].satisfaites, null);
  assert.equal(model.cellules[2].category, null);
  assert.equal(model.cellules[2].condition, "309");
  assert.equal(model.cellules[2].recherches, 10);
  assert.equal(model.cellules[2].demandes, null);
  assert.deepEqual(seriesRows(model.cellules, model.cellules[0].seriesKey, period).map(row => row.row?.demandes ?? null), [11, null, null]);
  assert.equal(analysisPayload({ ...data, cellules: [demand, demand] }), null);
  assert.equal(analysisPayload({ ...data, cellules: [{ ...demand, mois: "2026-05" }] }), null);
  assert.equal(analysisPayload({ ...data, statutCollecte: "indisponible" }).collecteDisponible, false);
  assert.equal(analysisPayload({ ...data, cellules: [{ ...demand, satisfaites: 0 }] }).cellules[0].satisfaites, 0);

  const selection = [];
  const graph = Series({ rows: model.cellules.slice(0, 1), period, measures: DEMAND_MEASURES, onMonth: (...args) => selection.push(args) });
  const monthButton = find(graph, node => node.type === "button");
  assert.match(monthButton.props["aria-label"], /Demandes 11.*Satisfaites —/);
  assert.equal(nodes(graph).filter(node => node.props?.className === "is-unavailable").length, 2);
  assert.equal(nodes(graph).filter(node => node.props?.className === "data-science-chart-empty").length, 2);
  monthButton.props.onClick();
  assert.deepEqual(selection, [["2026-01", model.cellules[0].seriesKey]]);
  const researchGraph = Series({ rows: model.cellules.slice(2), period, measures: SEARCH_MEASURES, onMonth() {} });
  assert.match(find(researchGraph, node => node.type === "button").props["aria-label"], /Recherches déclarées 10.*Avec résultat —/);


  const geography = analysisPayload({
    ...data,
    cellules: [
      demand,
      { ...demand, mois: "2026-02", territoireId: 11, territoireLibelle: "Kongo Central", demandes: 0, satisfaites: 0 },
      { ...demand, mois: "2026-03", territoireId: 11, territoireLibelle: "Kongo Central", produitId: 109, demandes: 7 },
      { ...demand, mois: "2026-03", territoireId: null, territoireLibelle: null },
    ],
  });
  const comparison = provinceMatrix(geography.cellules, "", period);
  assert.equal(comparison.options.length, 2);
  const twoProvinces = comparison.options.find(option =>
    provinceMatrix(geography.cellules, option.value, period).provinces.length === 2);
  assert(twoProvinces);
  const chosen = provinceMatrix(geography.cellules, twoProvinces.value, period);
  assert.deepEqual(chosen.provinces.map(({ label, cells }) => [label, cells.map(cell => cell?.demandes ?? null)]), [
    ["Kinshasa", [11, null, null]], ["Kongo Central", [null, 0, null]],
  ]);
  const matrixHooks = new Hooks();
  const matrixClicks = [];
  const matrixProps = { rows: geography.cellules, period, measures: DEMAND_MEASURES, onMonth: (...args) => matrixClicks.push(args) };
  let matrix = matrixHooks.render(ProvinceMatrix, matrixProps);
  find(matrix, node => node.type === "SearchSelect" && node.props.label === "Série à comparer").props.onChange(twoProvinces.value);
  matrix = matrixHooks.render(ProvinceMatrix, matrixProps);
  const zero = find(matrix, node => node.type === "button" && text(node) === "0");
  zero.props.onClick();
  assert.deepEqual(matrixClicks, [["2026-02", geography.cellules[1].seriesKey]]);
  assert.equal(nodes(matrix).filter(node => node.type === "abbr").length, 4);
  find(matrix, node => node.type === "SearchSelect" && node.props.label === "Mesure à afficher").props.onChange("satisfaites");
  matrix = matrixHooks.render(ProvinceMatrix, matrixProps);
  assert.match(find(matrix, node => node.type === "button" && text(node) === "—").props["aria-label"], /Valeur indisponible/);
  assert.equal(find(matrix, node => node.type === "button" && text(node) === "0").props.style["--matrix-intensity"], "0%");

  const reads = globalThis.__dataScienceReads = [];
  const canRead = { canRead: true, canManage: false, canExport: false };
  const noRead = { ...canRead, canRead: false };
  const administrator = {
    IdUser: 1, Is_Admin: true,
    moduleAccess: { platformAdmin: true, modules: { "data-science": canRead } },
  };
  const tenant = {
    IdUser: 2, IdEntiteFk: 7,
    moduleAccess: { platformAdmin: false, modules: { "data-science": canRead } },
  };
  const setScope = ({ user, entityId = "", scopeKey = `${user.IdUser}:${entityId || "all"}` }) => {
    globalThis.__dataScienceUser = user;
    globalThis.__dataScienceScope = {
      entityId, scopeKey, globalAdmin: user.moduleAccess.platformAdmin, entities: [
        { id: 7, label: "Entreprise A", active: true }, { id: 8, label: "Entreprise B", active: true },
      ],
      loading: false, error: "", ready: true,
    };
    configureEntityScope({ userId: user.IdUser, entityId, globalAdmin: user.moduleAccess.platformAdmin });
  };
  const reportUrl = (view, filter = "") => `/api/data-science/indicateurs/demandes?vue=${view}${filter}`;
  function latestRead(view, query = "") {
    const request = reads.at(-1);
    const actual = new URL(request.url, "http://localhost");
    const expected = new URL(reportUrl(view, query), "http://localhost");
    assert.equal(actual.pathname, expected.pathname);
    assert.deepEqual([...actual.searchParams.entries()].sort(), [...expected.searchParams.entries()].sort());
    assert.equal(request.options.requiresAuth, true);
    assert(request.options.signal);
    return request;
  }
  const answer = (perimetre, payload = {}) => ({ success: true, data: { ...data, ...payload, perimetre } });
  const globalScope = { type: "global", entrepriseId: null };
  const company = entrepriseId => ({ type: "entreprise", entrepriseId });
  const sidebar = tree => find(tree, node => node.type === "ModuleSidebar");
  const tabs = tree => sidebar(tree).props.groups.flatMap(group => group.items.map(item => item.key));
  const title = tree => text(find(tree, node => node.type === "h1"));
  const table = tree => find(tree, node => node.type === "tableFixture");
  const action = (tree, label) => find(tree, node => node.type === "ActionButton" && text(node) === label);
  const dashboardSummary = tree => {
    const component = find(tree, node => typeof node.type === "function" && Object.hasOwn(node.props, "canOpenResearch"));
    return component.type(component.props);
  };

  globalThis.__dataScienceSearch = "";
  const denied = { ...tenant, Is_Admin: true, moduleAccess: { platformAdmin: false } };
  setScope({ user: denied });
  const unauthorised = mountPage(DataScience);
  find(unauthorised.renderShell(), node => node.type === "ListState");
  assert.equal(mayOpen(denied, "/data-science"), false);
  assert.deepEqual(reads, []);
  unauthorised.dispose();

  setScope({ user: administrator });
  assert.equal(mayOpen(administrator, "/data-science"), true);
  const page = mountPage(DataScience);
  const { renderWorkspace, renderShell } = page;
  let tree = renderWorkspace();
  assert.equal(sidebar(renderShell()).props.activeKey, "tableau-de-bord");
  assert.deepEqual(tabs(renderShell()), ["tableau-de-bord", "demandes", "recherches", "perimetre"]);
  assert.equal(sidebar(renderShell()).props.headerProps.showEntityScope, true);
  assert.match(title(tree), /Tableau de bord/);
  const globalRequest = latestRead("tableau-de-bord");
  assert(globalRequest.scope.scoped);
  assert.deepEqual(globalRequest.scope.headers, {});
  globalRequest.resolve(answer(globalScope));
  await nextTurn();
  tree = renderWorkspace();
  action(dashboardSummary(tree), "Explorer les recherches");
  action(dashboardSummary(tree), "Explorer les demandes").props.onClick();

  tree = renderWorkspace();
  const request = latestRead("demandes");
  request.resolve(answer(globalScope, { cellules: [demand, unmet] }));
  await nextTurn();
  tree = renderWorkspace();
  assert.deepEqual(table(tree).props.rows.map(row => row.nature), ["demande_suivie", "besoin_sans_resultat"]);
  assert.match(text(tree), /Définitions et limites/);
  assert.match(text(tree), /5 contributeurs distincts/);
  const dateFields = current => nodes(current).filter(node => node.type === "input" && node.props.type === "date");
  assert.deepEqual(dateFields(tree).map(node => node.props.value), ["2026-01-01", "2026-03-31"]);
  assert.match(text(tree), /Mois affichés/);
  action(tree, "Comparaison par province").props.onClick();
  tree = renderWorkspace();
  const matrixPanel = find(tree, node => node.type === ProvinceMatrix);
  matrixPanel.props.onMonth("2026-01", matrixPanel.props.rows[0].seriesKey);
  tree = renderWorkspace();
  assert.deepEqual(table(tree).props.rows.map(row => row.mois), ["2026-01"]);

  sidebar(renderShell()).props.onNavigate("recherches");
  tree = renderWorkspace();
  assert.match(title(tree), /Recherches déclarées/);
  latestRead("recherches").resolve(answer(globalScope, { cellules: [search] }));
  await nextTurn();
  tree = renderWorkspace();
  assert.deepEqual(table(tree).props.rows.map(row => row.nature), ["recherche"]);
  assert.match(text(tree), /Aucune correspondance maladie–produit validée/);
  const condition = find(tree, node => node.type === "SearchSelect" && node.props.label === "Terme de maladie");
  assert.deepEqual(condition.props.options.map(item => item.label), ["Tous les termes", "Terme de référence"]);
  condition.props.onChange('"309"');
  tree = renderWorkspace();
  assert.equal(table(tree).props.rows.length, 1);
  assert.deepEqual(dateFields(tree).map(node => node.props.value), ["2026-01-01", "2026-03-31"]);
  const beforeInvalidRange = reads.length;
  dateFields(tree)[0].props.onChange({ target: { value: "2026-03-18" } });
  dateFields(tree)[1].props.onChange({ target: { value: "2026-03-17" } });
  const submit = current => find(current, node => node.type === "form").props.onSubmit({ preventDefault() {} });
  submit(renderWorkspace());
  tree = renderWorkspace();
  assert.match(text(find(tree, node => node.type === "p" && node.props.role === "alert")), /précéder/);
  assert.equal(reads.length, beforeInvalidRange);
  dateFields(tree)[0].props.onChange({ target: { value: "2026-02-18" } });
  submit(renderWorkspace());
  renderWorkspace();
  const custom = latestRead("recherches", "&debut=2026-02&fin=2026-03");
  custom.resolve(answer(globalScope, { periode: { debut: "2026-02", fin: "2026-03" }, cellules: [] }));
  await nextTurn();
  tree = renderWorkspace();
  assert.deepEqual(dateFields(tree).map(node => node.props.value), ["2026-02-18", "2026-03-17"]);
  assert.match(text(tree), /Mois affichés · févr.*mars/);
  action(tree, "Période par défaut").props.onClick();
  tree = renderWorkspace();
  assert(request.options.signal.aborted);
  assert(custom.options.signal.aborted);
  assert.match(find(tree, node => node.type === "ListState").props.title, /Chargement/);
  const failed = latestRead("recherches");
  failed.resolve({ success: false, status: 403 });
  await nextTurn();
  tree = renderWorkspace();
  find(tree, node => node.type === "ListState" && node.props.action).props.action.props.onClick();
  renderWorkspace();
  const pending = latestRead("recherches");

  setScope({ user: administrator, entityId: "7" });
  globalThis.__dataScienceSearch = "onglet=demandes";
  tree = renderWorkspace();
  assert(pending.options.signal.aborted);
  assert.equal(entityScopeIsCurrent(pending.scope), false);
  const stale = latestRead("demandes");
  assert.deepEqual(stale.scope.headers, { "X-Entite-ID": "7" });
  setScope({ user: administrator, entityId: "8" });
  tree = renderWorkspace();
  assert(stale.options.signal.aborted);
  assert.equal(entityScopeIsCurrent(stale.scope), false);
  assert(!nodes(tree).some(node => node.type === "tableFixture"));
  const selected = latestRead("demandes");
  assert.deepEqual(selected.scope.headers, { "X-Entite-ID": "8" });
  assert(entityScopeIsCurrent(selected.scope));

  stale.resolve(answer(company(7), { cellules: [{ ...demand, produitLibelle: "Données de A" }] }));
  await nextTurn();
  tree = renderWorkspace();
  assert(!nodes(tree).some(node => node.type === "tableFixture"));
  selected.resolve(answer(company(7), { cellules: [{ ...demand, produitLibelle: "Réponse fournisseur incohérente" }] }));
  await nextTurn();
  tree = renderWorkspace();
  assert(!nodes(tree).some(node => node.type === "tableFixture"));
  find(tree, node => node.type === "ListState" && node.props.action).props.action.props.onClick();
  renderWorkspace();
  latestRead("demandes").resolve(answer(company(8), { cellules: [{ ...demand, produitLibelle: "Données de B" }] }));
  await nextTurn();
  assert.deepEqual(table(renderWorkspace()).props.rows.map(row => row.produitLibelle), ["Données de B"]);
  page.dispose();

  setScope({ user: tenant, entityId: "7" });
  assert.equal(mayOpen(tenant, "/data-science"), true);
  for (const restricted of ["recherches", "perimetre"]) {
    globalThis.__dataScienceSearch = "onglet=" + restricted;
    const restrictedPage = mountPage(DataScience);
    const beforeRestricted = reads.length;
    const restrictedTree = restrictedPage.renderShell();
    assert.deepEqual(tabs(restrictedTree), ["tableau-de-bord", "demandes"]);
    assert.match(find(restrictedTree, node => node.type === "ListState").props.title, /pas accès/);
    assert.equal(reads.length, beforeRestricted);
    restrictedPage.dispose();
  }

  globalThis.__dataScienceSearch = "";
  const tenantPage = mountPage(DataScience);
  tenantPage.renderWorkspace();
  const requestForTenant = latestRead("tableau-de-bord");
  assert.deepEqual(requestForTenant.scope.headers, {});
  requestForTenant.resolve(answer(company(7), { cellules: [demand] }));
  await nextTurn();
  const tenantSummary = dashboardSummary(tenantPage.renderWorkspace());
  action(tenantSummary, "Explorer les demandes");
  assert(!nodes(tenantSummary).some(node => node.type === "ActionButton" && text(node) === "Explorer les recherches"));
  tenantPage.dispose();

  const restrictedUser = {
    ...tenant,
    moduleAccess: { ...tenant.moduleAccess, tabs: { "data-science": { demandes: noRead } } },
  };
  setScope({ user: restrictedUser, entityId: "7", scopeKey: "2:7:dashboard-only" });
  globalThis.__dataScienceSearch = "onglet=tableau-de-bord";
  const dashboardOnly = mountPage(DataScience);
  assert.deepEqual(tabs(dashboardOnly.renderShell()), ["tableau-de-bord"]);
  dashboardOnly.renderWorkspace();
  const lastRequest = latestRead("tableau-de-bord");
  lastRequest.resolve(answer(company(7), { cellules: [demand] }));
  await nextTurn();
  assert(!nodes(dashboardSummary(dashboardOnly.renderWorkspace())).some(node => node.type === "ActionButton" && text(node) === "Explorer les demandes"));
  dashboardOnly.dispose();
  assert(lastRequest.options.signal.aborted);
  console.log("Module Data science : agrégats, confidentialité, graphique, filtres, navigation et chargement vérifiés.");
})().catch(error => { console.error(error); process.exitCode = 1; });
