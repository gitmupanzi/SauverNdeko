// Contexte entreprise réel, réseau simulé ; aucun droit ou compte enregistré.
const path=require('node:path'),Module=require('node:module'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../..'),front=path.join(root,'frontend'),esbuild=require(path.join(front,'node_modules/esbuild'));let checks=0;
const eq=(a,b)=>{assert.deepEqual(a,b);checks++;},ok=value=>{assert(value);checks++;};
class Hooks{constructor(){this.slots=[];this.cursor=0;this.queue=[];}state(initial){const index=this.cursor++;if(!this.slots[index])this.slots[index]={value:typeof initial==='function'?initial():initial};return[this.slots[index].value,value=>{this.slots[index].value=typeof value==='function'?value(this.slots[index].value):value;}];}memo(fn,deps){const index=this.cursor++,old=this.slots[index];if(!old||deps.some((v,i)=>!Object.is(v,old.deps[i])))this.slots[index]={deps,value:fn()};return this.slots[index].value;}effect(fn,deps=[]){const i=this.cursor++,old=this.slots[i];if(!old||deps.some((v,j)=>!Object.is(v,old.deps[j])))this.queue.push(()=>{old?.clean?.();this.slots[i]={deps,clean:fn()};});}render(Component,props={}){this.cursor=0;globalThis.__h=this;return Component(props);}async flush(){for(const fn of this.queue.splice(0))fn();await new Promise(resolve=>setImmediate(resolve));await new Promise(resolve=>setImmediate(resolve));}unmount(){this.slots.forEach(slot=>slot?.clean?.());}}
function fixture(entries){return{name:'fixtures',setup(build){for(const[filter,name,source]of entries){build.onResolve({filter},()=>({path:name,namespace:name}));build.onLoad({filter:/.*/,namespace:name},()=>({contents:source,loader:'jsx',resolveDir:front}));}}};}
async function compile(contents,entries){const result=await esbuild.build({stdin:{contents,resolveDir:front,loader:'jsx'},bundle:true,jsx:'automatic',external:['react','react/jsx-runtime'],platform:'node',format:'cjs',write:false,loader:{'.css':'empty'},plugins:[fixture(entries)],logLevel:'error'});const compiled=new Module(path.join(front,'admin-context-proof.cjs'),module);compiled.filename=path.join(front,'admin-context-proof.cjs');compiled.paths=Module._nodeModulePaths(front);compiled._compile(result.outputFiles[0].text,compiled.filename);return compiled.exports;}
globalThis.document={querySelector:()=>globalThis.__dialog?{}:null};globalThis.__dialog=false;globalThis.__calls=[];globalThis.__configured=[];globalThis.__deferred=[];globalThis.__delay=false;
const rows=[{id:7,label:'Société A',active:true},{id:8,label:'Société B',active:true},{id:9,label:'Société archivée',active:false}];
globalThis.__response={success:true,data:rows};
const rights=(admin=true,logistique=false)=>({administration:{canRead:admin,canManage:admin,canExport:admin},logistique:{canRead:logistique,canManage:logistique,canExport:logistique}});
globalThis.__auth={isAuthenticated:true,user:{IdUser:1,Is_Admin:true,permissions:{canWriteData:true},moduleAccess:{modules:rights()}}};
(async()=>{
 const p=await compile("export {EntityScopeProvider} from './src/contexts/EntityScopeContext';",[
 [/^react$/,'hooks',`export const createContext=()=>({Provider:function Provider(){}}),useContext=()=>{},useState=v=>globalThis.__h.state(v),useMemo=(f,d)=>globalThis.__h.memo(f,d),useEffect=(f,d)=>globalThis.__h.effect(f,d),useLayoutEffect=(f,d)=>globalThis.__h.effect(f,d);`],
 [/\.\/AuthContext$/,'auth',`export const useAuth=()=>globalThis.__auth;`],
 [/\/services\/api$/,'api',`export async function requestJson(url){globalThis.__calls.push(url);if(globalThis.__delay)return new Promise(resolve=>globalThis.__deferred.push(resolve));return globalThis.__response;}`],
 [/\/services\/entityScope$/,'transport',`export function configureEntityScope(value){globalThis.__configured.push(value);}`],
 ]);
 const h=new Hooks(),render=()=>h.render(p.EntityScopeProvider),value=()=>render().props.value;
 render();await h.flush();eq(globalThis.__calls.at(-1),'/api/systeme/administration/entreprises');eq(value().entities,rows);eq(value().canWrite,false);eq(value().globalAdmin,true);eq(value().entityId,'');
 value().selectEntity('7');await h.flush();eq(value().entityId,'7');ok(value().scopeKey.includes(':7:'));eq(value().canWrite,false);render();await h.flush();eq(globalThis.__configured.at(-1).entityId,'7');
 value().selectEntity('999');eq(value().entityId,'7');value().selectEntity('9');eq(value().entityId,'7');globalThis.__dialog=true;value().selectEntity('8');eq(value().entityId,'7');globalThis.__dialog=false;value().selectEntity('');eq(value().entityId,'');
 globalThis.__auth={isAuthenticated:true,user:{IdUser:2,IdEntiteFk:8,Is_Admin:false,permissions:{canWriteData:true},moduleAccess:{modules:rights()}}};render();await h.flush();eq(value().globalAdmin,false);eq(value().entityId,'8');value().selectEntity('7');eq(value().entityId,'8');
 globalThis.__auth={...globalThis.__auth,user:{...globalThis.__auth.user,moduleAccess:{modules:rights(false,true)}}};render();await h.flush();eq(globalThis.__calls.at(-1),'/api/logistique/entreprises');eq(value().canWrite,true);
 globalThis.__auth={...globalThis.__auth,user:{...globalThis.__auth.user,moduleAccess:{modules:{...rights(false,false),support:{canRead:true,canManage:true,canExport:true}}}}};render();await h.flush();eq(globalThis.__calls.at(-1),'/api/support/entreprises');eq(value().entities,rows);eq(value().canWrite,false);eq(value().entityId,'8');
 globalThis.__auth={...globalThis.__auth,user:{...globalThis.__auth.user,permissions:{canWriteData:false}}};render();await h.flush();eq(value().canWrite,false);
 globalThis.__response={success:false,message:'Indisponible'};value().retry();render();await h.flush();eq(value().error,'Indisponible');eq(value().entities,[]);
 globalThis.__delay=true;value().retry();render();await h.flush();eq(value().loading,true);globalThis.__auth={isAuthenticated:false,user:null};render();await h.flush();globalThis.__deferred.shift()({success:true,data:rows});await h.flush();eq(value().entities,[]);eq(value().entityId,'');eq(value().canWrite,false);h.unmount();
 const header=await compile("export {default} from './src/components/ModuleHeader';",[
 [/\/contexts\/AuthContext$/,'header-auth',`export const useAuth=()=>({user:{permissions:{}}});`],
 [/\.\/EntityScopePicker$/,'picker',`export default function Picker(){}`],
 [/\.\/AccountControls$/,'account',`export default function Account(){}`],
 [/\.\/AppIcon$/,'icon',`export default function Icon(){}`],
 [/^react-router-dom$/,'links',`export function Link(){}`],
 ]);
 for(const title of ['Administration','Logistique','Référentiels','Support']){const tree=header.default({title}),children=tree.props.children.flat().filter(Boolean);ok(children.some(node=>node.type?.name==='Picker'));}
 const transport=await compile("export * from './src/services/entityScope';",[]);
 transport.configureEntityScope({userId:'1',entityId:'7',globalAdmin:true});
 for(const route of ['/api/systeme/administration/synthese','/api/systeme/administration/registres/licences?take=2','/api/systeme/administration/saisie-multiple/utilisateurs','/api/systeme/utilisateurs','/api/systeme/entites/7','/api/systeme/licences/4','/api/systeme/fk-correspondances','/api/systeme/admin-ui-settings','/api/systeme/personnel/references','/api/logistique/articles','/api/support/tickets/12/documents','/api/tableaux/support.tickets/preferences','/api/referentiel/champs-references','/api/tableaux/admin.utilisateurs/preferences']){const snapshot=transport.captureEntityScope(route);eq(snapshot.scoped,true);eq(snapshot.headers,{'X-Entite-ID':'7'});}
 for(const route of ['/api/systeme/administration-autre','/api/public/articles','/SauverNdeko/auth/me','https://example.invalid/api/systeme/administration'])eq(transport.captureEntityScope(route).headers,{});
 const snapshot=transport.captureEntityScope('/api/systeme/administration/synthese');eq(transport.entityScopeIsCurrent(snapshot),true);transport.configureEntityScope({userId:'1',entityId:'8',globalAdmin:true});eq(transport.entityScopeIsCurrent(snapshot),false);transport.configureEntityScope({userId:'2',entityId:'8',globalAdmin:false});eq(transport.captureEntityScope('/api/systeme/administration/synthese').headers,{});
 console.log(JSON.stringify({success:true,checks,scope:'Contexte entreprise sans licence Logistique, droits conservés, réponses obsolètes et en-tête partagés'}));
})().catch(error=>{console.error(error);process.exit(1);});
