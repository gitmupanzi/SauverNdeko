// Vrais handlers React avec DOM simulé, sans navigateur ni requête applicative.
const fs=require('node:fs'),path=require('node:path'),Module=require('node:module'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../..'),front=path.join(root,'frontend'),esbuild=require(path.join(front,'node_modules/esbuild'));let checks=0;
function eq(actual,expected){assert.deepEqual(actual,expected);checks++;}function ok(value,message){assert(value,message);checks++;}
class Hooks{constructor(){this.slots=[];this.cursor=0;this.effects=[];}state(v){const i=this.cursor++;if(!this.slots[i])this.slots[i]={value:typeof v==='function'?v():v};return[this.slots[i].value,next=>this.slots[i].value=typeof next==='function'?next(this.slots[i].value):next];}ref(v){const i=this.cursor++;return this.slots[i]||(this.slots[i]={current:v});}effect(fn,deps=[]){const i=this.cursor++,old=this.slots[i];if(!old||deps.some((v,j)=>!Object.is(v,old.deps[j])))this.effects.push(()=>{old?.clean?.();this.slots[i]={deps,clean:fn()};});}render(Component,props){this.cursor=0;globalThis.__navHooks=this;return Component(props);}flush(){for(const fn of this.effects.splice(0))fn();}unmount(){this.slots.forEach(slot=>slot?.clean?.());}}
function nodes(node,out=[]){if(!node||typeof node!=='object')return out;if(Array.isArray(node)){node.forEach(n=>nodes(n,out));return out;}if(node.type)out.push(node);nodes(node.props?.children,out);return out;}
function find(tree,predicate){const found=nodes(tree).find(predicate);assert(found,'Expected rendered element');return found;}
const group=(tree,name)=>find(tree,n=>n.type==='section'&&n.props['aria-label']===name),groupToggle=(tree,name)=>find(group(tree,name),n=>n.type==='button'),groupItems=(tree,name)=>find(group(tree,name),n=>n.props.className==='module-nav-items');
(async()=>{
 const result=await esbuild.build({stdin:{contents:"export {default as Sidebar} from './src/components/ModuleSidebar'; export {lockBodyScroll,unlockBodyScroll,isBodyScrollLocked} from './src/utils/bodyScrollLock';",resolveDir:front},bundle:true,write:false,platform:'node',format:'cjs',jsx:'automatic',loader:{'.css':'empty'},plugins:[{name:'doubles',setup(build){
  build.onResolve({filter:/^react$|^react\/jsx-runtime$|^react-router-dom$/},args=>({path:args.path,namespace:'fixture'}));
  build.onResolve({filter:/\/contexts\/AuthContext$/},()=>({path:'auth',namespace:'fixture'}));
  build.onResolve({filter:/^\.\/ModuleHeader$/},()=>({path:'header',namespace:'fixture'}));
  build.onLoad({filter:/^header$/,namespace:'fixture'},()=>({contents:'export default "Header";'}));
  build.onLoad({filter:/^auth$/,namespace:'fixture'},()=>({contents:'export const useAuth=()=>globalThis.__sidebarAuth;'}));
  build.onLoad({filter:/.*/,namespace:'fixture'},args=>({loader:'js',contents:args.path==='react'?`export const useState=v=>globalThis.__navHooks.state(v),useRef=v=>globalThis.__navHooks.ref(v),useId=()=>"nav-proof",useEffect=(f,d)=>globalThis.__navHooks.effect(f,d);export const createElement=(type,props,...children)=>({type,props:{...props,children:children.length===1?children[0]:children}});`:args.path==='react/jsx-runtime'?`export const jsx=(type,props,key)=>({type,props,key}),jsxs=jsx,Fragment='fragment';`:`export function Link(){return null;}`}));
 }}]});
 const loaded=new Module(path.join(front,'module-sidebar-proof.cjs'));loaded.filename=path.join(front,'module-sidebar-proof.cjs');loaded.paths=Module._nodeModulePaths(front);loaded._compile(result.outputFiles[0].text,loaded.filename);const {Sidebar,lockBodyScroll,unlockBodyScroll,isBodyScrollLocked}=loaded.exports;
 const storage=new Map(),events=new Map(),mediaEvents=new Map();globalThis.localStorage={getItem:key=>storage.get(key),setItem:(key,value)=>storage.set(key,value)};globalThis.requestAnimationFrame=fn=>fn();let mobile=false;globalThis.matchMedia=()=>({matches:mobile,addEventListener:(name,fn)=>mediaEvents.set(name,fn),removeEventListener:(name,fn)=>{if(mediaEvents.get(name)===fn)mediaEvents.delete(name);}});
 const focusNode=name=>({name,isConnected:true,getClientRects:()=>[1],focus(){globalThis.document.activeElement=this;}}),first=focusNode('first'),last=focusNode('last'),origin=focusNode('origin');
 globalThis.document={body:{style:{overflow:'auto'}},activeElement:origin,addEventListener:(name,fn)=>events.set(name,fn),removeEventListener:(name,fn)=>{if(events.get(name)===fn)events.delete(name);}};
 const selected=[];let toggles=0,closed=0;
 const moduleAccess={modules:{parametres:{canRead:true},administration:{canRead:true}}};
 globalThis.__sidebarAuth={isAuthenticated:true,user:{moduleAccess,permissions:{canAccessAdmin:true}}};
 const shortcuts=tree=>nodes(tree).find(node=>node.props?.className==='logistics-app-switcher');
 const props={title:'Administration',headerProps:null,storageKey:'test-navigation',activeKey:'users',onToggle:()=>toggles++,onNavigate:key=>selected.push(key),groups:[{label:'Accès',items:[{key:'users',label:'Utilisateurs',icon:'user'},{key:'roles',label:'Rôles',icon:'shield'}]},{label:'Vide',items:[]},{label:'Organisation',items:[{key:'entities',label:'Entreprises',icon:'building'},{key:'denied',label:'Interdit',hidden:true}]}]};
 function attach(tree){const aside=find(tree,n=>n.type==='aside');aside.props.ref.current={querySelectorAll:()=>[first,last],querySelector:()=>first};const btn=find(tree,n=>n.props.className==='logistics-sidebar-toggle');btn.props.ref.current=last;const search=nodes(tree).find(n=>n.type==='input'&&n.props['aria-label']==='Rechercher dans le menu');if(search)search.props.ref.current=first;}
 const sidebarToggle=tree=>find(tree,n=>n.props.className==='logistics-sidebar-toggle');
 function viewport(isMobile){mobile=isMobile;mediaEvents.get('change')?.({matches:isMobile});}
 const h=new Hooks();let tree=h.render(Sidebar,props);attach(tree);h.flush();
 eq(nodes(tree).filter(n=>n.type==='section').length,2);eq(nodes(tree).some(n=>n.props?.['aria-label']==='Interdit'),false);eq(find(tree,n=>n.props?.['aria-label']==='Utilisateurs').props['aria-current'],'page');eq(groupToggle(tree,'Accès').props['aria-expanded'],true);
 groupToggle(tree,'Organisation').props.onClick();tree=h.render(Sidebar,props);attach(tree);h.flush();eq(groupItems(tree,'Organisation').props.hidden,true);ok(storage.get('test-navigation.groups').includes('Organisation'));
 find(tree,n=>n.props?.['aria-label']==='Rôles').props.onClick();eq(selected,['roles']);
 tree=h.render(Sidebar,{...props,activeKey:'entities'});attach(tree);h.flush();tree=h.render(Sidebar,{...props,activeKey:'entities'});attach(tree);h.flush();eq(groupItems(tree,'Organisation').props.hidden,false);eq(find(tree,n=>n.props?.['aria-label']==='Entreprises').props['aria-current'],'page');
 groupToggle(tree,'Accès').props.onClick();tree=h.render(Sidebar,{...props,activeKey:'entities',collapsed:true});attach(tree);h.flush();eq(groupItems(tree,'Accès').props.hidden,false);ok(find(tree,n=>n.type==='aside').props.className.includes('is-collapsed'));
 eq(sidebarToggle(tree).props.children.props.name,'sidebar');eq(sidebarToggle(tree).props['aria-expanded'],false);sidebarToggle(tree).props.onClick();eq(toggles,1);
 eq(shortcuts(tree).props.children.map(item=>[item.props['aria-label'],item.props.to]),[['Paramètres','/parametres'],['Administration','/admin']]);eq(find(tree,n=>n.props?.className==='logistics-brand-lockup').props.to,'/espace');
 const authorized=globalThis.__sidebarAuth;
 globalThis.__sidebarAuth={...authorized,user:{moduleAccess,permissions:{canAccessAdmin:false}}};
 eq(shortcuts(h.render(Sidebar,props)).props.children.map(item=>item.props.to),['/parametres']);
 globalThis.__sidebarAuth={...authorized,user:{...authorized.user,moduleAccess:{modules:{administration:{canRead:true}}}}};
 eq(shortcuts(h.render(Sidebar,props)).props.children.map(item=>item.props.to),['/admin']);
 globalThis.__sidebarAuth={...authorized,user:{...authorized.user,moduleAccess:{modules:{administration:{canRead:false}}}}};
 eq(shortcuts(h.render(Sidebar,props)),undefined);
 globalThis.__sidebarAuth={...authorized,isAuthenticated:false};
 eq(shortcuts(h.render(Sidebar,props)),undefined);
 globalThis.__sidebarAuth=authorized;
 viewport(true);tree=h.render(Sidebar,{...props,activeKey:'entities',collapsed:false});attach(tree);h.flush();
 const mobileButton=sidebarToggle(tree);eq(mobileButton.props.children.props.name,'menu');eq(mobileButton.props['aria-label'],'Ouvrir le menu');eq(mobileButton.props['aria-expanded'],false);eq(mobileButton.props['aria-controls'],find(tree,n=>n.type==='aside').props.id);eq(groupItems(tree,'Accès').props.hidden,false);
 mobileButton.props.onClick();tree=h.render(Sidebar,{...props,activeKey:'entities',collapsed:true});attach(tree);h.flush();ok(find(tree,n=>n.type==='aside').props.className.includes('is-mobile-open'));eq(find(tree,n=>n.type==='aside').props['aria-modal'],true);eq(document.body.style.overflow,'hidden');eq(document.activeElement,last);eq(sidebarToggle(tree).props.children.props.name,'close');eq(sidebarToggle(tree).props['aria-label'],'Fermer le menu');eq(sidebarToggle(tree).props['aria-expanded'],true);eq(toggles,1);ok(events.has('keydown'));ok(nodes(tree).some(n=>n.props.className==='module-sidebar-backdrop'));
 groupToggle(tree,'Organisation').props.onClick();tree=h.render(Sidebar,{...props,activeKey:'entities',collapsed:true});attach(tree);h.flush();eq(groupItems(tree,'Organisation').props.hidden,true);
 let prevented=0;document.activeElement=last;events.get('keydown')({key:'Tab',preventDefault(){prevented++;}});eq(document.activeElement,first);eq(prevented,1);events.get('keydown')({key:'Tab',shiftKey:true,preventDefault(){prevented++;}});eq(document.activeElement,last);eq(prevented,2);
 events.get('keydown')({key:'Escape',preventDefault(){prevented++;}});tree=h.render(Sidebar,props);attach(tree);h.flush();eq(document.body.style.overflow,'auto');eq(events.has('keydown'),false);eq(document.activeElement,last);eq(nodes(tree).some(n=>n.props.className==='module-sidebar-backdrop'),false);eq(sidebarToggle(tree).props.children.props.name,'menu');h.unmount();eq(mediaEvents.has('change'),false);
 const overlay=new Hooks();tree=overlay.render(Sidebar,{...props,overlay:true,open:false,onClose:()=>closed++});attach(tree);overlay.flush();eq(find(tree,n=>n.type==='aside').props.inert,true);eq(find(tree,n=>n.type==='aside').props['aria-hidden'],true);
 tree=overlay.render(Sidebar,{...props,overlay:true,open:true,onClose:()=>closed++});attach(tree);overlay.flush();eq(find(tree,n=>n.type==='aside').props.role,'dialog');find(tree,n=>n.props?.['aria-label']==='Rôles').props.onClick();eq(closed,1);overlay.unmount();eq(events.has('keydown'),false);eq(document.body.style.overflow,'auto');
 storage.set('test-navigation.groups','invalid JSON');const corrupt=new Hooks();tree=corrupt.render(Sidebar,props);attach(tree);corrupt.flush();eq(groupItems(tree,'Organisation').props.hidden,false);
 find(tree,n=>n.props.className==='logistics-sidebar-toggle').props.onClick();tree=corrupt.render(Sidebar,props);attach(tree);corrupt.flush();ok(mediaEvents.has('change'));eq(document.body.style.overflow,'hidden');viewport(false);tree=corrupt.render(Sidebar,props);attach(tree);corrupt.flush();eq(sidebarToggle(tree).props.children.props.name,'sidebar');eq(sidebarToggle(tree).props['aria-expanded'],true);eq(events.has('keydown'),false);eq(document.body.style.overflow,'auto');corrupt.unmount();eq(mediaEvents.has('change'),false);
 for(const name of ['Logistique','Referentiels','LegacyAdmin','admin/AdminPortal','App'])ok(fs.readFileSync(path.join(front,'src',name==='App'?'App.jsx':'pages/'+name+'.jsx'),'utf8').includes('<ModuleSidebar'),name+' uses shared sidebar');
 // Recherche locale des menus longs : aucune API ni modification des droits.
 mobile=false;const longProps={...props,storageKey:'long-menu',groups:[...props.groups,{label:'Finances',items:[{key:'invoices',label:'Factures',icon:'document'},{key:'payments',label:'Règlements',icon:'wallet'},{key:'dates',label:'Échéances',icon:'calendar'},{key:'credit',label:'Avoirs',icon:'document'},{key:'private',label:'Secret',hidden:true}]}]};
 const long=new Hooks();function renderLong(extra={}){const t=long.render(Sidebar,{...longProps,...extra});attach(t);long.flush();return t;}
 tree=renderLong();const search=t=>find(t,n=>n.type==='input'&&n.props['aria-label']==='Rechercher dans le menu');ok(search(tree));groupToggle(tree,'Organisation').props.onClick();tree=renderLong();eq(groupItems(tree,'Organisation').props.hidden,true);
 search(tree).props.onChange({target:{value:'ORGANISATION'}});tree=renderLong();eq(nodes(tree).filter(n=>n.type==='section').length,1);eq(groupItems(tree,'Organisation').props.hidden,false);eq(groupToggle(tree,'Organisation').props.disabled,true);eq(shortcuts(tree).props.children.map(item=>item.props.to),['/parametres','/admin']);
 find(tree,n=>n.props['aria-label']==='Effacer la recherche du menu').props.onClick();tree=renderLong();eq(search(tree).props.value,'');eq(groupItems(tree,'Organisation').props.hidden,true);eq(document.activeElement,first);
 search(tree).props.onChange({target:{value:'ECHEANCES'}});tree=renderLong();eq(nodes(tree).filter(n=>n.type==='section').length,1);ok(find(tree,n=>n.props['aria-label']==='Échéances'));eq(nodes(tree).some(n=>n.props['aria-label']==='Secret'),false);eq(find(tree,n=>n.props.role==='status').props.children.join(''),'1 menu');
 document.activeElement=last;search(tree).props.onKeyDown({key:'ArrowDown',preventDefault(){prevented++;}});eq(document.activeElement,first);
 let stopped=0;search(tree).props.onKeyDown({key:'Escape',preventDefault(){prevented++;},stopPropagation(){stopped++;}});tree=renderLong();eq(stopped,1);eq(search(tree).props.value,'');
 search(tree).props.onChange({target:{value:'inexistant'}});tree=renderLong();eq(nodes(tree).filter(n=>n.type==='section').length,0);ok(find(tree,n=>n.props.className==='module-menu-empty'));eq(find(tree,n=>n.props.role==='status').props.children.join(''),'0 menus');
 tree=renderLong({collapsed:true});eq(nodes(tree).filter(n=>n.type==='section').length,3);find(tree,n=>n.props.className==='logistics-sidebar-toggle').props.onClick();tree=renderLong();eq(search(tree).props.value,'');
 search(tree).props.onChange({target:{value:'rôles'}});tree=renderLong();find(tree,n=>n.props['aria-label']==='Rôles').props.onClick();tree=renderLong();eq(search(tree).props.value,'');eq(selected.at(-1),'roles');
 tree=renderLong({collapsed:true});find(tree,n=>n.props['aria-label']==='Rôles').props.onFocus({currentTarget:{getBoundingClientRect:()=>({top:100,height:40,right:70})}});tree=renderLong({collapsed:true});const hint=find(tree,n=>n.props.role==='tooltip');eq(hint.props.children,'Rôles');eq(hint.props.style,{top:120,left:80});eq(find(tree,n=>n.props['aria-label']==='Rôles').props['aria-describedby'],hint.props.id);find(tree,n=>n.props['aria-label']==='Rôles').props.onKeyDown({key:'Escape',preventDefault(){prevented++;}});tree=renderLong({collapsed:true});eq(nodes(tree).some(n=>n.props.role==='tooltip'),false);
 viewport(true);tree=renderLong();sidebarToggle(tree).props.onClick();tree=renderLong();search(tree).props.onChange({target:{value:'rôles'}});tree=renderLong();eq(nodes(tree).filter(n=>n.type==='section').length,1);find(tree,n=>n.props.className==='logistics-sidebar-toggle').props.onClick();tree=renderLong();eq(search(tree).props.value,'');eq(nodes(tree).filter(n=>n.type==='section').length,3);eq(document.body.style.overflow,'auto');long.unmount();
 // Menu et fiche partagent le verrou : libérer l'un ne libère jamais l'autre.
 const drawerOwner={},nested=new Hooks();document.body.style.overflow='scroll';
 tree=nested.render(Sidebar,{...props,overlay:true,open:true});attach(tree);nested.flush();eq(document.body.style.overflow,'hidden');eq(isBodyScrollLocked(),true);
 lockBodyScroll(drawerOwner);tree=nested.render(Sidebar,{...props,overlay:true,open:false});attach(tree);nested.flush();eq(document.body.style.overflow,'hidden');eq(isBodyScrollLocked(),true);
 unlockBodyScroll(drawerOwner);eq(document.body.style.overflow,'scroll');eq(isBodyScrollLocked(),false);nested.unmount();
 lockBodyScroll(drawerOwner);tree=nested.render(Sidebar,{...props,overlay:true,open:true});attach(tree);nested.flush();unlockBodyScroll(drawerOwner);eq(document.body.style.overflow,'hidden');
 nested.unmount();eq(document.body.style.overflow,'scroll');eq(isBodyScrollLocked(),false);document.body.style.overflow='auto';
 const headerNav=new Hooks();
 let headerCollapsed=false;
 function renderHeaderNav(){
  const next=headerNav.render(Sidebar,{...props,headerProps:{},collapsed:headerCollapsed,onToggle:()=>{headerCollapsed=!headerCollapsed;}});
  next.props.ref.current={querySelectorAll:()=>[first,last]};
  find(next,n=>n.type==='Header').props.menuToggle.props.ref.current=first;
  headerNav.flush();
  return next;
 }
 const headerToggle=tree=>find(tree,n=>n.type==='Header').props.menuToggle;
 mobile=false;
 tree=renderHeaderNav();
 eq(headerToggle(tree).props.className,'module-sidebar-trigger');
 eq(headerToggle(tree).props.children.props.name,'close');
 eq(headerToggle(tree).props['aria-controls'],find(tree,n=>n.type==='aside').props.id);
 eq(nodes(tree).some(n=>n.props.className==='logistics-sidebar-toggle'),false);
 headerToggle(tree).props.onClick();tree=renderHeaderNav();
 eq(headerToggle(tree).props['aria-expanded'],false);eq(headerToggle(tree).props.children.props.name,'menu');
 viewport(true);tree=renderHeaderNav();
 headerToggle(tree).props.onClick();tree=renderHeaderNav();
 eq(tree.props.role,'dialog');eq(tree.props['aria-modal'],true);eq(headerToggle(tree).props['aria-label'],'Fermer le menu');
 eq(document.activeElement,first);eq(isBodyScrollLocked(),true);
 headerToggle(tree).props.onClick();tree=renderHeaderNav();
 eq(tree.props.role,undefined);eq(headerToggle(tree).props['aria-label'],'Ouvrir le menu');eq(isBodyScrollLocked(),false);
 headerNav.unmount();
 const sidebarCss=fs.readFileSync(path.join(front,'src/components/ModuleSidebar.css'),'utf8');ok(sidebarCss.includes('.module-menu-search-field:focus-within'));ok(sidebarCss.includes('.module-rail-hint { position:fixed'));ok(sidebarCss.includes('max-width:min(240px,calc(100vw - 100px))'));
 const report={success:true,checks,scope:'Vrais handlers ModuleSidebar avec DOM simulé : groupes, navigation stable, rail, mobile, focus, Échap, nettoyage ; aucune requête applicative',limits:['Pas de vérification visuelle dans le navigateur']};fs.writeFileSync(path.join(root,'.runtime/module-sidebar-tests.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));
})().catch(error=>{console.error(error);process.exit(1);});
