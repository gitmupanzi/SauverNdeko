// Helpers et handlers réels ; transports/DOM simulés, aucune donnée d'entreprise écrite.
const path=require('node:path'),Module=require('node:module'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../..'),front=path.join(root,'frontend'),esbuild=require(path.join(front,'node_modules/esbuild'));let checks=0;
const eq=(a,b)=>{assert.deepEqual(a,b);checks++;},ok=value=>{assert(value);checks++;};
function mocks(entries){return{name:'fixtures',setup(build){for(const[filter,name,source]of entries){build.onResolve({filter},()=>({path:name,namespace:name}));build.onLoad({filter:/.*/,namespace:name},()=>({contents:source,loader:'jsx',resolveDir:front}));}}};}
async function bundle(contents,entries=[]){const result=await esbuild.build({stdin:{contents,resolveDir:front,loader:'jsx'},bundle:true,jsx:'automatic',external:['react','react/jsx-runtime','react-dom/server'],platform:'node',format:'cjs',write:false,define:{'import.meta.env':'{}'},loader:{'.css':'empty'},plugins:[mocks(entries)],logLevel:'error'});const compiled=new Module(path.join(front,'settings-proof.cjs'),module);compiled.filename=path.join(front,'settings-proof.cjs');compiled.paths=Module._nodeModulePaths(front);compiled._compile(result.outputFiles[0].text,compiled.filename);return compiled.exports;}
class Hooks{constructor(){this.slots=[];this.cursor=0;this.queue=[];}state(value){const i=this.cursor++;if(!this.slots[i])this.slots[i]={value:typeof value==='function'?value():value};return[this.slots[i].value,next=>this.slots[i].value=typeof next==='function'?next(this.slots[i].value):next];}ref(value){const i=this.cursor++;if(!this.slots[i])this.slots[i]={current:value};return this.slots[i];}id(){return 'settings-'+this.cursor++;}effect(fn,deps=[]){const i=this.cursor++,old=this.slots[i];if(!old||deps.some((v,j)=>!Object.is(v,old.deps[j])))this.queue.push(()=>{old?.clean?.();this.slots[i]={deps,clean:fn()};});}render(component,props={}){this.cursor=0;globalThis.__hooks=this;return component(props);}async flush(){for(const effect of this.queue.splice(0))effect();await new Promise(resolve=>setImmediate(resolve));await new Promise(resolve=>setImmediate(resolve));}unmount(){this.slots.forEach(slot=>slot?.clean?.());}}
function nodes(node,out=[]){if(!node||typeof node!=='object')return out;if(Array.isArray(node)){node.forEach(n=>nodes(n,out));return out;}if(node.type)out.push(node);nodes(node.props?.children,out);return out;}
const named=(tree,name)=>nodes(tree).find(node=>node.type?.name===name);
const reactHooks=`export const useState=v=>globalThis.__hooks.state(v),useRef=v=>globalThis.__hooks.ref(v),useId=()=>globalThis.__hooks.id(),useEffect=(f,d)=>globalThis.__hooks.effect(f,d),useMemo=f=>f();`;
const profile={IdEntite:7,_version:'profile-v1',NomEntite:'Entreprise A',TauxTVAEntite:'16.0000',canConfigure:true,canManageEntity:false,Localisations:[],IdentifiantsLegauxEntite:[],references:{entityTypes:[],niveaux3:[],niveaux4:[],niveaux5:[]}};
globalThis.document={getElementById:id=>({focus(){globalThis.__focus=id;}})};globalThis.requestAnimationFrame=fn=>fn();globalThis.localStorage={getItem:()=>null,setItem(){}};
(async()=>{
 const domain=await bundle("export * from './src/utils/entityProfile';export * from './src/services/moduleAccess';export {moduleTabKey,presentedModuleTabs} from './src/hooks/useModulePresentation';");
 const tabFixture=[{key:'dashboard',label:'Tableau de bord'},{key:'depots',label:'Dépôts'},{key:'stocks-depots',label:'Stocks par dépôt'},{key:'transferts',label:'Transferts internes'}];
 eq(domain.presentedModuleTabs(tabFixture,{tabLabels:{depots:'Magasins'},hiddenTabs:['transferts']}).map(t=>[t.key,t.label]),[['dashboard','Tableau de bord'],['depots','Magasins'],['stocks-depots','Stocks par dépôt']]);
 eq(domain.presentedModuleTabs(tabFixture,{tabLabels:{tiers:'Partenaires'},hiddenTabs:[]}).map(t=>t.key),tabFixture.map(t=>t.key));
 for(const key of ['depots','stocks-depots','transferts'])eq(domain.moduleTabKey(tabFixture,key),key);
 eq(domain.moduleTabKey(tabFixture,'inconnu'),'dashboard');eq(domain.moduleTabKey(tabFixture,'inconnu',null),null);
 eq(domain.entityProfileValues().TauxTVAEntite,'0');eq(domain.entityProfileValues(profile).TauxTVAEntite,'16.0000');
 for(const [input,expected]of [['0','0'],['100','100'],['0.0001','0.0001'],['100.0000','100.0000'],[' 16,1234 ','16.1234'],['016.20','16.20']])eq(domain.entityTaxRate(input),expected);
 for(const bad of ['',null,'-1','100.0001','1e2','NaN','0.00001','1.2.3','16 %','1000','Infinity','16,12,1'])eq(domain.entityTaxRate(bad),null);
 let values=domain.entityProfileValues(profile);eq(domain.entityProfileErrors(values,'Mise à jour'),{});ok(domain.entityProfileErrors({...values,TauxTVAEntite:''},'Mise à jour').TauxTVAEntite);ok(domain.entityProfileErrors(values,'').motif);
 const payload=domain.entityProfilePayload({...values,TauxTVAEntite:' 16,1250 '},{record:profile,motif:' TVA ',requestId:'request'});eq(payload.TauxTVAEntite,'16.1250');eq(payload._version,'profile-v1');ok(!('ValideEntite'in payload));ok(!('IdTypeEntiteFk'in payload));
 const legacy={...profile};delete legacy.TauxTVAEntite;ok(!('TauxTVAEntite'in domain.entityProfilePayload(values,{record:legacy,motif:'Adresse',requestId:'r'})));eq(domain.moduleForPath('/parametres'),'parametres');eq(domain.mayOpen({moduleAccess:{modules:{parametres:{canRead:false}}}},'/parametres'),false);
 const ssr=await bundle("import React from 'react';import {renderToStaticMarkup} from 'react-dom/server';import Fields from './src/components/EntityProfileFields';import Totals from './src/components/InvoiceTaxSummary';export const field=p=>renderToStaticMarkup(<Fields {...p}/>);export const tax=p=>renderToStaticMarkup(<Totals {...p}/>);");
 let html=ssr.field({active:'fiscalite',prefix:'proof-',values,record:profile,readOnly:false,change(){},logo:{file:null,remove:false}});ok(html.includes('Taux de TVA (%)'));ok(html.includes('inputMode="decimal"'));ok(html.includes('value="16.0000"'));ok(html.includes('Les factures déjà émises restent inchangées'));ok(!html.includes('disabled=""'));
 html=ssr.field({active:'fiscalite',prefix:'proof-',values,record:profile,readOnly:true});ok(html.includes('readOnly=""'));
 html=ssr.tax({record:{TauxTVA:'16.1250',MontantHT:'100.00',MontantTVA:'16.13',MontantTTC:'116.13'},currency:'USD'});ok(html.includes('TVA (16,125 %)'));ok(html.includes('116,13 USD'));ok(html.includes('16,13 USD'));eq(ssr.tax({record:null}), '');html=ssr.tax({record:{MontantHT:'100.00'},currency:'USD'});ok(html.includes('—'));ok(!html.includes('>0,00 USD<'));
 globalThis.__scope={scopeKey:'user:7',entityId:'7',globalAdmin:false,canWrite:false,retry(){}};globalThis.__profile=profile;globalThis.__writes=[];globalThis.__saveResult={success:false,status:422,message:'Validation refusée',error:{details:{TauxTVAEntite:'Taux refusé'}}};
 const editor=await bundle("export {default} from './src/components/EntityProfileEditor';",[
 [/^react$/,'editor-hooks',reactHooks],[/\/contexts\/EntityScopeContext$/,'scope',`export const useEntityScope=()=>globalThis.__scope;`],[/\/contexts\/AuthContext$/,'auth',`export const useAuth=()=>({user:{IdUser:3,Is_Admin:false}});`],[/\/hooks\/useReferencesRefresh$/,'refresh',`export default function refresh(){}`],[/\/services\/fieldReferences$/,'references',`export async function fetchFieldValues(){return {success:true,data:{options:[]}};}`],[/\/services\/entityProfile$/,'profile-api',`export async function loadEntityProfile(){return {success:true,data:globalThis.__profile};}export async function saveEntityProfile(context,id,body){globalThis.__writes.push({context,id,body});return globalThis.__saveResult;}`],[/\/RecordEditorFrame$/,'frame',`export default function Frame(){}`],[/\/ConsultationTabs$/,'tabs',`export default function Tabs(){}`],[/\/ActionButton$/,'button',`export default function Button(){}`],[/\/EntityProfileFields$/,'fields',`export default function Fields(){}`],
 ]);
 const eh=new Hooks(),ep={context:'settings',mode:'edit',initialTab:'fiscalite',onClose(){},onSaved(){}},erender=()=>eh.render(editor.default,ep);erender();await eh.flush();let tree=erender();eq(named(tree,'Frame').props.readOnly,false);eq(named(tree,'Fields').props.active,'fiscalite');eq(named(tree,'Fields').props.manageStructure,false);ok(named(tree,'Tabs').props.tabs.some(tab=>tab.key==='localisation'));
 named(tree,'Fields').props.change('TauxTVAEntite','16,1250');tree=erender();eq(named(tree,'Frame').props.canSubmit,true);await named(tree,'Frame').props.onSubmit();eq(globalThis.__writes.length,0);ok(named(erender(),'Fields').props.errors.motif);ok(globalThis.__focus.endsWith('motif'));
 nodes(erender()).find(node=>node.type==='textarea'&&node.props.id.endsWith('motif')).props.onChange({target:{value:'Révision du taux'}});await named(erender(),'Frame').props.onSubmit();eq(globalThis.__writes.length,1);eq(globalThis.__writes[0].context,'settings');eq(JSON.parse(globalThis.__writes[0].body).TauxTVAEntite,'16.1250');eq(named(erender(),'Fields').props.values.TauxTVAEntite,'16,1250');eq(named(erender(),'Fields').props.errors.TauxTVAEntite,'Taux refusé');
 globalThis.__saveResult={success:false,status:503,message:'Réponse incertaine'};await named(erender(),'Frame').props.onSubmit();tree=erender();eq(named(tree,'Fields').props.disabled,true);const exact=globalThis.__writes.at(-1).body;named(tree,'Fields').props.change('TauxTVAEntite','20');eq(named(erender(),'Fields').props.values.TauxTVAEntite,'16,1250');globalThis.__saveResult={success:true,data:{...profile,TauxTVAEntite:'16.1250',_version:'profile-v2'}};await named(erender(),'Frame').props.onSubmit();eq(globalThis.__writes.at(-1).body,exact);eq(named(erender(),'Frame').props.readOnly,true);eh.unmount();
 globalThis.__profile={...profile,canConfigure:false};const denied=new Hooks();denied.render(editor.default,ep);await denied.flush();eq(named(denied.render(editor.default,ep),'Frame').props.readOnly,true);denied.unmount();
 globalThis.__profile=profile;globalThis.__params=new URLSearchParams('onglet=fiscalite');globalThis.__contextResponse={success:true,data:{entityId:7,canManage:true,profile}};globalThis.__pending=[];globalThis.__delay=false;
 const page=await bundle("export {default,settingsTab} from './src/pages/Parametres';",[
 [/^react$/,'page-hooks',reactHooks],[/^react-router-dom$/,'router',`export const useSearchParams=()=>[globalThis.__params,value=>{globalThis.__params=new URLSearchParams(value);}];`],[/\/contexts\/AuthContext$/,'page-auth',`export const useAuth=()=>({user:{IdUser:3,moduleAccess:{modules:{parametres:{canRead:true,canManage:true}}}}});`],[/\/contexts\/EntityScopeContext$/,'page-scope',`export const useEntityScope=()=>globalThis.__scope;`],[/\/services\/api$/,'page-api',`export async function requestJson(path,options){if(path!=='/api/parametres/contexte')return globalThis.__presentationApi(path,options);if(globalThis.__delay)return new Promise(resolve=>globalThis.__pending.push(resolve));return globalThis.__contextResponse;}`],[/\/components\/ModuleSidebar$/,'sidebar',`export default function Sidebar(){}`],[/\/components\/ModuleHeader$/,'header',`export default function Header(){}`],[/\/components\/AppIcon$/,'page-icon',`export default function Icon(){}`],[/\/components\/ActionButton$/,'page-button',`export default function Button(){}`],[/\/components\/EntityProfileEditor$/,'editor',`export default function Editor(){}`],[/\/components\/EntityProfileFields$/,'page-fields',`export default function Fields(){}`],
 [/\/components\/RecordEditorFrame$/,'presentation-frame',`export default function Frame(){}`],
 ]);
 globalThis.__presentationApi=()=>({success:true,data:{entityId:Number(globalThis.__scope.entityId),modules:[]}});
 eq(page.settingsTab('inconnu').key,'entreprise');const ph=new Hooks(),render=()=>ph.render(page.default);render();await ph.flush();tree=render();eq(named(tree,'Fields').props.values.TauxTVAEntite,'16.0000');let modify=nodes(tree).find(node=>node.type?.name==='Button'&&node.props.children==='Modifier');eq(modify.props.disabled,false);modify.props.onClick();tree=render();eq(named(tree,'Editor').props.context,'settings');eq(named(tree,'Editor').props.initialTab,'fiscalite');named(tree,'Editor').props.onSaved();render();await ph.flush();ok(nodes(render()).some(node=>node.props?.role==='status'));
 globalThis.__scope={...globalThis.__scope,scopeKey:'user:8',entityId:'8'};tree=render();eq(named(tree,'Fields'),undefined);eq(named(tree,'Editor'),undefined);await ph.flush();tree=render();ok(nodes(tree).some(node=>node.props?.role==='alert'));eq(named(tree,'Fields'),undefined);
 globalThis.__contextResponse={success:true,data:{entityId:8,canManage:false,profile:{...profile,IdEntite:8,TauxTVAEntite:'0.0000'}}};globalThis.__scope={...globalThis.__scope,scopeKey:'read:8'};render();await ph.flush();tree=render();eq(named(tree,'Fields').props.values.TauxTVAEntite,'0.0000');eq(nodes(tree).find(node=>node.type?.name==='Button'&&node.props.children==='Modifier').props.disabled,true);
 globalThis.__delay=true;globalThis.__scope={...globalThis.__scope,scopeKey:'waiting:8'};render();await ph.flush();globalThis.__scope={...globalThis.__scope,scopeKey:'waiting:7',entityId:'7'};render();await ph.flush();globalThis.__pending.shift()({success:true,data:{canManage:true,profile:{...profile,IdEntite:8}}});await ph.flush();eq(named(render(),'Fields'),undefined);globalThis.__pending.shift()({success:true,data:{canManage:true,profile}});await ph.flush();eq(named(render(),'Fields').props.record.IdEntite,7);ph.unmount();
 const presentation={entityId:7,tabDefaults:{caisses:'Caisses',clotures:'Clôtures'},dashboardBlockDefaults:{flux:'Flux quotidiens'},
  tabLabels:{caisses:'Guichets'},hiddenDashboardBlocks:['flux'],revision:'v1',canManage:true};
 const modules=[{key:'logistique',label:'Logistique'},{key:'caisse',label:'Caisse'},{key:'support',label:'Support'},{key:'discussions',label:'Discussions'},{key:'data-science',label:'Data Science'}];
 const writes=[];
 let presentationModule='caisse';
 globalThis.__presentationApi=(path,options)=>{
  if(path==='/api/parametres/presentation'){
   const entityId=Number(globalThis.__scope.entityId);
   return {success:true,data:{entityId,modules:entityId===7?modules:modules.slice(0,1)}};
  }
  eq(path,'/api/parametres/'+presentationModule+'/presentation');
  if(options.method!=='PUT')return {success:true,data:presentation};
  const body=JSON.parse(options.body);
  writes.push(body);
  return {success:true,data:{...presentation,...body,revision:'v'+(writes.length+1)}};
 };
 globalThis.__delay=false;
 globalThis.__scope={...globalThis.__scope,entities:[]};
 globalThis.__params=new URLSearchParams('onglet=presentation&module=caisse');
 const mh=new Hooks(),renderPage=()=>mh.render(page.default);
 const sidebar=tree=>named(tree,'Sidebar').props;
 const presentationItems=tree=>sidebar(tree).groups.find(group=>group.key==='presentation').items;
 renderPage();await mh.flush();const modulePage=renderPage();
 const sidebarItems=presentationItems(modulePage);
 eq(sidebarItems.map(({key,label})=>({key,label})),[
  {key:'presentation-logistique',label:'Logistique'},{key:'presentation-caisse',label:'Caisse'},
  {key:'presentation-support',label:'Support'},{key:'presentation-discussions',label:'Discussions'},
  {key:'presentation-data-science',label:'Data Science'},
 ]);
 eq(sidebar(modulePage).activeKey,'presentation-caisse');
 ok(!sidebar(modulePage).groups[0].items.some(item=>item.key==='presentation'));
 const panel=named(modulePage,'PresentationSettings');
 eq(panel.props.module.key,'caisse');
 const sh=new Hooks();
 tree=sh.render(panel.type,panel.props);
 const modulePanel=named(tree,'ModulePresentationSettings');
 const dh=new Hooks(),renderModule=()=>dh.render(modulePanel.type,modulePanel.props);
 const action=(tree,text)=>nodes(tree).find(node=>node.type?.name==='Button'&&node.props.children===text);
 renderModule();await dh.flush();action(renderModule(),'Modifier').props.onClick();
 const checkbox=tree=>nodes(tree).find(node=>node.type==='input'&&node.props['aria-label']==='Afficher dans le menu · Clôtures');
 tree=renderModule();
 eq(checkbox(tree).props.checked,true);
 checkbox(tree).props.onChange({target:{checked:false}});
 await named(renderModule(),'Frame').props.onSubmit();
 eq(writes[0],{entityId:7,revision:'v1',tabLabels:{caisses:'Guichets'},hiddenTabs:['clotures'],hiddenDashboardBlocks:['flux']});
 ok(nodes(renderModule()).some(node=>node.type==='span'&&node.props.children==='Masqué'));
 action(renderModule(),'Modifier').props.onClick();
 eq(checkbox(renderModule()).props.checked,false);
 action(renderModule(),'Rétablir les valeurs par défaut').props.onClick();
 await named(renderModule(),'Frame').props.onSubmit();
 eq(writes[1],{entityId:7,revision:'v2',tabLabels:{},hiddenTabs:[],hiddenDashboardBlocks:[]});
 globalThis.__params=new URLSearchParams(sidebarItems[0].to.split('?')[1]);
 eq(named(renderPage(),'PresentationSettings').props.module.key,'logistique');
 presentationModule='discussions';
 const discussionData={...presentation,tabDefaults:{messages:'Messages',demandes:'Demandes',annonces:'Annonces'},dashboardBlockDefaults:{},tabLabels:{},hiddenDashboardBlocks:[]};
 const previousApi=globalThis.__presentationApi;
 globalThis.__presentationApi=(path,options)=>path==='/api/parametres/discussions/presentation'?{success:true,data:discussionData}:previousApi(path,options);
 globalThis.__params=new URLSearchParams(sidebarItems[3].to.split('?')[1]);
 const discussionPanel=named(renderPage(),'PresentationSettings');
 eq(discussionPanel.props.module.key,'discussions');
 const discussion=new Hooks();
 const discussionSettings=named(sh.render(discussionPanel.type,discussionPanel.props),'ModulePresentationSettings');
 const renderDiscussion=()=>discussion.render(discussionSettings.type,discussionSettings.props);
 renderDiscussion();await discussion.flush();
 ok(action(renderDiscussion(),'Modifier'));
 ok(!nodes(renderDiscussion()).some(node=>node.props?.children==='Blocs du tableau de bord'));
 discussion.unmount();
 const dataScienceItem=sidebarItems.find(item=>item.key==='presentation-data-science');
 eq(dataScienceItem.to,'/parametres?onglet=presentation&module=data-science');
 globalThis.__params=new URLSearchParams(dataScienceItem.to.split('?')[1]);
 const dataSciencePanel=named(renderPage(),'PresentationSettings');
 eq(sidebar(renderPage()).activeKey,'presentation-data-science');
 eq(dataSciencePanel.props.module.key,'data-science');
 const dataScienceSettings=named(sh.render(dataSciencePanel.type,dataSciencePanel.props),'ModulePresentationSettings');
 const dataScience=new Hooks();
 const renderDataScience=()=>dataScience.render(dataScienceSettings.type,dataScienceSettings.props);
 const dataScienceData={...presentation,tabDefaults:{'tableau-de-bord':'Tableau de bord',demandes:'Demandes et besoins'},
   dashboardBlockDefaults:{demandes:'Demandes et besoins'},tabLabels:{demandes:'Demandes de l’entreprise'},
   hiddenTabs:[],hiddenDashboardBlocks:[]};
 globalThis.__presentationApi=(path,options)=>path==='/api/parametres/data-science/presentation'?{success:true,data:dataScienceData}:previousApi(path,options);
 renderDataScience();await dataScience.flush();
 tree=renderDataScience();
 ok(nodes(tree).some(node=>node.type==='dd'&&node.props.children==='Demandes de l’entreprise'));
 ok(nodes(tree).some(node=>node.type==='h2'&&node.props.children==='Data Science'));
 dataScience.unmount();
 globalThis.__presentationApi=previousApi;
 globalThis.__params=new URLSearchParams('');
 eq(sidebar(renderPage()).activeKey,'entreprise');
 eq(presentationItems(renderPage()).length,5);
 globalThis.__scope={...globalThis.__scope,scopeKey:'user:8',entityId:'8'};
 globalThis.__params=new URLSearchParams('onglet=presentation&module=data-science');
 eq(presentationItems(renderPage()),[]);
 await mh.flush();
 tree=renderPage();
 eq(presentationItems(tree).map(item=>item.key),['presentation-logistique']);
 eq(sidebar(tree).activeKey,'presentation-logistique');
 dh.unmount();sh.unmount();mh.unmount();
 // Le même panneau reçoit les nouveaux onglets du catalogue serveur, sans réinitialiser l'entreprise.
 const depotDefaults={dashboard:'Tableau de bord',dossiers:'Dossiers de suivi',tiers:'Clients et fournisseurs',depots:'Dépôts',articles:'Articles',lots:'Lots de stock','stocks-depots':'Stocks par dépôt',commandes:'Bons de stock',details:'Lignes des bons',transferts:'Transferts internes',mouvements:'Mouvements de stock',inventaires:'Inventaires',factures:'Factures',reglements:'Règlements',immobilisations:'Immobilisations'};
 presentationModule='logistique';
 Object.assign(presentation,{tabDefaults:depotDefaults,dashboardBlockDefaults:{articles:'Articles',commandes:'Bons de stock',factures:'Factures',alertes:'Alertes'},tabLabels:{tiers:'COUSP et Partenaires',articles:'Produits'},hiddenTabs:['factures'],hiddenDashboardBlocks:['factures'],revision:'log-v1',canManage:true});
 const lh=new Hooks(),lp={entityId:7,entityName:'Entreprise A',module:modules[0]},renderLogistique=()=>lh.render(modulePanel.type,lp);
 renderLogistique();await lh.flush();tree=renderLogistique();
 eq(nodes(tree).filter(n=>n.type==='dt').map(n=>n.props.children),Object.values(depotDefaults));
 eq(nodes(tree).filter(n=>n.type==='span'&&n.props.children==='Visible').length,14+3);
 action(tree,'Modifier').props.onClick();tree=renderLogistique();
 const visible=(tree,label)=>nodes(tree).find(n=>n.type==='input'&&n.props['aria-label']==='Afficher dans le menu · '+label);
 for(const label of ['Dépôts','Stocks par dépôt','Transferts internes'])eq(visible(tree,label).props.checked,true);
 eq(visible(tree,'Factures').props.checked,false);
 const labelInput=(tree,label)=>nodes(tree).find(n=>n.type==='input'&&n.props.placeholder===label);
 eq(labelInput(tree,'Clients et fournisseurs').props.value,'COUSP et Partenaires');
 labelInput(tree,'Dépôts').props.onChange({target:{value:'Magasins'}});
 visible(renderLogistique(),'Transferts internes').props.onChange({target:{checked:false}});
 await named(renderLogistique(),'Frame').props.onSubmit();
 eq(writes[2],{entityId:7,revision:'log-v1',tabLabels:{tiers:'COUSP et Partenaires',depots:'Magasins',articles:'Produits'},hiddenTabs:['transferts','factures'],hiddenDashboardBlocks:['factures']});
 tree=renderLogistique();ok(nodes(tree).some(n=>n.type==='dd'&&n.props.children==='Magasins'));
 action(tree,'Modifier').props.onClick();tree=renderLogistique();eq(visible(tree,'Transferts internes').props.checked,false);
 action(tree,'Rétablir les valeurs par défaut').props.onClick();tree=renderLogistique();
 for(const label of ['Dépôts','Stocks par dépôt','Transferts internes','Factures'])eq(visible(tree,label).props.checked,true);
 await named(tree,'Frame').props.onSubmit();eq(writes[3],{entityId:7,revision:'v4',tabLabels:{},hiddenTabs:[],hiddenDashboardBlocks:[]});lh.unmount();
 Object.assign(presentation,{canManage:false});const readonly=new Hooks();readonly.render(modulePanel.type,lp);await readonly.flush();ok(!action(readonly.render(modulePanel.type,lp),'Modifier'));readonly.unmount();
 globalThis.__invoiceResponse={success:true,data:{bonOrigine:{CodeCmd:'BS-1',DeviseCode:'USD'},totaux:{TauxTVA:'16.0000',MontantHT:'100.00',MontantTVA:'16.00',MontantTTC:'116.00',DeviseCode:'USD'},lignes:[],references:{}},meta:{available:true,canIssue:true,canEdit:true}};
 const invoice=await bundle("export {default} from './src/pages/logistique/InvoiceEditor';",[
 [/^react$/,'invoice-hooks',reactHooks],[/\/contexts\/AuthContext$/,'invoice-auth',`export const useAuth=()=>({user:{IdUser:3,IdEntiteFk:7,permissions:{canWriteData:true}}});`],[/\/services\/api$/,'invoice-api',`export async function requestJson(){return globalThis.__invoiceResponse;}`],[/\/hooks\/useReferencesRefresh$/,'invoice-refresh',`export default function refresh(){}`],[/\/RecordEditorFrame$/,'invoice-frame',`export default function Frame(){}`],[/\/SearchSelect$/,'invoice-select',`export default function Select(){}`],[/\/BusinessDocuments$/,'invoice-docs',`export default function Documents(){}`],[/\/InvoiceTaxSummary$/,'invoice-taxes',`export default function Taxes(){}`],[/\/logistiqueShared$/,'invoice-shared',`export const formatCurrency=(v,c)=>v==null?'—':String(v)+' '+c,formatNumber=v=>String(v);export function SimpleTable(){}`],
 ]);
 const ih=new Hooks(),ip={commandeId:1,onClose(){},onSaved(){}};ih.render(invoice.default,ip);await ih.flush();tree=ih.render(invoice.default,ip);eq(named(tree,'Taxes').props.record.MontantTTC,'116.00');let cols=named(tree,'SimpleTable').props.columns;eq(cols.find(c=>c.key==='PUFacture').label,'Prix unitaire HT');eq(cols.filter(c=>['MontantLigneHT','MontantTVA','MontantTTC'].includes(c.key)).length,3);eq(cols.find(c=>c.key==='MontantTVA').render({MontantTVA:'16.00'}),'16.00 USD');ih.unmount();
 globalThis.__invoiceResponse={...globalThis.__invoiceResponse,data:{...globalThis.__invoiceResponse.data,facture:{CodeFacture:'fac-1',TauxTVA:'0.0000',MontantHT:'100.00',MontantTVA:'0.00',MontantTTC:'100.00',DeviseCode:'USD'},totaux:{TauxTVA:'16.0000',MontantHT:'100.00',MontantTVA:'16.00',MontantTTC:'116.00',DeviseCode:'EUR'}}};
 const historical=new Hooks();historical.render(invoice.default,ip);await historical.flush();tree=historical.render(invoice.default,ip);eq(named(tree,'Taxes').props.record.TauxTVA,'0.0000');eq(named(tree,'Taxes').props.currency,'USD');ok(nodes(tree).some(n=>n.type==='strong'&&n.props.children==='100.00 USD'));ok(!nodes(tree).some(n=>n.type==='strong'&&n.props.children==='116.00 EUR'));historical.unmount();
 const api=await bundle("export * from './src/services/entityProfile';",[[/\.\/api$/,'api',`export const API_BASE_URL='http://local.invalid';export const requestJson=(path,options)=>({path,options});`]]);eq(api.entityProfilePath('settings'),'/api/parametres/profil');eq(api.saveEntityProfile('settings',null,'{}').options.method,'PUT');eq(api.loadEntityProfile('settings',null).path,'/api/parametres/profil');
 console.log(JSON.stringify({success:true,checks,scope:'TVA exacte, profil partagé, isolation visuelle, rejeu après incertitude et présentation par module avec masquage et restauration',limits:['API et DOM simulés ; aucune recette visuelle navigateur']}));
})().catch(error=>{console.error(error);process.exitCode=1;});
