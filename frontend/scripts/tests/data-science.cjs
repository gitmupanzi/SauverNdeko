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
  router: 'export const Link="Link",useSearchParams=()=>[new URLSearchParams(globalThis.__dataScienceSearch),next=>{globalThis.__dataScienceSearch=new URLSearchParams(next).toString();}];',
  auth: 'export const useAuth=()=>({user:globalThis.__dataScienceUser});',
  scope: 'export const useEntityScope=()=>globalThis.__dataScienceScope;',
  api: `import {captureEntityScope} from "./src/services/entityScope";
    export function requestJson(url,options){
      const scope=captureEntityScope(url);
      if(url==="/api/data-science/presentation"){
        const entityId=Number(globalThis.__dataScienceScope.entityId);
        return {then:read=>read({success:true,data:{entityId,...globalThis.__dataSciencePresentation}})};
      }
      return new Promise(resolve=>globalThis.__dataScienceReads.push({url,options,scope,resolve}));
    }`,
  table: 'export const SimpleTable="tableFixture",formatDate=value=>value||"—";',
};
const names = new Map([
  ["react", "react"], ["react/jsx-runtime", "jsx"], ["react-router-dom", "router"],
  ["../contexts/AuthContext", "auth"], ["../contexts/EntityScopeContext", "scope"], ["../services/api", "api"], ["../../services/api", "api"], ["./logistique/logistiqueShared", "table"], ["../logistique/logistiqueShared", "table"],
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
    stdin: { contents: 'export {default as DataScience} from "./src/pages/DataScience"; export {default as Series} from "./src/pages/datascience/DemandSeries"; export {default as ProvinceMatrix, provinceMatrix} from "./src/pages/datascience/ProvinceMatrix"; export {default as ScienceDashboard} from "./src/pages/datascience/ScienceDashboard"; export {default as DashboardTrend} from "./src/pages/datascience/DashboardTrend"; export * from "./src/pages/datascience/dashboardModel"; export * from "./src/pages/datascience/analysisModel"; export {captureEntityScope, configureEntityScope, entityScopeIsCurrent} from "./src/services/entityScope"; export {mayOpen} from "./src/services/moduleAccess";', resolveDir: front },
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
  let register = null;
  const renderShell = () => { shell.render(DataScience); return shell.render(DataScience); };
  function renderWorkspace() {
    const workspace = find(renderShell(), node => typeof node.type === "function" && Object.hasOwn(node.props, "active"));
    if (child?.key !== workspace.key || child?.type !== workspace.type) {
      child?.hooks.dispose();
      register?.hooks.dispose();
      register = null;
      child = { key: workspace.key, type: workspace.type, hooks: new Hooks() };
    }
    return child.hooks.render(workspace.type, workspace.props);
  }
  function renderChild(Component) {
    const node = find(renderWorkspace(), item => item.type === Component);
    if (register?.key !== node.key || register?.type !== node.type) {
      register?.hooks.dispose();
      register = { key: node.key, type: node.type, hooks: new Hooks() };
    }
    return register.hooks.render(node.type, node.props);
  }
  return { renderShell, renderWorkspace, renderDashboard: renderChild, renderChild,
    dispose() { child?.hooks.dispose(); register?.hooks.dispose(); shell.dispose(); } };
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
    analysisPath, analysisPayload, periodError, periodMonths, reportDatePeriod, reportPeriodDates, reportToday, recentReportDates, seriesRows, captureEntityScope, configureEntityScope, entityScopeIsCurrent, mayOpen, DEMAND_MEASURES, SEARCH_MEASURES, Series, DataScience, ScienceDashboard, DashboardTrend, dashboardAnalysis, ProvinceMatrix, provinceMatrix,
  } = await bundle();
  assert.equal(analysisPath(period), "/api/data-science/indicateurs/demandes?debut=2026-01&fin=2026-03");
  assert.deepEqual(periodMonths(period), ["2026-01", "2026-02", "2026-03"]);
  assert.match(periodError({ debut: "2026-02", fin: "2026-01" }), /fin/);
  assert.match(periodError({ debut: "2026-01", fin: "2027-01" }), /12/);
  assert.match(periodError({ debut: "2026-21", fin: "2026-22" }), /AAAA-MM/);
  const today = "2026-11-14";
  assert.equal(reportToday(new Date("2026-11-13T23:00:00Z")), today);
  assert.deepEqual(recentReportDates(3, "2026-02-04"), { debut: "2025-12-01", fin: "2026-02-04" });
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
  const totals = dashboardAnalysis(model.cellules, period, true);
  assert.deepEqual(totals.points.map(point => [point.demandes, point.recherches]), [[11, null], [null, null], [5, 10]]);
  assert.equal(totals.groups[0].metrics.find(item => item.key === "demandes").value, 16);
  assert.equal(totals.groups[0].metrics.find(item => item.key === "satisfaites").value, null);
  assert.deepEqual(totals.populations.get("besoins").rows.map(row => row.key), [model.cellules[1].key]);
  assert.equal(dashboardAnalysis(model.cellules, period, false).groups.some(group => group.key === "recherches"), false);
  assert.equal(dashboardAnalysis([], period, false).groups[0].metrics[0].value, null);
  const trend = DashboardTrend({ points: totals.points, showResearch: true, onMonth() {} });
  assert.equal(nodes(trend).filter(node => node.type === "button").length, 2);
  assert.equal(nodes(trend).filter(node => node.type === "path")[0].props.d.match(/M/g).length, 2);

  const selection = [];
  const graph = Series({ rows: model.cellules.slice(0, 1), period, measures: DEMAND_MEASURES, onMonth: (...args) => selection.push(args) });
  const monthButton = find(graph, node => node.type === "button");
  assert.match(monthButton.props["aria-label"], /Demandes 11.*Satisfaites —/);
  assert.equal(nodes(graph).filter(node => node.props?.className === "is-unavailable").length, 2);
  assert.equal(nodes(graph).filter(node => node.props?.className === "data-science-chart-empty").length, 2);
  const chartButton = { focus() {} };
  monthButton.props.onClick({ currentTarget: chartButton });
  assert.deepEqual(selection, [["2026-01", model.cellules[0].seriesKey, chartButton]]);
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
  zero.props.onClick({ currentTarget: chartButton });
  assert.deepEqual(matrixClicks, [["2026-02", geography.cellules[1].seriesKey, chartButton]]);
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
  const toolbar = tree => find(table(tree).props.toolbar, node => node.type === "DataTableToolbar").props;

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
  let tree = page.renderDashboard(ScienceDashboard);
  assert.equal(sidebar(renderShell()).props.activeKey, "tableau-de-bord");
  assert.deepEqual(tabs(renderShell()), ["tableau-de-bord", "demandes", "recherches", "perimetre"]);
  assert.equal(sidebar(renderShell()).props.headerProps.showEntityScope, true);
  assert.match(title(tree), /Tableau de bord/);
  const globalRequest = latestRead("tableau-de-bord");
  assert(globalRequest.scope.scoped);
  assert.deepEqual(globalRequest.scope.headers, {});
  globalRequest.resolve(answer(globalScope));
  await nextTurn();
  tree = page.renderDashboard(ScienceDashboard);
  action(tree, "Explorer les recherches");
  const applyDashboard = current => find(current, node => node.type === "form").props.onSubmit({ preventDefault() {} });
  const indicatorPanel = current => find(current, node => node.props?.activeMetric !== undefined && node.props?.groups);
  const dashboard = () => page.renderDashboard(ScienceDashboard);
  const searchField = find(tree, node => node.type === "input" && node.props.type === "search");
  searchField.props.onChange({ target: { value: "hygiene" } });
  tree = dashboard();
  assert.equal(indicatorPanel(tree).props.groups[1].metrics[0].value, 10);
  applyDashboard(tree);
  tree = dashboard();
  const indicators = indicatorPanel(tree).props;
  assert.equal(indicators.groups[0].metrics[0].value, 16);
  assert.equal(indicators.groups[1].metrics[0].value, null);
  const trigger = { getClientRects: () => [1], focus() { this.restored = true; } };
  indicators.onMetric("demandes", indicators.groups[0].metrics[1], trigger);
  tree = dashboard();
  assert.deepEqual(table(tree).props.rows.map(row => row.nature), ["besoin_sans_resultat"]);
  action(tree, "Revenir à l’indicateur").props.onClick();
  assert.equal(trigger.restored, true);
  tree = dashboard();
  find(tree, node => node.type === DashboardTrend).props.onMonth("2026-01", trigger);
  assert.deepEqual(table(dashboard()).props.rows.map(row => row.mois), ["2026-01"]);
  tree = dashboard();
  action(tree, "Filtrer").props.onClick();
  tree = dashboard();
  find(tree, node => node.type === "SearchSelect" && node.props.label === "Nature du signal").props.onChange('"demande_suivie"');
  applyDashboard(dashboard());
  tree = dashboard();
  assert.equal(indicatorPanel(tree).props.groups[0].metrics[0].value, 11);
  assert.equal(indicatorPanel(tree).props.groups[0].metrics[1].value, null);
  action(tree, "Explorer les demandes").props.onClick();

  tree = renderWorkspace();
  const request = latestRead("demandes");
  request.resolve(answer(globalScope, { cellules: [demand, unmet] }));
  await nextTurn();
  const AnalysisRegister = find(renderWorkspace(), node => node.type?.name === "AnalysisRegister").type;
  const register = () => page.renderChild(AnalysisRegister);
  tree = register();
  assert.deepEqual(table(tree).props.rows.map(row => row.nature), ["demande_suivie", "besoin_sans_resultat"]);
  assert.match(text(renderWorkspace()), /Définitions et limites/);
  assert.match(text(renderWorkspace()), /5 contributeurs distincts/);
  const settings = current => find(find(current, node => node.type === "RegisterSurface").props.actions, node => node.type === "RegisterSettingsButton");
  settings(tree).props.onTableSettings();
  assert.equal(table(register()).props.columnsPanelOpen, true);
  toolbar(tree).onTake(10);
  toolbar(tree).toggleDensity();
  toolbar(tree).toggleFilters();
  tree = register();
  assert.equal(table(tree).props.rowsPerPage, 10);
  assert.equal(find(tree, node => node.props?.["data-density"]).props["data-density"], "airy");
  const dateFields = current => nodes(table(current).props.toolbar).filter(node => node.type === "input" && node.props.type === "date");
  assert.deepEqual(dateFields(tree).map(node => node.props.value), ["2026-01-01", "2026-03-31"]);
  assert.match(text(table(tree).props.toolbar), /Mois affichés/);
  action(tree, "Comparaison par province").props.onClick();
  tree = register();
  const matrixPanel = find(tree, node => node.type === ProvinceMatrix);
  matrixPanel.props.onMonth("2026-01", matrixPanel.props.rows[0].seriesKey);
  tree = register();
  assert.deepEqual(table(tree).props.rows.map(row => row.mois), ["2026-01"]);

  sidebar(renderShell()).props.onNavigate("recherches");
  tree = register();
  assert.match(find(tree, node => node.type === "RegisterSurface").props.title, /Recherches déclarées/);
  latestRead("recherches").resolve(answer(globalScope, { cellules: [search] }));
  await nextTurn();
  tree = register();
  assert.deepEqual(table(tree).props.rows.map(row => row.nature), ["recherche"]);
  assert.match(text(renderWorkspace()), /Aucune correspondance maladie–produit validée/);
  toolbar(tree).setSearch("aucune correspondance");
  assert.equal(table(register()).props.rows.length, 1);
  assert.equal(toolbar(register()).pending, true);
  toolbar(register()).onApply();
  assert.equal(table(register()).props.rows.length, 0);
  assert.equal(toolbar(register()).exportFile, undefined);
  const searchChip = find(table(register()).props.toolbar, node => node.type === "button" && node.props["aria-label"]?.startsWith("Retirer Recherche"));
  searchChip.props.onClick();
  assert.equal(table(register()).props.rows.length, 1);
  toolbar(register()).toggleFilters();
  tree = register();
  const condition = find(table(tree).props.toolbar, node => node.type === "SearchSelect" && node.props.label === "Terme de maladie");
  assert.deepEqual(condition.props.options.map(item => item.label), ["Tous les termes", "Terme de référence"]);
  condition.props.onChange('"309"');
  tree = register();
  assert.equal(table(tree).props.rows.length, 1);
  assert.deepEqual(dateFields(tree).map(node => node.props.value), ["2026-01-01", "2026-03-31"]);
  const beforeInvalidRange = reads.length;
  dateFields(tree)[0].props.onChange({ target: { value: "2026-03-18" } });
  dateFields(tree)[1].props.onChange({ target: { value: "2026-03-17" } });
  const submit = current => find(table(current).props.toolbar, node => node.type === "form").props.onSubmit({ preventDefault() {} });
  submit(register());
  tree = register();
  assert.match(text(find(table(tree).props.toolbar, node => node.type === "p" && node.props.role === "alert")), /précéder/);
  assert.equal(reads.length, beforeInvalidRange);
  dateFields(tree)[0].props.onChange({ target: { value: "2026-02-18" } });
  submit(register());
  register();
  const custom = latestRead("recherches", "&debut=2026-02&fin=2026-03");
  custom.resolve(answer(globalScope, { periode: { debut: "2026-02", fin: "2026-03" }, cellules: [] }));
  await nextTurn();
  tree = register();
  assert.deepEqual(dateFields(tree).map(node => node.props.value), ["2026-02-18", "2026-03-17"]);
  assert.match(text(table(tree).props.toolbar), /Mois affichés · févr.*mars/);
  toolbar(tree).onReset();
  tree = register();
  assert(request.options.signal.aborted);
  assert(custom.options.signal.aborted);
  assert.match(find(tree, node => node.type === "ListState").props.title, /Chargement/);
  const failed = latestRead("recherches");
  failed.resolve({ success: false, status: 403 });
  await nextTurn();
  tree = register();
  find(tree, node => node.type === "ListState" && node.props.action).props.action.props.onClick();
  renderWorkspace();
  const pending = latestRead("recherches");

  setScope({ user: administrator, entityId: "7" });
  assert.deepEqual(captureEntityScope("/api/data-science/presentation").headers, { "X-Entite-ID": "7" });
  assert.equal(captureEntityScope("/api/data-science/perimetre").scoped, false);
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
  assert.equal(table(register()).props.rows.length, 0);
  const selected = latestRead("demandes");
  assert.deepEqual(selected.scope.headers, { "X-Entite-ID": "8" });
  assert(entityScopeIsCurrent(selected.scope));

  stale.resolve(answer(company(7), { cellules: [{ ...demand, produitLibelle: "Données de A" }] }));
  await nextTurn();
  tree = renderWorkspace();
  assert.equal(table(register()).props.rows.length, 0);
  selected.resolve(answer(company(7), { cellules: [{ ...demand, produitLibelle: "Réponse fournisseur incohérente" }] }));
  await nextTurn();
  tree = renderWorkspace();
  assert.equal(table(register()).props.rows.length, 0);
  find(register(), node => node.type === "ListState" && node.props.action).props.action.props.onClick();
  renderWorkspace();
  latestRead("demandes").resolve(answer(company(8), { cellules: [{ ...demand, produitLibelle: "Données de B" }] }));
  await nextTurn();
  assert.deepEqual(table(register()).props.rows.map(row => row.produitLibelle), ["Données de B"]);
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
  const tenantSummary = tenantPage.renderDashboard(ScienceDashboard);
  action(tenantSummary, "Explorer les demandes");
  assert(!nodes(tenantSummary).some(node => node.type === "ActionButton" && text(node) === "Explorer les recherches"));
  assert(!nodes(tenantSummary).some(node => node.type === "SearchSelect" && node.props.label === "Terme de maladie"));
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
  assert(!nodes(dashboardOnly.renderDashboard(ScienceDashboard)).some(node => node.type === "ActionButton" && text(node) === "Explorer les demandes"));
  dashboardOnly.dispose();
  assert(lastRequest.options.signal.aborted);

  globalThis.__dataSciencePresentation = {tabLabels:{demandes:"Suivi des besoins"},hiddenTabs:["tableau-de-bord"]};
  setScope({ user: tenant, entityId: "7" });
  globalThis.__dataScienceSearch = "";
  const presentationPage = mountPage(DataScience);
  const presentationShell = presentationPage.renderShell();
  assert.deepEqual(tabs(presentationShell), ["demandes"]);
  assert.equal(sidebar(presentationShell).props.activeKey,"demandes");
  assert.equal(sidebar(presentationShell).props.groups[0].items[0].label,"Suivi des besoins");
  assert.equal(find(presentationPage.renderWorkspace(), node => node.type === AnalysisRegister).props.title,"Suivi des besoins");
  presentationPage.dispose();
  globalThis.__dataSciencePresentation = undefined;

  setScope({ user: administrator });
  globalThis.__dataScienceSearch = "onglet=perimetre";
  const scopePage = mountPage(DataScience);
  const scopeNode = find(scopePage.renderShell(), node => node.type?.name === "ResearchScope");
  const scopeHooks = new Hooks();
  const renderScope = () => scopeHooks.render(scopeNode.type, scopeNode.props);
  renderScope();
  const scopeRequest = reads.at(-1);
  assert.equal(scopeRequest.url, "/api/data-science/perimetre");
  scopeRequest.resolve({success:true,data:{entreprises:[
    {id:7,nom:"École Pilote",debuteLe:"2026-01-01"}, {id:8,nom:"Autre entreprise",debuteLe:null},
  ]}});
  await nextTurn();
  let scopeTree = renderScope();
  toolbar(scopeTree).setSearch("ecole");
  scopeTree = renderScope();
  assert.equal(table(scopeTree).props.rows.length, 2);
  toolbar(scopeTree).onApply();
  scopeTree = renderScope();
  assert.deepEqual(table(scopeTree).props.rows.map(row => row.id), [7]);
  settings(scopeTree).props.onTableSettings();
  assert.equal(table(renderScope()).props.columnsPanelOpen, true);
  toolbar(renderScope()).onReset();
  scopeTree = renderScope();
  assert.equal(table(scopeTree).props.rows.length, 2);
  assert.equal(toolbar(scopeTree).exportCsv, undefined);
  table(scopeTree).props.onRowConsult(table(scopeTree).props.rows[0]);
  const editor = find(renderScope(), node => node.type?.name === "ParticipationEditor");
  const readOnlyEditor = new Hooks().render(editor.type, {...editor.props,canManage:false});
  assert.equal(readOnlyEditor.props.readOnly, true);
  assert.equal(readOnlyEditor.props.canSubmit, false);
  scopeHooks.dispose();
  scopePage.dispose();
  console.log("Module Data science : agrégats, confidentialité, graphique, filtres, navigation et chargement vérifiés.");
})().catch(error => { console.error(error); process.exitCode = 1; });
