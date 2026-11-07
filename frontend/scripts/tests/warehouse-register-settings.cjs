// Vrais handlers des éditeurs ; doubles de transport et de DOM, aucune écriture applicative.
const path=require('node:path'),fs=require('node:fs'),Module=require('node:module'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../..'),front=path.join(root,'frontend'),esbuild=require(path.join(front,'node_modules/esbuild'));
let checks=0;const eq=(a,b)=>{assert.deepEqual(a,b);checks++;},ok=(value,message)=>{assert(value,message);checks++;};
const tick=()=>new Promise(resolve=>setImmediate(resolve));
class Hooks {
 constructor(){this.slots=[];this.cursor=0;this.queue=[];}
 state(value){const i=this.cursor++;if(!this.slots[i])this.slots[i]={value:typeof value==='function'?value():value};return[this.slots[i].value,next=>{this.slots[i].value=typeof next==='function'?next(this.slots[i].value):next;}];}
 ref(value){const i=this.cursor++;if(!this.slots[i])this.slots[i]={current:value};return this.slots[i];}
 id(){return'proof-'+this.cursor++;}
 effect(fn,deps=[]){const i=this.cursor++,old=this.slots[i];if(!old||deps.some((value,j)=>!Object.is(value,old.deps[j])))this.queue.push(()=>{old?.clean?.();this.slots[i]={deps,clean:fn()};});}
 render(component,props){this.cursor=0;globalThis.__hooks=this;return component(props);}
 async flush(){for(const fn of this.queue.splice(0))fn();await tick();await tick();}
 unmount(){this.slots.forEach(slot=>slot?.clean?.());}
}
function nodes(node,out=[]){if(!node||typeof node!=='object')return out;if(Array.isArray(node)){node.forEach(child=>nodes(child,out));return out;}if(node.type)out.push(node);nodes(node.props?.children,out);return out;}
const named=(tree,name)=>nodes(tree).find(node=>node.type?.name===name);
const control=(tree,key)=>nodes(tree).find(node=>node.props.id?.endsWith(key)&&typeof node.props.onChange==='function');
async function bundle(contents,plugins=[]){const result=await esbuild.build({stdin:{contents,resolveDir:front,loader:'jsx'},bundle:true,write:false,platform:'node',format:'cjs',external:['react/jsx-runtime'],jsx:'automatic',define:{'import.meta.env':'{}'},loader:{'.css':'empty'},plugins,logLevel:'error'});const compiled=new Module(path.join(front,'draft-editors-proof.cjs'),module);compiled.filename=path.join(front,'draft-editors-proof.cjs');compiled.paths=Module._nodeModulePaths(front);compiled._compile(result.outputFiles[0].text,compiled.filename);return compiled.exports;}
function mocks(entries){return{name:'editor-fixtures',setup(build){for(const[filter,name,source]of entries){build.onResolve({filter},()=>({path:name,namespace:name}));build.onLoad({filter:/.*/,namespace:name},()=>({contents:source,loader:'jsx',resolveDir:front}));}}};}

globalThis.__scope={scopeKey:'company-7',canWrite:true};globalThis.__depot={depotId:'2',retry(){}};
globalThis.__user={IdUser:3,Is_Admin:true,permissions:{canExportData:true,canWriteData:true}};
globalThis.__canExport=true;globalThis.__downloads=[];globalThis.__download=async()=>{};
globalThis.__prefs={ready:true,canExport:true,exportKeys:['NomDepot','CodeDepot'],tableKeys:['NomDepot','CodeDepot'],catalogue:[],contextKey:'company-7',error:''};
const common=[
 [/^react$/,'hooks',`export const useState=v=>globalThis.__hooks.state(v),useRef=v=>globalThis.__hooks.ref(v),useId=()=>globalThis.__hooks.id(),useEffect=(f,d)=>globalThis.__hooks.effect(f,d),useMemo=f=>f();`],
 [/\/contexts\/EntityScopeContext$/,'scope',`export const useEntityScope=()=>globalThis.__scope;`],
 [/\/contexts\/AuthContext$/,'auth',`export const useAuth=()=>({user:globalThis.__user});`],
 [/\/contexts\/DepotScopeContext$/,'depot',`export const useDepotScope=()=>globalThis.__depot;export function DepotField(){}`],
 [/\/services\/moduleAccess$/,'rights',`export const moduleRights=()=>({canExport:globalThis.__canExport});`],
 [/\/services\/api$/,'api',`export const downloadApiFile=async(url,options)=>{globalThis.__downloads.push({url,...options});return globalThis.__download(url,options);};export const requestJson=async()=>({success:true,data:[],meta:{filteredCount:0}});`],
 [/\.\/useTablePreferences$/,'preferences',`export default function usePreferences(){return globalThis.__prefs;}`]
];
(async()=>{
 const {useSettings}=await bundle("export {default as useSettings} from './src/hooks/useLogisticsRegisterSettings';",[mocks(common)]);
 let opts={query:{q:'central',actif:'all',depotId:'2'},grid:{take:25,skip:50,sortBy:'NomDepot',sortDir:'desc'},count:121};
 const hook=new Hooks(),render=()=>hook.render(()=>useSettings('depots',opts));let tools=render();await hook.flush();tools=render();eq(tools.columnsOpen,false);tools.open();eq(render().columnsOpen,true);tools.close();eq(render().columnsOpen,false);ok(!tools.toolbarProps.exportDisabled);await render().toolbarProps.exportFile();eq(globalThis.__downloads.length,1);
 let request=globalThis.__downloads[0],url=new URL(request.url,'https://example.invalid');eq(url.pathname,'/api/logistique/depots/export.xlsx');eq(url.searchParams.get('q'),'central');eq(url.searchParams.get('depotId'),'2');eq(url.searchParams.get('columns'),'["NomDepot","CodeDepot"]');eq(url.searchParams.has('take'),false);eq(url.searchParams.has('skip'),false);eq(url.searchParams.get('sortDir'),'desc');await render().toolbarProps.exportCsv();ok(globalThis.__downloads.at(-1).url.includes('/export.csv?'));
 for(const patch of [{loading:true},{pending:true},{error:'Non disponible'},{count:0}]){opts={...opts,...patch};const before=globalThis.__downloads.length;tools=render();ok(tools.toolbarProps.exportDisabled);await tools.toolbarProps.exportFile();eq(globalThis.__downloads.length,before);opts={...opts,loading:false,pending:false,error:'',count:121};}
 globalThis.__canExport=false;eq(render().toolbarProps.exportFile,undefined);globalThis.__canExport=true;globalThis.__prefs={...globalThis.__prefs,ready:false};ok(render().toolbarProps.exportDisabled);globalThis.__prefs={...globalThis.__prefs,ready:true};
 globalThis.__download=async()=>{throw new Error('Fichier indisponible');};await render().toolbarProps.exportFile();eq(render().toolbarProps.error,'Fichier indisponible');globalThis.__download=()=>new Promise(()=>{});render().toolbarProps.exportFile();request=globalThis.__downloads.at(-1);ok(!request.signal.aborted);globalThis.__scope={...globalThis.__scope,scopeKey:'company-8'};render();await hook.flush();eq(request.signal.aborted,true);eq(render().columnsOpen,false);hook.unmount();
 const entries=[...common,
 [/\/hooks\/useLogisticsRegisterSettings$/,'settings-hook',`export default function useSettings(kind){return{preferences:globalThis.__prefs,columnsOpen:false,columnsAnchorRef:{current:null},tableProps:{tablePreferences:globalThis.__prefs,columnsPanelOpen:false},toolbarProps:{showSettings:false,exportFile(){},exportCsv(){}},open(){globalThis.__opened=kind;}};}`],
 [/\/components\/ConsultationProvider$/,'consult',`export const useConsultations=()=>({openProduct(){}});`],
 [/\/components\/RegisterSettingsButton$/,'settings',`export default function SettingsButton(){}`],
 [/\/components\/RegisterSurface$/,'surface',`export default function Surface(){}`],
 [/\/components\/RecordEditorFrame$/,'frame',`export default function Frame(){}`],
 [/\/components\/ActionButton$/,'button',`export default function Button(){}`],
 [/\/components\/RowActionsMenu$/,'actions',`export default function Actions(){}`],
 [/\/components\/DataTableToolbar$/,'toolbar',`export default function Toolbar(){}`],
 [/\/components\/SearchSelect$/,'select',`export default function Select(){}`],
 [/\/components\/BusinessDocuments$/,'documents',`export default function Documents(){}`],
 [/\/components\/LotFields$/,'lots',`export default function Lots(){}`],
 [/\.\/(InventoryEditor|InventoryCancellation|UnitPrecisionEditor)$/,'editors',`export default function Editor(){}`],
 [/\.\/logistiqueShared$/,'shared',`export function SimpleTable(){};export function StatusBanner(){};export const formatDate=x=>x,formatNumber=x=>x;`],
 [/\/services\/depots$/,'transport',`export const depotRead=async()=>({success:true,data:[],meta:{filteredCount:0}}),depotFailure=(r,f)=>f;export function depotWrite(){};export function depotRecord(){};export function depotRevision(){};export function depotUncertain(){};`]
 ];
 const pages=await bundle("export {default as Depots} from './src/pages/logistique/Depots';export {default as StocksDepots} from './src/pages/logistique/StocksDepots';export {default as Transferts} from './src/pages/logistique/Transferts';export {default as Inventaires} from './src/pages/logistique/Inventaires';",[mocks(entries)]);
 for(const [page,kind]of [['Depots','depots'],['StocksDepots','stocks-depots'],['Transferts','transferts'],['Inventaires','inventaires']]){const h=new Hooks();let tree=h.render(pages[page],{});await h.flush();tree=h.render(pages[page],{});const table=named(tree,'SimpleTable');ok(table,page+' table');eq(table.props.tablePreferences,globalThis.__prefs);ok(table.props.showControls!==false);const toolbar=table.props.toolbar;eq(toolbar.type.name,'Toolbar');eq(toolbar.props.showSettings,false);ok(typeof toolbar.props.exportFile==='function');ok(typeof toolbar.props.exportCsv==='function');const surface=named(tree,'Surface');const actionTree=page==='Inventaires'?tree:surface.props.actions;const settings=named(actionTree,'SettingsButton');ok(settings,page+' header settings');settings.props.onTableSettings();eq(globalThis.__opened,kind);h.unmount();}
 console.log(JSON.stringify({success:true,checks,scope:'Réglages des quatre registres, export exhaustif et droits, erreurs, changement entreprise; handlers simulés sans écriture métier'}));
})().catch(error=>{console.error(error);process.exit(1);});
