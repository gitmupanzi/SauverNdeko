const assert = require("node:assert/strict");
const fs = require("node:fs");
const Module = require("node:module");
const path = require("node:path");
const test = require("node:test");

const frontend = path.resolve(__dirname, "../..");
const base = process.env.SEARCH_NEEDS_SOURCE_FRONTEND || frontend;
const dependencies = process.env.SEARCH_NEEDS_NODE_MODULES || path.join(frontend, "node_modules");
const esbuild = require(path.join(dependencies, "esbuild"));
const nextTick = () => new Promise(resolve => setImmediate(resolve));

const widgets = {
  DataTableToolbar: "Toolbar", ActionButton: "Button",
  RegisterSurface: "Surface", ListState: "ListState", AppIcon: "Icon",
  ArticlePhoto: "Photo", AppliedCriteria: "Criteria", SearchSelect: "Select",
  RegisterSettingsButton: "Settings", RowActionsMenu: "Actions", ModuleSidebar: "Sidebar",
};
const doubles = [
  [/^react$/, "export const useState=v=>__hooks.state(v),useRef=v=>__hooks.ref(v),useId=()=>__hooks.id(),useEffect=(fn,deps)=>__hooks.effect(fn,deps);"],
  [/^react-router-dom$/, "export function Link(){};export const useLocation=()=>__location,useNavigate=()=>()=>{},useSearchParams=()=>[__params,value=>{globalThis.__params=new URLSearchParams(value);}];"],
  [/\/AuthContext$/, "export const useAuth=()=>({user:__user});"],
  [/\/EntityScopeContext$/, "export const useEntityScope=()=>({scopeKey:'test',entityId:7});"],
  [/\/api$/, "export const requestJson=(url,options)=>new Promise(resolve=>__reads.push({url,options,resolve}));export const downloadApiFile=()=>{};"],
  [/\/useReferencesRefresh$/, "export default function refresh(){}"],
  [/\/logistiqueShared$/, "export function SimpleTable(){}"],
  [/\/(ProductOfferDetail|StructureDetail|ExpertReferences|ExpertAvatar)$/, "export default function SidePanel(){}"],
  ...Object.entries(widgets).map(([file, name]) => [
    new RegExp("/" + file + "$"), "export default function " + name + "(){}",
  ]),
];

async function bundle() {
  const built = await esbuild.build({
    stdin: {
      contents: "export {default as product} from './src/pages/produits/ProductDirectory';export {default as expert} from './src/pages/experts/ExpertDirectory';export {default as structure} from './src/pages/structures/StructureDirectory';",
      resolveDir: base,
    },
    bundle: true, write: false, platform: "node", jsx: "automatic",
    external: ["react/jsx-runtime"], loader: {".css": "empty"},
    plugins: [{name: "search-fixtures", setup(build) {
      for (const [index, [filter, contents]] of doubles.entries()) {
        const namespace = "double-" + index;
        build.onResolve({filter}, () => ({path: namespace, namespace}));
        build.onLoad({filter: /.*/, namespace}, () => ({contents}));
      }
      build.onResolve({filter: /\/SearchNeedAction$/}, () => ({
        path: path.join(base, "src/components/SearchNeedAction.jsx"),
      }));
      build.onLoad({filter: /\.[jt]sx?$/}, args => {
        const overlay = path.join(frontend, path.relative(base, args.path));
        if (fs.existsSync(overlay)) {
          return {contents: fs.readFileSync(overlay, "utf8"), loader: path.extname(args.path).slice(1)};
        }
      });
    }}],
  });
  const compiled = new Module(path.join(frontend, "search-needs-fixture.cjs"), module);
  compiled.filename = path.join(frontend, "search-needs-fixture.cjs");
  compiled.paths = [dependencies];
  compiled._compile(built.outputFiles[0].text, compiled.filename);
  return compiled.exports;
}

class Hooks {
  constructor() { this.slots = []; this.effects = []; }
  state(value) {
    const id = this.cursor++;
    this.slots[id] ||= {value: typeof value === "function" ? value() : value};
    return [this.slots[id].value, update => {
      const slot = this.slots[id];
      slot.value = typeof update === "function" ? update(slot.value) : update;
    }];
  }
  ref(value) { return this.slots[this.cursor++] ||= {current: value}; }
  id() { return "proof-" + this.cursor++; }
  effect(fn, deps = []) {
    const id = this.cursor++;
    const prior = this.slots[id];
    if (!prior || deps.some((value, index) => !Object.is(value, prior.deps[index]))) {
      this.effects.push(() => { prior?.cleanup?.(); this.slots[id] = {deps, cleanup: fn()}; });
    }
  }
  render(Component, props) {
    globalThis.__hooks = this;
    this.cursor = 0;
    return Component(props);
  }
  async flush() { this.effects.splice(0).forEach(fn => fn()); await nextTick(); }
  dispose() { for (const slot of this.slots) slot?.cleanup?.(); }
}

function find(tree, predicate) {
  if (!tree || typeof tree !== "object") return undefined;
  if (Array.isArray(tree)) return tree.map(value => find(value, predicate)).find(Boolean);
  if (predicate(tree)) return tree;
  return ["children", "actions", "toolbar", "action", "emptyAction"].map(key =>
    find(tree.props?.[key], predicate)).find(Boolean);
}

const rights = {canRead: true, canManage: true};
const allowed = {IdUser: 17, permissions: {canWriteData: false}, moduleAccess: {
  readOnly: false, modules: {discussions: rights}, tabs: {discussions: {demandes: rights}},
}};
const fixtures = {
  product: {row: {ID_Article: 2}, list: "/offres?", references: {}},
  expert: {row: {id: 7}, list: "/annuaire?", references: {}},
  structure: {row: {id: 9, level: 5, key: "n5:9", contactsPublished: false},
    list: "/annuaire-sanitaire?", references: {types: [], levels: [], provinces: [], canManageTerritories: false}},
};
const need = tree => find(tree, node => node.type?.name === "SearchNeedAction");

test("each search offers an explicit handoff after a confirmed applied result", async () => {
  globalThis.localStorage = {getItem: () => null, setItem() {}};
  const directories = await bundle();
  for (const [kind, {row, list, references}] of Object.entries(fixtures)) {
    const hooks = new Hooks();
    try {
      Object.assign(globalThis, {__user: allowed, __params: new URLSearchParams(),
        __location: {key: "initial", state: null}, __reads: []});
      const render = () => hooks.render(directories[kind], {});
      const toolbar = tree => find(tree, node => node.type?.name === "Toolbar");
      const resolveList = response => __reads.findLast(item => item.url.includes(list)).resolve(response);
      const succeed = rows => resolveList({success: true, data: {rows, total: rows.length}});
      render();
      await hooks.flush();
      for (const call of __reads.filter(item => item.url.endsWith("/references"))) {
        call.resolve({success: true, data: references});
      }
      succeed([]);
      await hooks.flush();
      assert.equal(need(render()), undefined, kind);
      toolbar(render()).props.setSearch("texte privé à ne pas transmettre");
      const draft = render();
      assert.equal(need(draft), undefined, kind);
      toolbar(draft).props.onApply();
      assert.equal(need(render()), undefined, kind);
      await hooks.flush();
      succeed([]);
      await hooks.flush();
      const verifyLink = async shareSearch => {
        const action = need(render());
        assert.ok(action, kind);
        assert.equal(Boolean(action.props.shareSearch), shareSearch, kind);
        const actionNode = action.type(action.props);
        let link;
        if (shareSearch) {
          for (const outcome of [
            {success: true, data: {canWrite: true, canShareResearch: false}},
            {success: true, data: {canWrite: false, canShareResearch: true}},
            {success: false, status: 403},
            {success: true, data: {canWrite: true, canShareResearch: true}},
          ]) {
            const eligibility = new Hooks();
            try {
              assert.equal(eligibility.render(actionNode.type, actionNode.props), null);
              await eligibility.flush();
              const request = __reads.at(-1);
              assert.equal(request.url, "/api/discussions/besoins/options");
              assert.equal(request.options.requiresAuth, true);
              assert.equal(request.options.body, undefined);
              request.resolve(outcome);
              await eligibility.flush();
              const verified = eligibility.render(actionNode.type, actionNode.props);
              if (outcome.data?.canWrite && outcome.data?.canShareResearch) {
                link = verified.type(verified.props);
              } else {
                assert.equal(verified, null);
              }
            } finally {
              eligibility.dispose();
            }
          }
          const departed = new Hooks();
          departed.render(actionNode.type, actionNode.props);
          await departed.flush();
          const pending = __reads.at(-1);
          departed.dispose();
          assert.equal(pending.options.signal.aborted, true);
        } else {
          const before = __reads.length;
          link = actionNode.type(actionNode.props);
          assert.equal(__reads.length, before);
        }
        assert.equal(link.props.to, "/discussions?onglet=demandes");
        assert.deepEqual(link.props.state, {newNeed: shareSearch ? {source: kind, nature: "recherche"} : {source: kind}});
        __user = {...allowed, moduleAccess: {...allowed.moduleAccess, readOnly: true}};
        assert.equal(action.type(action.props), null);
        __user = {...allowed, moduleAccess: {...allowed.moduleAccess,
          tabs: {discussions: {demandes: {canRead: true, canManage: false}}}}};
        assert.equal(action.type(action.props), null);
        __user = allowed;
      };
      await verifyLink(false);
      find(render(), node => node.props?.["aria-label"] === "Affichage en tableau").props.onClick();
      await verifyLink(false);
      toolbar(render()).props.onApply();
      render();
      await hooks.flush();
      succeed([row]);
      await hooks.flush();
      await verifyLink(true);
      toolbar(render()).props.setSearch("autre recherche");
      assert.equal(need(render()), undefined, kind);
      toolbar(render()).props.onApply();
      render();
      await hooks.flush();
      resolveList({success: false, status: 503});
      await hooks.flush();
      assert.equal(need(render()), undefined, kind);
      assert.ok(__reads.every(call => !call.options.method || call.options.method === "GET"));
    } finally { hooks.dispose(); }
  }
});
