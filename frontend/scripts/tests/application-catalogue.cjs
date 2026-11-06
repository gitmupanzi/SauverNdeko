// Classification issue de la base, groupes et vrais handlers de licence ; API/DOM simulés.
const path=require('node:path'),Module=require('node:module'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../..'),front=path.join(root,'frontend'),esbuild=require(path.join(front,'node_modules/esbuild'));let checks=0;
const eq=(a,b)=>{assert.deepEqual(a,b);checks++;},ok=value=>{assert(value);checks++;};
function fixtures(entries){return{name:'fixtures',setup(build){for(const[filter,name,source]of entries){build.onResolve({filter},()=>({path:name,namespace:name}));build.onLoad({filter:/.*/,namespace:name},()=>({contents:source,loader:'jsx',resolveDir:front}));}}};}
async function bundle(contents,entries=[]){const result=await esbuild.build({stdin:{contents,resolveDir:front,loader:'jsx'},bundle:true,jsx:'automatic',external:['react','react/jsx-runtime'],platform:'node',format:'cjs',write:false,define:{'import.meta.env':'{}'},loader:{'.css':'empty'},plugins:[fixtures(entries)],logLevel:'error'});const module=new Module(path.join(front,'catalogue-proof.cjs'));module.filename=path.join(front,'catalogue-proof.cjs');module.paths=Module._nodeModulePaths(front);module._compile(result.outputFiles[0].text,module.filename);return module.exports;}
class Hooks{constructor(){this.slots=[];this.cursor=0;this.queue=[];}state(value){const i=this.cursor++;if(!this.slots[i])this.slots[i]={value:typeof value==='function'?value():value};return[this.slots[i].value,next=>this.slots[i].value=typeof next==='function'?next(this.slots[i].value):next];}ref(value){const i=this.cursor++;if(!this.slots[i])this.slots[i]={current:value};return this.slots[i];}id(){return 'catalogue-'+this.cursor++;}memo(value,deps=[]){const i=this.cursor++,old=this.slots[i];if(!old||deps.some((v,j)=>!Object.is(v,old.deps[j])))this.slots[i]={deps,value};return this.slots[i].value;}effect(fn,deps=[]){const i=this.cursor++,old=this.slots[i];if(!old||deps.some((v,j)=>!Object.is(v,old.deps[j])))this.queue.push(()=>{old?.clean?.();this.slots[i]={deps,clean:fn()};});}render(component,props={}){this.cursor=0;globalThis.__hooks=this;return component(props);}async flush(){for(const effect of this.queue.splice(0))effect();await new Promise(resolve=>setImmediate(resolve));await new Promise(resolve=>setImmediate(resolve));}unmount(){this.slots.forEach(slot=>slot?.clean?.());}}
function nodes(node,out=[]){if(!node||typeof node!=='object')return out;if(Array.isArray(node)){node.forEach(n=>nodes(n,out));return out;}if(node.type)out.push(node);if(node.type?.name==='OfferModules')return nodes(node.type(node.props),out);for(const key of ['children','action'])nodes(node.props?.[key],out);return out;}
const named=(tree,name)=>nodes(tree).find(node=>node.type?.name===name),text=node=>typeof node==='string'||typeof node==='number'?String(node):Array.isArray(node)?node.map(text).join(''):node?.type?.name==='OfferModules'?text(node.type(node.props)):node?.props?text(node.props.children):'';
const hooks=`export const useState=v=>globalThis.__hooks.state(v),useRef=v=>globalThis.__hooks.ref(v),useId=()=>globalThis.__hooks.id(),useEffect=(f,d)=>globalThis.__hooks.effect(f,d),useCallback=(f,d)=>globalThis.__hooks.memo(f,d);`;
const moduleCard = (key, label, path, extra={}) => ({
  key, label, path, type:'MODULE', commercialisable:false, base:false, platformOnly:false, canRead:true, ...extra,
});
const catalogue = [
  moduleCard('produits','Produits','/produits',{base:true,description:'Consulter les produits'}),
  moduleCard('structures','Structures','/pharmacies',{base:true}),
  moduleCard('professionnels','Professionnels','/experts',{base:true}),
  moduleCard('logistique','Logistique','/logistique',{commercialisable:true,description:'Stock et commandes'}),
  moduleCard('discussions','Discussions','/discussions',{commercialisable:true}),
  moduleCard('caisse','Caisse','/caisse',{commercialisable:true,canRead:false}),
  moduleCard('support','Support','/support',{commercialisable:true,canRead:false}),
  moduleCard('guide','Guide utilisateur','/guide',{type:'FONCTIONNALITE',base:true}),
  moduleCard('referentiels','Référentiels','/referentiels',{type:'FONCTIONNALITE',base:true}),
  moduleCard('territoires','Organisation territoriale','/territoires',{platformOnly:true}),
];
const retiredHealth = moduleCard('sante','Informations santé','/maladies',{type:'FONCTIONNALITE'});
const visible = catalogue.filter(row => row.canRead);
const customer = catalogue.filter(row => !row.platformOnly);
const headings = tree => nodes(tree).filter(node => node.type === 'h2').map(text);
const action = (tree,label) => nodes(tree).find(node => node.type?.name === 'Button' && node.props.children === label);
const links = tree => nodes(tree).filter(node => node.type?.name === 'Link').map(node => node.props.to);
const licenceSwitch = (tree, label) => nodes(tree).find(node => node.type === 'input' && node.props.role === 'switch' && node.props['aria-label'].startsWith('Activer '+label+' '));
const common=[[/^react$/,'hooks',hooks],[/^react-router-dom$/,'router',`export function Link(){}export const useLocation=()=>({pathname:'/abonnements',search:'',hash:''}),useNavigate=()=>()=>{};`],[/\/contexts\/AuthContext$/,'auth',`export const useAuth=()=>({user:globalThis.__user,refreshUser:async()=>({success:true})});`],[/\/services\/api$/,'api',`export const requestJson=(path,options)=>globalThis.__request(path,options);`],[/\/components\/AccountControls$/,'account',`export default function Account(){}`],[/\/components\/ModuleHeader$/,'header',`export default function Header(){}`],[/\/components\/DrawerDialog$/,'dialog',`export default function Dialog(){}`],[/\/components\/SearchSelect$/,'select',`export default function Select(){}`],[/\/components\/ActionButton$/,'button',`export default function Button(){}`],[/\/components\/AppIcon$/,'icon',`export default function Icon(){}`],[/\.\/logistique\/logistiqueShared$/,'format',`export const formatDate=value=>String(value);`]];
globalThis.window={addEventListener(){},removeEventListener(){},dispatchEvent(){}};
(async()=>{
  const domain = await bundle("export * from './src/services/applicationCatalogue';");
  eq(domain.applicationGroups([...catalogue,retiredHealth]).map(group=>[group.key,group.total,group.accessible]),
    [['included',3,3],['licensed',4,2],['features',2,2],['platform',1,1]]);
  eq(domain.applicationGroups([...catalogue,retiredHealth],'santé').flatMap(group=>group.items),[]);
  eq(domain.applicationGroupCount(domain.applicationGroups(catalogue,'stock')[1],'stock'),'1 sur 4 modules');
  eq(domain.applicationRetired({CodeModule:'sante'}),true);
  eq(domain.applicationRetired({path:'/maladies'}),true);
  ok(domain.applicationClassificationValid(catalogue[0]));
  eq(domain.applicationClassificationValid({...catalogue[7],commercialisable:true}),false);
  eq(domain.applicationClassificationValid({type:'MODULE'}),false);

  globalThis.__user={IdUser:2,IdEntiteFk:7,moduleAccess:{platformAdmin:true},permissions:{canAccessAdmin:true}};
  globalThis.__request=async()=>({success:true,data:[...visible,retiredHealth]});
  const home = await bundle("export {default} from './src/pages/WorkspaceHome';",common);
  const hh=new Hooks(), hr=()=>hh.render(home.default);
  hr(); await hh.flush(); let tree=hr();
  eq(headings(tree),['Modules inclus','Modules sur licence','Fonctionnalités associées','Administration de la plateforme']);
  ok(text(tree).includes('3 modules'));
  ok(text(tree).includes('2 modules'));
  ok(text(tree).includes('2 fonctionnalités'));
  ok(links(tree).includes('/referentiels'));
  ok(links(tree).includes('/territoires'));
  ok(!links(tree).includes('/catalogue'));
  ok(!links(tree).includes('/maladies'));
  ok(!links(tree).includes('/caisse'));
  nodes(tree).find(node=>node.type==='input'&&node.props.id==='workspace-search').props.onChange({target:{value:'Guide'}});
  tree=hr();
  ok(text(tree).includes('0 sur 3 modules'));
  ok(text(tree).includes('1 sur 2 fonctionnalités'));
  globalThis.__user={...__user,IdEntiteFk:8};
  eq(nodes(hr()).filter(node=>node.props?.className?.startsWith('workspace-app ')).length,0);
  hh.unmount();

  // Un délai de lecture ne laisse pas le lanceur vide et sa réponse tardive est ignorée.
  globalThis.__user={...__user,IdEntiteFk:7};
  let timedOut,signal,resolveLate;
  const nativeTimer=globalThis.setTimeout,nativeClear=globalThis.clearTimeout;
  globalThis.setTimeout=(fn,delay,...args)=>delay===15000?(timedOut=fn,'workspace-deadline'):nativeTimer(fn,delay,...args);
  globalThis.clearTimeout=id=>id==='workspace-deadline'?undefined:nativeClear(id);
  globalThis.__request=(_,options)=>{signal=options.signal;return new Promise(resolve=>{resolveLate=resolve;});};
  const slow=new Hooks(),sr=()=>slow.render(home.default);
  sr(); await slow.flush(); tree=sr();
  eq(named(tree,'ListState').props.loading,true);
  eq(signal.aborted,false);
  timedOut(); tree=sr();
  eq(signal.aborted,true);
  eq(named(tree,'ListState').props.role,'alert');
  resolveLate({success:true,data:visible}); await slow.flush(); tree=sr();
  eq(named(tree,'ListState').props.role,'alert');
  globalThis.__request=async()=>({success:true,data:visible});
  action(tree,'Réessayer').props.onClick();
  sr(); await slow.flush(); tree=sr();
  eq(nodes(tree).filter(node=>node.props?.className?.startsWith('workspace-app ')).length,visible.length);
  slow.unmount(); globalThis.setTimeout=nativeTimer; globalThis.clearTimeout=nativeClear;

  globalThis.__request=()=>Promise.reject(Error('offline'));
  const failed=new Hooks(),fr=()=>failed.render(home.default);
  fr(); await failed.flush(); tree=fr();
  eq(named(tree,'ListState').props.title,'Vos applications sont indisponibles');
  globalThis.__request=async()=>({success:true,data:visible});
  action(tree,'Réessayer').props.onClick(); fr(); await failed.flush(); tree=fr();
  nodes(tree).find(node=>node.type==='input'&&node.props.id==='workspace-search').props.onChange({target:{value:'inconnu'}});
  tree=fr(); eq(named(tree,'ListState').props.role,'status');
  let searchFocus;
  nodes(tree).find(node=>node.props['aria-label']==='Effacer la recherche').props.onClick({
    currentTarget:{closest:()=>({querySelector:()=>({focus:options=>searchFocus=options})})},
  });
  eq(searchFocus,{preventScroll:true}); eq(nodes(fr()).filter(node=>node.props?.className?.startsWith('workspace-app ')).length,visible.length);
  failed.unmount();

  globalThis.__user={...__user,moduleAccess:{platformAdmin:false}};
  globalThis.__request=async()=>({success:true,data:{modules:customer}});
  const app=await bundle("export {default} from './src/pages/Applications';",common);
  const ah=new Hooks(),ar=()=>ah.render(app.default); ar(); await ah.flush(); tree=ar();
  eq(headings(tree),['Modules inclus','Modules sur licence','Fonctionnalités associées']);
  ok(text(tree).includes('4 modules · 2 accessibles'));
  ok(text(tree).includes('Disponible sur licence.'));
  ok(links(tree).includes('/referentiels'));
  ok(!links(tree).includes('/territoires'));
  nodes(tree).find(node=>node.type==='input'&&node.props.type==='search').props.onChange({target:{value:'Stock'}});
  tree=ar(); ok(text(tree).includes('1 sur 4 modules · 1 accessible'));
  ok(text(tree).includes('0 sur 2 fonctionnalités · 0 accessibles'));
  ah.unmount();

  const categories=customer.filter(row=>row.key!=='referentiels').map(row=>({
    ...row,CodeModule:row.key,Nom:row.label,EstSocle:row.base,Actif:true,
  }));
  const moduleCodes=categories.filter(row=>row.commercialisable).map(row=>row.CodeModule);
  const activeLogistique={CodeModule:'logistique',Actif:true,Version:3,EstAccesActif:true,EtatAcces:'Actif'};
  const offer={entityId:7,canManage:true,catalogue:categories,moduleCodes,effectiveModules:['logistique','caisse'],
    licences:[{IdLicence:1,statut_licence:'Active',DateDebut:'2026-01-01',DateFin:'2031-01-01',activations:[activeLogistique]},
      {IdLicence:2,statut_licence:'Active',activations:[{CodeModule:'caisse',Actif:true,Version:1,EstAccesActif:true,EtatAcces:'Actif'}]}]};
  const roleData={entityId:7,canManage:true,catalogue:categories,roles:[{IdRoleFk:9,NomRole:'Manager',permissions:[],
    baseline:Object.fromEntries(categories.map(row=>[row.CodeModule,{canRead:true,canManage:true,canExport:true}]))}]};
  const licence=await bundle("export {default} from './src/pages/ApplicationLicences';",common);
  globalThis.__writes=[];
  globalThis.__request=async(path,options={})=>{
    if(options.method){__writes.push({path,options});return {success:true,data:offer};}
    return {success:true,data:path.includes('/organisations')?[{IdEntite:7,NomEntite:'Entreprise A',ValideEntite:true}]:path.includes('/licences')?offer:roleData};
  };
  globalThis.__user={...__user,moduleAccess:{platformAdmin:true}};
  const lh=new Hooks(),lr=()=>lh.render(licence.default);
  for(let i=0;i<4;i++){lr(); await lh.flush();} tree=lr();
  eq(nodes(tree).filter(node=>node.type==='h3').map(text),['Modules sur licence','Modules inclus']);
  eq(nodes(tree).filter(node=>node.type==='input'&&node.props.role==='switch').length,4);
  ok(text(tree).includes('Accès actif via une autre licence'));
  eq(licenceSwitch(tree,'Logistique').props.checked,true);
  eq(licenceSwitch(tree,'Caisse').props.checked,false);
  eq(licenceSwitch(tree,'Produits'),undefined);
  licenceSwitch(tree,'Logistique').props.onChange({target:{checked:false}});
  licenceSwitch(tree,'Discussions').props.onChange({target:{checked:true}});
  tree=lr(); ok(text(tree).includes('À désactiver')); ok(text(tree).includes('À activer'));
  action(tree,'Appliquer les changements').props.onClick();
  tree=lr(); eq(__writes.length,0);
  const review=named(tree,'Dialog');
  eq(review.props.title,'Appliquer les changements');
  ok(text(review).includes('Désactiver Logistique')); ok(text(review).includes('Activer Discussions'));
  action(review.props.footer,'Confirmer').props.onClick();
  await lh.flush();
  eq(__writes.length,1);
  eq(__writes[0].path,'/api/workspace/licences/1/modules');
  eq(JSON.parse(__writes[0].options.body),{
    enabled:['discussions'],versions:{logistique:3,discussions:0,caisse:0,support:0},
  });
  lh.unmount();

  globalThis.__user={...__user,moduleAccess:{platformAdmin:false}};
  const rh=new Hooks(),rr=()=>rh.render(licence.default);
  for(let i=0;i<4;i++){rr(); await rh.flush();} tree=rr();
  eq(nodes(tree).filter(node=>node.type==='input'&&node.props.role==='switch').length,0);
  ok(text(tree).includes('Les activations sont gérées par l’administration de la plateforme.'));
  eq(action(tree,'Appliquer les changements'),undefined);
  rh.unmount();
  console.log(JSON.stringify({success:true,checks,coverage:['Quatre groupes et recherche','Accès par entreprise et affichage licence','Activation et désactivation confirmées','Modifications interdites à un administrateur d’entreprise'],limits:['API et DOM simulés']}));
})().catch(error=>{console.error(error);process.exitCode=1;});
