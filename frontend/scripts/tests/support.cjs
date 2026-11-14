// Vrais helpers et handlers Support ; transports et DOM simulés, aucune donnée applicative.
const fs=require('node:fs'),path=require('node:path'),Module=require('node:module'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../..'),front=path.join(root,'frontend'),esbuild=require(path.join(front,'node_modules/esbuild'));let checks=0;
const eq=(a,b)=>{assert.deepEqual(a,b);checks++;},ok=(v,msg)=>{assert(v,msg);checks++;};
class Hooks{constructor(){this.slots=[];this.cursor=0;this.queue=[];}state(initial){const i=this.cursor++;if(!this.slots[i])this.slots[i]={value:typeof initial==='function'?initial():initial};return[this.slots[i].value,next=>this.slots[i].value=typeof next==='function'?next(this.slots[i].value):next];}ref(value){const i=this.cursor++;if(!this.slots[i])this.slots[i]={current:value};return this.slots[i];}id(){return'proof-'+this.cursor++;}effect(fn,deps=[]){const i=this.cursor++,old=this.slots[i];if(!old||deps.some((v,j)=>!Object.is(v,old.deps[j])))this.queue.push(()=>{old?.cleanup?.();this.slots[i]={deps,cleanup:fn()};});}render(fn,props){this.cursor=0;globalThis.__hooks=this;return fn(props);}async flush(){for(const effect of this.queue.splice(0))effect();await new Promise(resolve=>setImmediate(resolve));await new Promise(resolve=>setImmediate(resolve));}unmount(){this.slots.forEach(slot=>slot?.cleanup?.());}}
function nodes(node,out=[]){if(!node||typeof node!=='object')return out;if(Array.isArray(node)){node.forEach(n=>nodes(n,out));return out;}if(node.type)out.push(node);for(const key of ['children','action'])nodes(node.props?.[key],out);return out;}
const mark=(tree,name)=>nodes(tree).find(n=>n.type?.name===name),field=(tree,key)=>nodes(tree).find(n=>String(n.props?.id||'').endsWith(key)),button=(tree,label)=>nodes(tree).find(n=>n.type?.name==='Button'&&n.props.children===label);
function mocks(entries){return{name:'fixtures',setup(build){entries.forEach(([filter,name,contents])=>{build.onResolve({filter},()=>({path:name,namespace:name}));build.onLoad({filter:/.*/,namespace:name},()=>({contents,loader:'jsx',resolveDir:front}));});}};}
async function bundle(contents,plugins=[]){const built=await esbuild.build({stdin:{contents,resolveDir:front,loader:'jsx'},bundle:true,jsx:'automatic',external:['react','react/jsx-runtime'],platform:'node',format:'cjs',write:false,define:{'import.meta.env':'{}'},loader:{'.css':'empty'},plugins,logLevel:'error'});const compiled=new Module(path.join(front,'support-proof.cjs'),module);compiled.filename=path.join(front,'support-proof.cjs');compiled.paths=Module._nodeModulePaths(front);compiled._compile(built.outputFiles[0].text,compiled.filename);return compiled.exports;}
globalThis.requestAnimationFrame=fn=>fn();globalThis.cancelAnimationFrame=()=>{};globalThis.document={getElementById:()=>({focus(){}})};globalThis.localStorage={getItem(){return null;},setItem(){}};
globalThis.__scope={scopeKey:'A',entityId:'7'};globalThis.__user={IdUser:1,permissions:{canWriteData:true,canExportData:true},moduleAccess:{modules:{support:{canRead:true,canManage:true,canExport:true}}}};
globalThis.__context={canCreate:true,canManage:true,canVerify:true,canExport:true,canReadProcessModels:true,users:[{id:1,label:'Agent habilité'}],requesters:[{id:2,label:'Demandeur externe'}],references:{types:[{id:11,label:'Incident'}],categories:[{id:12,label:'Technique'}],priorities:[{id:13,label:'Normale'}],statuses:[{id:14,label:'Nouveau'}],channels:[{id:15,label:'Téléphone'}],services:[{id:16,label:'Informatique'}],resultats:[{id:17,label:'Conforme'}]},links:{articles:[{id:3,label:'Article'}],bons:[{id:4,label:'BE-4'}],immobilisations:[{id:5,label:'IMMO-5'}]}};
globalThis.__record={ID_Support:42,NumeroSupport:'SUP-42',Objet:'Demande fictive',Description:'Description conservée',ID_DemandeurFk:2,ID_ResponsableFk:1,ID_TypeSupportFk:11,_version:'v1'};
globalThis.__detail={record:globalThis.__record,canManage:true,canVerify:true,canExport:true,comments:[],documents:[],resolutions:[],history:[],transitions:[{key:'prendre',label:'Prendre en charge'}]};
globalThis.__meta={filteredCount:1,totalCount:1,take:25,skip:0};globalThis.__calls=[];globalThis.__writes=[];globalThis.__results=[];globalThis.__downloads=[];
const apiNames=[...fs.readFileSync(path.join(front,'src/services/api.js'),'utf8').matchAll(/export (?:async )?function (\w+)/g)].map(m=>m[1]).filter(n=>!['requestJson','downloadApiFile'].includes(n));
const fixture=mocks([
 [/^react$/,'hooks',`export const Fragment=Symbol.for('react.fragment'),useState=v=>globalThis.__hooks.state(v),useRef=v=>globalThis.__hooks.ref(v),useId=()=>globalThis.__hooks.id(),useEffect=(f,d)=>globalThis.__hooks.effect(f,d),useLayoutEffect=useEffect,useMemo=f=>f(),useCallback=f=>f,Children={toArray:x=>[].concat(x)},isValidElement=x=>Boolean(x?.type);`],
 [/\/contexts\/AuthContext$/,'auth',`export const useAuth=()=>({user:globalThis.__user});`],
 [/\/contexts\/EntityScopeContext$/,'scope',`export const useEntityScope=()=>globalThis.__scope;`],
 [/\/hooks\/useTablePreferences$/,'prefs',`export default function Preferences(key){return {key,ready:true,canExport:true,exportKeys:key==='support.modeles'?['name','stageCount']:['NumeroSupport','Objet'],error:''};}`],
 [/\/hooks\/useReferencesRefresh$/,'refresh',`export default function ReferencesRefresh(){}`],
 [/\/components\/RecordEditorFrame$/,'frame',`export default function Frame(){}`],
 [/\/components\/ActionButton$/,'button',`export default function Button(){}`],
 [/\/components\/AppIcon$/,'icon',`export default function Icon(){}`],
 [/\/components\/ConsultationTabs$/,'tabs',`export default function Tabs(){}`],
 [/\/components\/ConsultationProvider$/,'consultation',`export const useConsultations=()=>({openProduct(){},openOrder(){}});`],
 [/\/components\/LazyView$/,'lazy',`export default function lazyView(){return function LazyView(){};}`],
 [/\/components\/SearchSelect$/,'select',`export default function Select(){}`],
 [/\/components\/RegisterSurface$/,'surface',`export default function Surface(){}`],
 [/\/components\/RegisterSettingsButton$/,'settings',`export default function Settings(){}`],
 [/\/components\/DataTableToolbar$/,'toolbar',`export default function Toolbar(){}`],
 [/\/components\/ExportMenu$/,'export-menu',`export default function ExportMenu(){}`],
 [/\/components\/RowActionsMenu$/,'actions',`export default function Actions(){}`],
 [/\/logistique\/logistiqueShared$/,'table',`export function SimpleTable(){};export const formatDate=x=>x;`],
 [/\/services\/api$/,'api',`export async function requestJson(url,options={}){globalThis.__calls.push({url,options});if(options.method){globalThis.__writes.push({url,options});return globalThis.__results.shift()||{success:false,status:503};}if(url==='/api/support/presentation')return {success:true,data:{entityId:globalThis.__scope.entityId,...globalThis.__supportPresentation}};if(globalThis.__holdReads)return globalThis.__holdReads;if(url.includes('/processus?'))return {success:true,data:globalThis.__models};if(url.includes('/processus/suivi?'))return {success:true,data:globalThis.__monitor};if(url.endsWith('/parcours'))return {success:true,data:globalThis.__journey};if(url.includes('/contexte'))return {success:true,data:globalThis.__context};if(url.includes('/tableau-de-bord'))return {success:true,data:globalThis.__dashboard};if(url.includes('/kanban'))return {success:true,data:globalThis.__kanban||{columns:[{id:14,label:'Nouveau',count:45,rows:[globalThis.__record],hasMore:true}]}};if(url.includes('?'))return {success:true,data:[globalThis.__record],meta:globalThis.__meta};return {success:true,data:globalThis.__detail};}export async function downloadApiFile(url,options){globalThis.__downloads.push({url,options});}${apiNames.map(name=>'export function '+name+'(){throw Error("Route hors Support inattendue");}').join(' ')}`],
 [/^react-router-dom$/,'router',`export function Link(){};export const useSearchParams=()=>[globalThis.__params||new URLSearchParams(),(...args)=>globalThis.__navigation?.push(args)];`],
 [/\/components\/ModuleSidebar$/,'sidebar',`export default function Sidebar(){}`],
 [/\/components\/ModuleHeader$/,'header',`export default function Header(){}`],
]);
(async()=>{
 const p=await bundle(`export * from './src/pages/support/supportForm';export {default as Portal} from './src/pages/support/SupportPortal';export {SupportStageRegister,ProcessMonitor} from './src/pages/support/SupportProcesses';export {default as Editor} from './src/pages/support/SupportEditor';export {default as Action} from './src/pages/support/SupportAction';export {default as Register,SupportReferences} from './src/pages/support/SupportRegister';export {default as Dashboard} from './src/pages/support/SupportDashboard';export {default as Detail,SUPPORT_DETAIL_TABS,supportHistoryLabel} from './src/pages/support/SupportDetail';`,[fixture]);
 eq(p.SUPPORT_ROOT,'/api/support');eq(p.SUPPORT_DETAIL_TABS.length,6);eq(p.SUPPORT_FIELDS.filter(f=>f.required).map(f=>f.key),['Objet','Description']);
 const initial=p.supportInitial(globalThis.__record);eq(initial.ID_ResponsableFk,'1');eq(initial.Description,'Description conservée');ok(p.supportValidation({...initial,Objet:''}).Objet);ok(p.supportValidation({...initial,Description:''}).Description);eq(p.supportValidation(initial),{});
 eq(p.supportOptions(globalThis.__context,{key:'ID_DemandeurFk',source:'requesters'},{}),[{id:2,label:'Demandeur externe',value:'2',disabled:false}]);
 eq(p.supportOptions({references:{types:[{id:111,name:'Nom complet',label:'Nom complet',abbr:'ABR'}]}},{key:'ID_TypeSupportFk',source:'types'})[0].label,'ABR');eq(p.supportOptions({references:{types:[{id:112,name:'Nom complet',label:'Nom complet',abbr:null}]}},{key:'ID_TypeSupportFk',source:'types'})[0].label,'Valeur sans abréviation #112');
 eq(p.supportOptions({}, {key:'ID_DemandeurFk',source:'requesters'},{ID_DemandeurFk:901,Demandeur:'Usager conservé'})[0].label,'Usager conservé');
 const retained=p.supportOptions(globalThis.__context,{key:'ID_TypeSupportFk',source:'types'},{ID_TypeSupportFk:900,TypeSupport:'Ancien type'});eq(retained.at(-1).value,'900');eq(retained.at(-1).label,'Valeur sans abréviation #900');ok(retained.at(-1).disabled);
 const body=p.supportPayload(initial,'opaque','uuid');eq(body._version,'opaque');eq(body.requestId,'uuid');eq(body.ID_DemandeurFk,'2');ok(!('ID_StatutFk'in body));ok(!('IdEntiteFk'in body));eq(body.ID_CommandeFk,null);
 eq(p.supportInputDate('2026-10-30T08:15:00Z'),'2026-10-30T09:15');eq(p.supportPayload({...initial,DateEcheance:'2026-10-30T10:20'},null,'r').DateEcheance,'2026-10-30T10:20:00+01:00');
 let query=p.supportQuery({q:'Incident',filters:{ID_StatutFk:'14',ID_ResponsableFk:'__null__'},dateFrom:'2026-10-01',archive:'all'},{take:50,skip:100});eq(JSON.parse(query.get('filters')),{ID_StatutFk:'14',ID_ResponsableFk:null});eq(query.get('q'),'Incident');eq(query.get('skip'),'100');eq(query.get('archive'),'all');
 ok(p.supportUncertain({status:503}));ok(!p.supportUncertain({status:422}));ok(p.supportActionValidation({requiresReason:true},{}).motif);ok(p.supportActionValidation({requiresResolution:true},{}).CauseIdentifiee);ok(p.supportActionValidation({requiresVerification:true},{}).ID_ResultatVerificationFk);eq(p.supportActionValidation({requiresReason:true},{motif:'Retour du demandeur'}),{});
 const h=new Hooks(),saved=[],props={record:globalThis.__record,context:globalThis.__context,allowed:true,onClose(){},onSaved:r=>saved.push(r)},render=()=>h.render(p.Editor,props);let tree=render();await h.flush();tree=render();eq(field(tree,'Objet').props.value,'Demande fictive');eq(field(tree,'Description').props.value,'Description conservée');eq(field(tree,'ID_DemandeurFk').props.value,'2');field(tree,'Objet').props.onChange({target:{value:'Objet corrigé'}});tree=render();ok(mark(tree,'Frame').props.dirty);globalThis.__results.push({success:false,status:503,message:'Réponse perdue'});await mark(tree,'Frame').props.onSubmit();tree=render();const first=globalThis.__writes.at(-1);eq(first.url,'/api/support/tickets/42');eq(first.options.method,'PATCH');eq(JSON.parse(first.options.body)._version,'v1');ok(field(tree,'Objet').props.disabled);eq(mark(tree,'Frame').props.submitLabel,'Vérifier l’enregistrement');globalThis.__results.push({success:true,data:{...globalThis.__record,Objet:'Objet corrigé'}});await mark(tree,'Frame').props.onSubmit();eq(globalThis.__writes.at(-1).options.body,first.options.body);eq(saved.length,1);h.unmount();
 const denied=new Hooks();globalThis.__user.permissions.canWriteData=false;tree=denied.render(p.Editor,props);ok(mark(tree,'Frame').props.readOnly);let before=globalThis.__writes.length;await mark(tree,'Frame').props.onSubmit();eq(globalThis.__writes.length,before);denied.unmount();globalThis.__user.permissions.canWriteData=true;
 const mismatch=new Hooks(),mr=()=>mismatch.render(p.Editor,props);tree=mr();await mismatch.flush();field(tree,'Objet').props.onChange({target:{value:'Brouillon conservé'}});globalThis.__scope={scopeKey:'B',entityId:'8'};tree=mr();ok(mark(tree,'Frame').props.readOnly);eq(field(tree,'Objet').props.value,'Brouillon conservé');before=globalThis.__writes.length;await mark(tree,'Frame').props.onSubmit();eq(globalThis.__writes.length,before);mismatch.unmount();globalThis.__scope={scopeKey:'A',entityId:'7'};
 const create=new Hooks(),cp={context:globalThis.__context,onClose(){},onSaved(){}},cr=()=>create.render(p.Editor,cp);tree=cr();await create.flush();await mark(tree,'Frame').props.onSubmit();tree=cr();ok(field(tree,'Objet').props['aria-invalid']);eq(mark(tree,'Tabs').props.value,'demande');before=globalThis.__writes.length;await mark(tree,'Frame').props.onSubmit();eq(globalThis.__writes.length,before);field(tree,'Objet').props.onChange({target:{value:'Nouvelle demande'}});field(tree,'Description').props.onChange({target:{value:'Détail de la demande'}});tree=cr();globalThis.__results.push({success:false,status:422,message:'Vérifiez la catégorie'});await mark(tree,'Frame').props.onSubmit();tree=cr();eq(field(tree,'Objet').props.value,'Nouvelle demande');ok(!field(tree,'Objet').props.disabled);create.unmount();
 const modelEditor=new Hooks(),modelSaved=[];
 const modelContext={...globalThis.__context,canStartJourneyOnCreate:true,journeyModels:[
  {id:21,typeId:11,name:'Traitement d’un incident',version:1,stageCount:2},
  {id:22,typeId:12,name:'Suivi d’une réclamation',version:1,stageCount:1},
 ]};
 const renderModel=()=>modelEditor.render(p.Editor,{context:modelContext,onClose(){},onSaved:(row,meta)=>modelSaved.push([row,meta])});
 tree=renderModel();await modelEditor.flush();tree=renderModel();ok(field(tree,'modelId').props.disabled);
 field(tree,'Objet').props.onChange({target:{value:'Dossier avec suivi'}});
 field(tree,'Description').props.onChange({target:{value:'Description du dossier'}});
 field(tree,'ID_TypeSupportFk').props.onChange('11');
 tree=renderModel();eq(field(tree,'modelId').props.options.map(option=>option.value),['','21']);
 field(tree,'modelId').props.onChange('21');
 tree=renderModel();field(tree,'ID_TypeSupportFk').props.onChange('12');
 tree=renderModel();eq(field(tree,'modelId').props.value,'');eq(field(tree,'modelId').props.options.map(option=>option.value),['','22']);
 field(tree,'modelId').props.onChange('22');
 tree=renderModel();globalThis.__results.push({success:false,status:422,error:{details:{modelId:'Modèle indisponible'}}});
 await mark(tree,'Frame').props.onSubmit();
 tree=renderModel();ok(field(tree,'modelId').props.invalid);eq(field(tree,'Objet').props.value,'Dossier avec suivi');
 eq(JSON.parse(globalThis.__writes.at(-1).options.body).modelId,22);
 field(tree,'modelId').props.onChange('');tree=renderModel();
 globalThis.__results.push({success:true,data:{record:globalThis.__record}});
 await mark(tree,'Frame').props.onSubmit();
 ok(!('modelId' in JSON.parse(globalThis.__writes.at(-1).options.body)));eq(modelSaved[0][1],{startedJourney:false});
 tree=renderModel();field(tree,'modelId').props.onChange('22');tree=renderModel();
 globalThis.__results.push({success:false,status:503});
 await mark(tree,'Frame').props.onSubmit();tree=renderModel();ok(field(tree,'modelId').props.disabled);
 const modelAttempt=globalThis.__writes.at(-1).options.body;
 globalThis.__results.push({success:true,data:{record:globalThis.__record}});
 await mark(tree,'Frame').props.onSubmit();
 eq(globalThis.__writes.at(-1).options.body,modelAttempt);eq(modelSaved[1][1],{startedJourney:true});
 modelEditor.unmount();
 const action=new Hooks(),ap={action:{key:'attendre',label:'Mettre en attente',requiresReason:true},record:globalThis.__record,context:globalThis.__context,onClose(){},onSaved:r=>saved.push(r)},ar=()=>action.render(p.Action,ap);tree=ar();await action.flush();before=globalThis.__writes.length;await mark(tree,'Frame').props.onSubmit();tree=ar();eq(globalThis.__writes.length,before);ok(field(tree,'motif').props['aria-invalid']);field(tree,'motif').props.onChange({target:{value:'Pièce attendue'}});tree=ar();globalThis.__results.push({success:false,status:503});await mark(tree,'Frame').props.onSubmit();tree=ar();const actionAttempt=globalThis.__writes.at(-1);eq(JSON.parse(actionAttempt.options.body).action,'attendre');eq(JSON.parse(actionAttempt.options.body).motif,'Pièce attendue');globalThis.__results.push({success:true,data:globalThis.__detail});await mark(tree,'Frame').props.onSubmit();eq(globalThis.__writes.at(-1).options.body,actionAttempt.options.body);action.unmount();
 const register=new Hooks(),rp={context:globalThis.__context,contextLoading:false,initial:{filters:{ID_StatutFk:'14'}},refresh:0,onChanged(){}},rr=()=>register.render(p.Register,rp);tree=rr();await register.flush();tree=rr();let table=mark(tree,'SimpleTable');eq(table.props.getRowId(globalThis.__record),42);table.props.onRowConsult(globalThis.__record);tree=rr();eq(mark(tree,'SupportDetail').props.id,42);table.props.onServerChange({skip:25});rr();await register.flush();const latest=globalThis.__calls.filter(c=>c.url.includes('/tickets?')).at(-1);eq(new URL(latest.url,'http://test').searchParams.get('skip'),'25');
 tree=rr();table=mark(tree,'SimpleTable');const toolbar=mark(table.props.toolbar,'Toolbar');toolbar.props.setSearch('texte');tree=rr();table=mark(tree,'SimpleTable');ok(mark(table.props.toolbar,'Toolbar').props.pending);mark(table.props.toolbar,'Toolbar').props.onApply();rr();await register.flush();tree=rr();table=mark(tree,'SimpleTable');await mark(table.props.toolbar,'Toolbar').props.exportFile();eq(globalThis.__downloads.length,1);let exported=new URL(globalThis.__downloads.at(-1).url,'http://test');eq(exported.searchParams.get('q'),'texte');eq(JSON.parse(exported.searchParams.get('filters')),{ID_StatutFk:'14'});eq(JSON.parse(exported.searchParams.get('columns')),['NumeroSupport','Objet']);
 const newTicketRegister=new Hooks(),ntr=()=>newTicketRegister.render(p.Register,{...rp,initialCreate:true});
 let newTree=ntr();ok(mark(newTree,'SupportEditor'));
 mark(newTree,'SupportEditor').props.onSaved(globalThis.__record,{startedJourney:true});
 newTree=ntr();eq(mark(newTree,'SupportDetail').props.id,42);eq(mark(newTree,'SupportDetail').props.initialTab,undefined);
 newTicketRegister.unmount();
 const journeyRegister=new Hooks(),jr=()=>journeyRegister.render(p.Register,{...rp,initialCreate:true,canReadJourney:true});
 newTree=jr();mark(newTree,'SupportEditor').props.onSaved(globalThis.__record,{startedJourney:true});
 newTree=jr();eq(mark(newTree,'SupportDetail').props.initialTab,'parcours');journeyRegister.unmount();
 const viewTabs=mark(tree,'Tabs');viewTabs.props.onChange('kanban');rr();await register.flush();tree=rr();ok(nodes(tree).some(node=>node.props?.className==='support-kanban-card'));let see=nodes(tree).find(node=>node.type?.name==='Button'&&Array.isArray(node.props.children)&&node.props.children[0]==='Voir les ');ok(see);eq(see.props.children[1],'45');see.props.onClick();rr();await register.flush();tree=rr();ok(mark(tree,'SimpleTable'));eq(mark(tree,'Tabs').props.value,'table');register.unmount();
 // Le Kanban vide propose une vraie action, selon les critères et le droit de création.
 globalThis.__kanban={columns:[{id:14,label:'Nouveau',count:0,rows:[],hasMore:false}]};const blank=new Hooks(),br=()=>blank.render(p.Register,{...rp,initial:{}});br();await blank.flush();tree=br();mark(tree,'Tabs').props.onChange('kanban');br();await blank.flush();tree=br();eq(mark(tree,'ListState').props.title,'Aucun dossier pour le moment');ok(button(tree,'Nouveau dossier'));button(tree,'Nouveau dossier').props.onClick();tree=br();ok(mark(tree,'SupportEditor'));blank.unmount();
 const pendingContext=new Hooks(),pcr=()=>pendingContext.render(p.Register,{...rp,initial:{},contextLoading:true});pcr();await pendingContext.flush();tree=pcr();mark(tree,'Tabs').props.onChange('kanban');pcr();await pendingContext.flush();tree=pcr();ok(button(tree,'Nouveau dossier').props.disabled);pendingContext.unmount();
 const filteredBlank=new Hooks(),fbr=()=>filteredBlank.render(p.Register,rp);fbr();await filteredBlank.flush();tree=fbr();mark(tree,'Tabs').props.onChange('kanban');fbr();await filteredBlank.flush();tree=fbr();eq(mark(tree,'ListState').props.title,'Aucun dossier pour ces critères');ok(button(tree,'Effacer les critères'));button(tree,'Effacer les critères').props.onClick();fbr();await filteredBlank.flush();tree=fbr();eq(mark(tree,'ListState').props.title,'Aucun dossier pour le moment');filteredBlank.unmount();
 const noCreate=new Hooks(),ncr=()=>noCreate.render(p.Register,{...rp,initial:{},context:{...globalThis.__context,canCreate:false}});ncr();await noCreate.flush();tree=ncr();mark(tree,'Tabs').props.onChange('kanban');ncr();await noCreate.flush();tree=ncr();eq(mark(tree,'ListState').props.action,null);noCreate.unmount();
 globalThis.__kanban={columns:[{id:14,label:'Nouveau',count:1,rows:[globalThis.__record]},{id:15,label:'Clos',count:0,rows:[]}]};const mixed=new Hooks(),mixedRender=()=>mixed.render(p.Register,{...rp,initial:{}});mixedRender();await mixed.flush();tree=mixedRender();mark(tree,'Tabs').props.onChange('kanban');mixedRender();await mixed.flush();tree=mixedRender();const lanes=nodes(tree).filter(node=>node.type?.name==='Button'&&Array.isArray(node.props.children)&&node.props.children[0]==='Voir les ');eq(lanes.length,2);eq(lanes.find(node=>node.props.children[1]==='0').props.disabled,true);eq(lanes.find(node=>node.props.children[1]==='1').props.disabled,false);mixed.unmount();delete globalThis.__kanban;
 globalThis.__dashboard={metrics:{ouverts:3,enAttente:1,enRetard:2,aEcheanceProchaine:1,sansResponsable:1,resolus:4,clotures:5,total:12},processes:{active:2,late:0,blocked:1,awaitingReceipt:1},charts:{parStatut:[{id:14,label:'Nouveau',count:3}],parPriorite:[{id:null,label:'Sans priorité',count:1},{id:4,label:'Urgente',count:3}]}};
 const dashboard=new Hooks(),navigation=[],dp={refresh:0,canReadProcesses:true,onChanged(){},onNavigate:(...args)=>navigation.push(args)},dr=()=>dashboard.render(p.Dashboard,dp);
 dr();await dashboard.flush();tree=dr();const panels=nodes(tree).filter(node=>node.type?.name==='MetricsPanel');
 eq(panels.map(panel=>panel.props.title),['À traiter','Activité des tickets','Suivi des étapes']);
 const cards=panels[0].type(panels[0].props),[overdue,upcoming,unassigned]=nodes(cards).filter(node=>node.type==='button');
 let focused=0,scrolled=0;const click={currentTarget:{isConnected:true,focus(){focused++;},scrollIntoView(){scrolled++;}}};
 eq(overdue.props['data-tone'],'danger');upcoming.props.onClick(click);tree=dr();
 const embedded=mark(tree,'SupportRegister');ok(embedded.props.embedded);eq(embedded.props.initial,{indicator:'echeance-prochaine'});
 eq(embedded.props.initialSort,{sortBy:'DateEcheance',sortDir:'asc'});eq(navigation,[]);
 const dueRegister=new Hooks();
 dueRegister.render(p.Register,{...rp,embedded:true,initial:embedded.props.initial,initialSort:embedded.props.initialSort});
 await dueRegister.flush();
 const dueQuery=new URL(globalThis.__calls.filter(call=>call.url.includes('/tickets?')).at(-1).url,'https://example.invalid').searchParams;
 eq(dueQuery.get('indicator'),'echeance-prochaine');eq(dueQuery.get('sortBy'),'DateEcheance');eq(dueQuery.get('sortDir'),'asc');
 dueRegister.unmount();
 button(tree,'Revenir à l’indicateur').props.onClick();eq(focused,1);eq(scrolled,1);tree=dr();ok(!mark(tree,'SupportRegister'));
 unassigned.props.onClick(click);tree=dr();eq(mark(tree,'SupportRegister').props.initial,{indicator:'sans-responsable'});
 const activity=nodes(panels[1].type(panels[1].props)).filter(node=>node.type==='button');
 activity[1].props.onClick(click);tree=dr();eq(mark(tree,'SupportRegister').props.initial,{indicator:'ouverts'});
 const distribution=nodes(tree).find(node=>node.type?.name==='Distribution'&&node.props.chart.key==='parPriorite');
 const chart=nodes(distribution.type(distribution.props)).find(node=>node.type==='button');
 ok(chart.props['aria-label'].includes('25'));eq(nodes(chart).find(node=>node.props.style?.width).props.style.width,'25%');
 chart.props.onClick(click);tree=dr();
 eq(mark(tree,'SupportRegister').props.initial,{filters:{ID_PrioriteFk:'__null__'}});
 const processPanel=nodes(tree).filter(node=>node.type?.name==='MetricsPanel')[2];
 const late=nodes(processPanel.type(processPanel.props)).filter(node=>node.type==='button')[1];ok(!late.props.disabled);late.props.onClick(click);tree=dr();
 eq(mark(tree,'ProcessMonitor').props.indicator,'late');mark(tree,'ProcessMonitor').props.onOpenTicket(42);tree=dr();eq(mark(tree,'SupportDetail').props.initialTab,'parcours');eq(mark(tree,'SupportDetail').props.id,42);
 button(tree,'Ouvrir les tickets').props.onClick();eq(navigation,[['tickets']]);dashboard.unmount();
 const restrictedDashboard=new Hooks(),rdr=()=>restrictedDashboard.render(p.Dashboard,{...dp,canReadProcesses:false});rdr();await restrictedDashboard.flush();tree=rdr();eq(nodes(tree).filter(node=>node.type?.name==='MetricsPanel').map(panel=>panel.props.title),['À traiter','Activité des tickets']);restrictedDashboard.unmount();
 const unified=new Hooks(),up={...rp,canReadJourney:true,context:{...rp.context,canReadProcessModels:true}},ur=()=>unified.render(p.Register,up);
 ur();await unified.flush();tree=ur();
 eq(mark(tree,'Tabs').props.tabs.map(tab=>tab.label),['Liste','Kanban']);ok(!mark(tree,'ProcessMonitor'));
 ok(!mark(mark(tree,'Surface').props.actions,'Settings').props.extraItems);
 const ticketActions=mark(mark(tree,'SimpleTable').props.columns.find(column=>column.key==='actions').render(globalThis.__record),'Actions');
 ticketActions.props.items.find(item=>item.label==='Voir les étapes').onSelect();tree=ur();
 eq(mark(tree,'SupportDetail').props.id,42);eq(mark(tree,'SupportDetail').props.initialTab,'parcours');unified.unmount();
 {
  const model={id:2,entityId:7,entityName:'École Pilote Test',name:'Dépannage',typeId:11,version:3,revision:9,active:true,stageCount:1,stages:[{name:'Diagnostic',validators:[]}]};
  globalThis.__models={available:true,canManage:true,canExport:true,count:42,items:[model],references:globalThis.__context.references,
    filterTypes:[{id:11,label:'Incident'},{id:23,label:'Plainte'}]};
  globalThis.__params=new URLSearchParams();
  globalThis.__navigation=[];
  const previousContext=globalThis.__context,previousScope=globalThis.__scope;
  const portal=new Hooks(),pr=()=>portal.render(p.Portal);
  tree=pr();await portal.flush();tree=pr();
  const menu=mark(tree,'Sidebar');
  eq(menu.props.groups.flatMap(group=>group.items.map(item=>item.label)),['Tableau de bord','Modèles de suivi','Tickets','Suivi des étapes']);
  menu.props.onNavigate('modeles');eq(globalThis.__navigation.at(-1),[{onglet:'modeles'}]);
  globalThis.__params=new URLSearchParams('onglet=modeles');tree=pr();
  const page=mark(tree,'SupportProcessModels'),models=new Hooks(),mr=()=>models.render(page.type,page.props);
  ok(page);ok(!mark(tree,'SupportRegister'));ok(!mark(tree,'SupportStageRegister'));
  tree=mr();eq(mark(tree,'ListState').props.title,'Chargement des modèles…');
  await models.flush();tree=mr();
  eq(mark(tree,'Surface').props.title,'Modèles de suivi');
  const modelQuery=()=>new URL(globalThis.__calls.filter(call=>call.url.includes('/processus?')).at(-1).url,'https://example.test').searchParams;
  const currentTable=()=>mark(tree,'SimpleTable'),modelToolbar=()=>mark(currentTable().props.toolbar,'Toolbar').props;
  eq(currentTable().props.tablePreferences.key,'support.modeles');eq(currentTable().props.serverMeta.filteredCount,42);
  ok(currentTable().props.enableSelection);eq(currentTable().props.getRowId(model),2);
  currentTable().props.onServerChange({skip:25});mr();await models.flush();tree=mr();eq(modelQuery().get('skip'),'25');
  modelToolbar().toggleFilters();modelToolbar().setSearch('  Dépannage ');tree=mr();ok(modelToolbar().pending);
  const typeFilter=field(currentTable().props.toolbar,'typeId');eq(typeFilter.props.options.map(option=>option.value),['','11','23']);
  typeFilter.props.onChange('23');field(currentTable().props.toolbar,'active').props.onChange('false');tree=mr();
  modelToolbar().onApply();mr();await models.flush();tree=mr();
  eq(modelQuery().get('q'),'Dépannage');eq(modelQuery().get('typeId'),'23');eq(modelQuery().get('active'),'false');eq(modelQuery().get('skip'),'0');
  await modelToolbar().exportCsv();
  let modelExport=new URL(globalThis.__downloads.at(-1).url,'https://example.test');
  eq(modelExport.pathname,'/api/support/processus/export.csv');eq(modelExport.searchParams.get('typeId'),'23');
  eq(JSON.parse(modelExport.searchParams.get('columns')),['name','stageCount']);
  currentTable().props.onSelectionChange([model]);tree=mr();await mark(tree,'ExportMenu').props.exportFile();
  modelExport=new URL(globalThis.__downloads.at(-1).url,'https://example.test');
  eq(modelExport.pathname,'/api/support/processus/export.xlsx');eq(JSON.parse(modelExport.searchParams.get('selection')),[2]);
  await button(mark(tree,'Surface').props.actions,'Télécharger le modèle Excel').props.onClick();
  eq(globalThis.__downloads.at(-1).url,'/api/support/processus/modele.xlsx');
  const modelSettings=mark(mark(tree,'Surface').props.actions,'Settings');
  ok(!modelSettings.props.onReferences);modelSettings.props.onTableSettings();tree=mr();ok(currentTable().props.columnsPanelOpen);
  const referenceAction=currentTable().props.tableSettingsActions.find(item=>item.label==='Références');ok(referenceAction);
  currentTable().props.onColumnsPanelClose();referenceAction.onSelect();tree=mr();ok(!currentTable().props.columnsPanelOpen);
  ok(mark(tree,'ModelReferences'));mark(tree,'ModelReferences').props.onClose();tree=mr();
  button(mark(tree,'Surface').props.actions,'Nouveau modèle').props.onClick();tree=mr();
  eq(mark(tree,'SupportProcessEditor').props.model,null);eq(mark(tree,'SupportProcessEditor').props.canManage,true);
  mark(tree,'SupportProcessEditor').props.onClose();tree=mr();
  currentTable().props.onRowConsult(model);tree=mr();
  eq(mark(tree,'SupportProcessEditor').props.model,model);ok(mark(tree,'SupportProcessEditor').props.readOnly);
  mark(tree,'SupportProcessEditor').props.onClose();tree=mr();
  const rowActions=()=>mark(currentTable().props.columns.find(column=>column.key==='actions').render(model),'Actions').props.items;
  eq(rowActions().map(item=>item.label),['Consulter','Modifier','Dupliquer','Désactiver']);
  rowActions().find(item=>item.label==='Dupliquer').onSelect();tree=mr();
  eq(mark(tree,'SupportProcessEditor').props.draft.name,'Dépannage (copie)');eq(mark(tree,'SupportProcessEditor').props.draft.active,false);
  mark(tree,'SupportProcessEditor').props.onClose();tree=mr();
  rowActions().find(item=>item.label==='Désactiver').onSelect();tree=mr();
  const activation=mark(tree,'ModelActivation'),ah=new Hooks();const dialog=ah.render(activation.type,activation.props);
  eq(mark(dialog,'Frame').props.title,'Désactiver le modèle');
  globalThis.__results.push({success:true,data:{...model,active:false}});mark(dialog,'Frame').props.onSubmit();await ah.flush();tree=mr();await models.flush();tree=mr();
  eq(globalThis.__writes.at(-1).url,'/api/support/processus/2');eq(JSON.parse(globalThis.__writes.at(-1).options.body).active,false);
  eq(JSON.parse(globalThis.__writes.at(-1).options.body).revision,9);ah.unmount();
  button(mark(tree,'Surface').props.actions,'Importer un fichier Excel').props.onClick();tree=mr();
  const batch=mark(tree,'SupportProcessBatch'),bh=new Hooks(),batchRender=()=>bh.render(batch.type,batch.props);
  let batchTree=batchRender();await bh.flush();batchTree=batchRender();
  const fileField=()=>nodes(batchTree).find(node=>node.type==='input'&&node.props.type==='file');
  const workbook=new File(['classeur'],'modeles.xlsx'),makeImportEvent=()=>({target:{files:[workbook],value:workbook.name}});
  globalThis.__results.push({success:true,data:{items:[
    {clientRowId:'excel-2',name:'Dépannage neuf',typeId:'Type inconnu',stages:[{name:''}]},
    {clientRowId:'excel-3',name:'Plainte fictive',typeId:11,stages:[{name:'Traitement'}]},
  ],errors:[{clientRowId:'excel-2',row:2,message:'Vérifiez le type et le nom de l’étape.'}]}});
  await fileField().props.onChange(makeImportEvent());batchTree=batchRender();await bh.flush();batchTree=batchRender();
  eq(globalThis.__writes.at(-1).url,'/api/support/processus/import.xlsx');
  eq(globalThis.__writes.at(-1).options.body.get('file').name,'modeles.xlsx');
  eq(mark(batchTree,'SupportProcessModelFields').props.values.active,true);
  eq(mark(batchTree,'SupportProcessModelFields').props.values.typeId,'Type inconnu');
  eq(mark(batchTree,'SupportProcessModelFields').props.values.stages[0].name,'');
  const beforeInvalid=globalThis.__writes.length;mark(batchTree,'Frame').props.onSubmit();batchTree=batchRender();
  eq(globalThis.__writes.length,beforeInvalid);
  let fields=mark(batchTree,'SupportProcessModelFields').props;
  fields.onChange({...fields.values,typeId:11,stages:[{...fields.values.stages[0],name:'Diagnostic'}]});batchTree=batchRender();
  mark(batchTree,'Frame').props.onSubmit();batchTree=batchRender();eq(globalThis.__writes.length,beforeInvalid);
  button(batchTree,'Confirmer la correction').props.onClick();batchTree=batchRender();
  globalThis.__results.push({success:false,status:422,message:'Le panier doit être corrigé.',
    error:{details:{errors:[{clientRowId:'excel-3',message:'Ce nom est déjà utilisé.'}]}}});
  mark(batchTree,'Frame').props.onSubmit();await bh.flush();batchTree=batchRender();await bh.flush();batchTree=batchRender();
  eq(JSON.parse(globalThis.__writes.at(-1).options.body).items.length,2);
  eq(mark(batchTree,'SupportProcessModelFields').props.values.name,'Plainte fictive');
  ok(nodes(batchTree).some(node=>node.props?.role==='alert'&&node.props.children==='Ce nom est déjà utilisé.'));
  nodes(batchTree).find(node=>node.props?.['aria-label']==='Retirer le modèle 2').props.onClick();batchTree=batchRender();
  globalThis.__results.push({success:false,status:503});mark(batchTree,'Frame').props.onSubmit();await bh.flush();batchTree=batchRender();
  const attempt=globalThis.__writes.at(-1);eq(attempt.url,'/api/support/processus/lot');eq(JSON.parse(attempt.options.body).items.length,1);
  eq(mark(batchTree,'Frame').props.submitLabel,'Vérifier l’enregistrement');ok(mark(batchTree,'SupportProcessModelFields').props.disabled);
  globalThis.__results.push({success:true,data:{items:[{id:3}],count:1}});mark(batchTree,'Frame').props.onSubmit();await bh.flush();
  eq(globalThis.__writes.at(-1).options.body,attempt.options.body);
  tree=mr();await models.flush();tree=mr();ok(!mark(tree,'SupportProcessBatch'));bh.unmount();
  rowActions().find(item=>item.label==='Modifier').onSelect();tree=mr();ok(!mark(tree,'SupportProcessEditor').props.readOnly);
  const beforeReload=globalThis.__calls.length;
  mark(tree,'SupportProcessEditor').props.onSaved();mr();await models.flush();tree=mr();
  ok(!mark(tree,'SupportProcessEditor'));ok(globalThis.__calls.slice(beforeReload).some(call=>call.url.startsWith('/api/support/processus?')));
  ok(nodes(tree).some(node=>node.props?.role==='status'));
  models.unmount();
  globalThis.__scope={scopeKey:'other',entityId:'8'};
  globalThis.__context={...previousContext,canReadProcessModels:false};
  tree=pr();ok(!mark(tree,'SupportProcessModels'));
  await portal.flush();tree=pr();
  ok(!mark(tree,'SupportProcessModels'));
  eq(mark(tree,'Sidebar').props.groups.flatMap(group=>group.items.map(item=>item.key)),['tableau-de-bord','tickets','processus']);
  portal.unmount();
  globalThis.__context=previousContext;

  globalThis.__scope={scopeKey:'all',globalAdmin:true,entities:[{id:7,label:'École Pilote Test'}]};
  const readonly=new Hooks(),ro=()=>readonly.render(page.type,page.props);
  ro();await readonly.flush();tree=ro();
  ok(mark(mark(tree,'Surface').props.actions,'Settings'));
  ok(!button(mark(tree,'Surface').props.actions,'Nouveau modèle'));
  const allTable=mark(tree,'SimpleTable'),allActions=allTable.props.columns.find(column=>column.key==='actions');
  eq(mark(allActions.render(model),'Actions').props.items.map(item=>item.label),['Consulter']);
  const modelName=allTable.props.columns.find(column=>column.key==='name');
  ok(nodes(modelName.render(model)).some(node=>node.type==='small'&&node.props.children==='École Pilote Test'));
  allTable.props.onRowConsult(model);tree=ro();
  eq(mark(tree,'SupportProcessEditor').props.canManage,false);
  readonly.unmount();
  globalThis.__scope=previousScope;

  globalThis.__context={...previousContext,canReadProcessModels:false};
  const denied=new Hooks(),restricted=()=>denied.render(p.Portal),beforeDenied=globalThis.__calls.length;
  tree=restricted();ok(nodes(tree).some(node=>node.props?.role==='status'));
  await denied.flush();tree=restricted();
  ok(!mark(tree,'SupportProcessModels'));
  eq(mark(tree,'Sidebar').props.groups.flatMap(group=>group.items.map(item=>item.key)),['tableau-de-bord','tickets','processus']);
  ok(nodes(tree).some(node=>node.props?.role==='alert'&&node.props.children.includes('pas accès')));
  eq(globalThis.__calls.slice(beforeDenied).map(call=>call.url),['/api/support/presentation','/api/support/contexte']);
  denied.unmount();
  globalThis.__context=previousContext;
  delete globalThis.__params;delete globalThis.__navigation;delete globalThis.__models;
 }
 {
  globalThis.__params=new URLSearchParams('onglet=tickets&vue=suivi&source=ancien-lien');
  globalThis.__navigation=[];
  const beforeStages=globalThis.__calls.length,portal=new Hooks(),pr=()=>portal.render(p.Portal);
  tree=pr();
  ok(!mark(tree,'SupportRegister'));
  await portal.flush();
  tree=pr();
  const sidebar=mark(tree,'Sidebar');
  eq(sidebar.props.activeKey,'processus');
  eq(sidebar.props.groups.find(group=>group.key==='traitement').items.map(item=>item.label),['Tickets','Suivi des étapes']);
  ok(!mark(tree,'SupportRegister'));
  eq(globalThis.__navigation[0][0].toString(),'onglet=processus&source=ancien-lien');
  eq(globalThis.__navigation[0][1],{replace:true});

  globalThis.__params=globalThis.__navigation[0][0];tree=pr();await portal.flush();tree=pr();
  const follow=mark(tree,'SupportStageRegister'),stage=new Hooks(),sr=()=>stage.render(p.SupportStageRegister,follow.props);
  ok(follow);eq(follow.props.context,globalThis.__context);
  tree=sr();eq(mark(tree,'Surface').props.title,'Suivi des étapes');
  const stageActions=mark(tree,'Surface').props.actions;
  button(stageActions,'Modèles de suivi').props.onClick();eq(globalThis.__navigation.at(-1),[{onglet:'modeles'}]);
  button(stageActions,'Voir les tickets').props.onClick();eq(globalThis.__navigation.at(-1),[{onglet:'tickets'}]);
  const stageSettings=mark(stageActions,'Settings');
  stageSettings.props.onTableSettings();
  tree=sr();
  ok(mark(mark(tree,'Surface').props.actions,'Settings').props.expanded);
  const monitorProps=mark(tree,'ProcessMonitor').props,monitor=new Hooks(),mor=()=>monitor.render(p.ProcessMonitor,monitorProps);
  eq(monitorProps.columnsAnchorRef,stageSettings.props.buttonRef);
  globalThis.__monitor={available:true,count:0,items:[]};
  mor();await monitor.flush();tree=mor();
  const emptyMonitor=mark(tree,'SimpleTable').props;
  eq(emptyMonitor.emptyState.props.title,'Aucun parcours démarré');
  eq(emptyMonitor.emptyState.props.action,null);
  ok(emptyMonitor.columnsPanelOpen);
  emptyMonitor.onColumnsPanelClose();
  ok(!mark(sr(),'ProcessMonitor').props.columnsPanelOpen);
  let newTickets=0;
  tree=stage.render(p.SupportStageRegister,{...follow.props,context:{...follow.props.context,canStartJourneyOnCreate:true},
   onNewTicket:()=>newTickets++});
  const createProps=mark(tree,'ProcessMonitor').props;
  const creation=new Hooks(),cr=()=>creation.render(p.ProcessMonitor,createProps);
  cr();await creation.flush();tree=cr();
  button(mark(tree,'SimpleTable').props.emptyState,'Nouveau dossier').props.onClick();eq(newTickets,1);
  creation.render(p.ProcessMonitor,{...createProps,indicator:'late'});
  await creation.flush();tree=creation.render(p.ProcessMonitor,{...createProps,indicator:'late'});
  ok(!mark(tree,'SimpleTable').props.emptyState);eq(mark(tree,'SimpleTable').props.emptyMessage,'Aucun parcours pour ces critères.');
  creation.unmount();
  globalThis.__monitor={available:true,count:1,items:[{ticketId:42,number:'SUP-42',stageName:'Diagnostic'}]};
  const populated=new Hooks(),pop=()=>populated.render(p.ProcessMonitor,monitorProps);
  pop();await populated.flush();tree=pop();
  const monitorTable=mark(tree,'SimpleTable');
  eq(monitorTable.props.rows[0].stageName,'Diagnostic');
  ok(monitorTable.props.consultColumns.includes('stageName'));
  eq(monitorTable.props.defaultVisibleColumns.at(-1),'actions');
  ok(monitorTable.props.columns.some(column=>column.key==='globalDueAt'));
  ok(mark(monitorTable.props.toolbar,'Toolbar'));
  const openJourney=nodes(monitorTable.props.columns.find(column=>column.key==='actions').render(monitorTable.props.rows[0])).find(node=>node.type==='button');
  eq(openJourney.props['aria-label'],'Ouvrir le parcours de SUP-42');
  openJourney.props.onClick();eq(mark(sr(),'SupportDetail').props.id,42);
  monitorTable.props.onRowConsult(monitorTable.props.rows[0]);tree=sr();
  eq(mark(tree,'SupportDetail').props.id,42);eq(mark(tree,'SupportDetail').props.initialTab,'parcours');
  tree=populated.render(p.ProcessMonitor,{...monitorProps,refresh:1});
  eq(mark(tree,'SimpleTable').props.loading,true);
  eq(mark(tree,'SimpleTable').props.rows,monitorTable.props.rows);
  await populated.flush();
  ok(globalThis.__calls.slice(beforeStages).some(call=>call.url.includes('/processus/suivi?')));
  ok(!globalThis.__calls.slice(beforeStages).some(call=>call.url.includes('/tickets?')));
  populated.unmount();monitor.unmount();stage.unmount();portal.unmount();
  const previousAccess=globalThis.__user.moduleAccess;
  globalThis.__user.moduleAccess={...previousAccess,tabs:{support:{processus:{canRead:false}}}};
  for(const url of ['onglet=processus','onglet=tickets&vue=suivi']){
   globalThis.__params=new URLSearchParams(url);
   const restricted=new Hooks(),beforeDenied=globalThis.__calls.length;
   restricted.render(p.Portal);await restricted.flush();tree=restricted.render(p.Portal);
   ok(!mark(tree,'SupportStageRegister'));
   eq(mark(tree,'Sidebar').props.groups.find(group=>group.key==='traitement').items.map(item=>item.key),['tickets']);
   ok(nodes(tree).some(node=>node.props?.role==='alert'&&node.props.children.includes('pas accès')));
   eq(globalThis.__calls.slice(beforeDenied).map(call=>call.url),['/api/support/presentation']);restricted.unmount();
  }
  globalThis.__user.moduleAccess=previousAccess;
  delete globalThis.__params;delete globalThis.__navigation;delete globalThis.__monitor;
 }
 {
  globalThis.__supportPresentation={tabLabels:{tickets:'Demandes internes'},hiddenTabs:['tableau-de-bord','modeles','processus'],hiddenDashboardBlocks:['attention']};
  globalThis.__params=new URLSearchParams();
  const presentation=new Hooks(),render=()=>presentation.render(p.Portal);
  render();await presentation.flush();tree=render();
  eq(mark(tree,'Sidebar').props.groups.flatMap(group=>group.items.map(item=>item.label)),['Demandes internes']);
  eq(mark(tree,'SupportRegister').props.title,'Demandes internes');
  globalThis.__params=new URLSearchParams('onglet=tableau-de-bord');
  eq(mark(render(),'SupportDashboard').props.hiddenDashboardBlocks,['attention']);
  presentation.unmount();
  delete globalThis.__supportPresentation;delete globalThis.__params;
 }
 const embeddedHooks=new Hooks(),er=()=>embeddedHooks.render(p.Register,{...rp,embedded:true,initial:{indicator:'retard',filters:{ID_StatutFk:'14'}}});
 er();await embeddedHooks.flush();tree=er();let embeddedToolbar=mark(mark(tree,'SimpleTable').props.toolbar,'Toolbar');
 eq(embeddedToolbar.props.activeFilters,0);embeddedToolbar.props.setSearch('Incident');tree=er();mark(mark(tree,'SimpleTable').props.toolbar,'Toolbar').props.onApply();er();await embeddedHooks.flush();
 tree=er();embeddedToolbar=mark(mark(tree,'SimpleTable').props.toolbar,'Toolbar');await embeddedToolbar.props.exportFile();
 exported=new URL(globalThis.__downloads.at(-1).url,'http://test');eq(exported.searchParams.get('indicator'),'retard');eq(exported.searchParams.get('q'),'Incident');eq(JSON.parse(exported.searchParams.get('filters')),{ID_StatutFk:'14'});
 embeddedToolbar.props.onReset();er();await embeddedHooks.flush();const resetUrl=new URL(globalThis.__calls.at(-1).url,'http://test');eq(resetUrl.searchParams.get('indicator'),'retard');eq(resetUrl.searchParams.get('q'),null);embeddedHooks.unmount();
 const detail=new Hooks(),ddp={id:42,context:globalThis.__context,onClose(){},onChanged(){}},ddr=()=>detail.render(p.Detail,ddp);ddr();await detail.flush();tree=ddr();eq(mark(tree,'Frame').props.title,'Support · SUP-42');eq(mark(tree,'Tabs').props.tabs.length,5);ok(mark(tree,'SupportComments'));ok(mark(tree,'SupportDocuments'));const commentComponent=mark(tree,'SupportComments'),documentComponent=mark(tree,'SupportDocuments');mark(tree,'SupportComments').props.onDraftChange(true);tree=ddr();ok(mark(tree,'Frame').props.dirty);ok(button(tree,'Modifier le ticket').props.disabled);ok(button(tree,'Modifier le suivi').props.disabled);mark(tree,'SupportComments').props.onBusyChange(true);tree=ddr();ok(mark(tree,'Frame').props.busy);detail.unmount();eq(p.supportHistoryLabel('COMMENT'),'Message ajouté');
 const editableDetail=new Hooks();
 let editChanges=0,detailCloses=0;
 const editDetailProps={...ddp,initialTab:'parcours',canReadJourney:true,onChanged:()=>editChanges++,onClose:()=>detailCloses++};
 const renderEditableDetail=()=>editableDetail.render(p.Detail,editDetailProps);
 renderEditableDetail();await editableDetail.flush();tree=renderEditableDetail();
 const frame=mark(tree,'Frame');
 let focusRestored=0;
 button(tree,'Modifier le ticket').props.ref({focus:()=>focusRestored++});
 button(tree,'Modifier le ticket').props.onClick();tree=renderEditableDetail();
 eq(nodes(tree).filter(node=>node.type===frame.type).length,1);eq(mark(tree,'Frame').props.title,'Modifier le ticket');
 eq(field(tree,'Objet').props.value,globalThis.__record.Objet);ok(!field(tree,'ID_ResponsableFk'));
 eq(mark(tree,'Frame').props.canSubmit,false);
 field(tree,'Objet').props.onChange({target:{value:'Modification à abandonner'}});tree=renderEditableDetail();
 ok(mark(tree,'Frame').props.dirty);
 mark(tree,'Frame').props.onClose();tree=renderEditableDetail();await editableDetail.flush();
 eq(mark(tree,'Tabs').props.value,'parcours');eq(focusRestored,1);eq(detailCloses,0);
 button(tree,'Modifier le suivi').props.onClick();tree=renderEditableDetail();
 eq(mark(tree,'Frame').props.title,'Modifier le suivi');ok(!field(tree,'Objet'));ok(field(tree,'ID_PrioriteFk'));
 eq(field(tree,'ID_ResponsableFk').props.value,'1');
 field(tree,'DateEcheance').props.onChange({target:{value:'2026-11-18T10:20'}});
 tree=renderEditableDetail();
 const previousDetail=globalThis.__detail;
 globalThis.__detail={...previousDetail,record:{...previousDetail.record,DateEcheance:'2026-11-18T10:20:00+01:00',_version:'v2'}};
 globalThis.__results.push({success:true,data:globalThis.__detail.record});
 await mark(tree,'Frame').props.onSubmit();tree=renderEditableDetail();
 const patch=JSON.parse(globalThis.__writes.at(-1).options.body);
 eq(patch.DateEcheance,'2026-11-18T10:20:00+01:00');eq(patch._version,'v1');
 eq(Object.keys(patch).sort(),['DateEcheance','_version','requestId']);
 eq(mark(tree,'Frame').props.title,'Support · SUP-42');ok(!mark(tree,'Frame').props.loading);
 eq(mark(tree,'Tabs').props.value,'parcours');eq(editChanges,1);eq(detailCloses,0);
 await editableDetail.flush();editableDetail.unmount();globalThis.__detail=previousDetail;
 for(const canEdit of [true,false]){
  globalThis.__detail={...previousDetail,canEdit};
  const direct=new Hooks(),renderDirect=()=>direct.render(p.Detail,{...ddp,initialEdit:'suivi'});
  tree=renderDirect();eq(mark(tree,'Frame').props.title,'Modifier le suivi');ok(mark(tree,'Frame').props.loading);
  await direct.flush();tree=renderDirect();
  eq(mark(tree,'Frame').props.title,canEdit?'Modifier le suivi':'Support · SUP-42');
  eq(Boolean(field(tree,'DateEcheance')),canEdit);
  direct.unmount();
 }
 globalThis.__detail=previousDetail;
 const rowEditor=new Hooks(),re=()=>rowEditor.render(p.Register,rp);
 re();await rowEditor.flush();tree=re();
 const menu=mark(mark(tree,'SimpleTable').props.columns.find(column=>column.key==='actions').render(globalThis.__record),'Actions');
 for(const [label,mode] of [['Modifier le ticket','ticket'],['Modifier le suivi','suivi']]){
  menu.props.items.find(item=>item.label===label).onSelect();
  eq(mark(re(),'SupportDetail').props.initialEdit,mode);
 }
 rowEditor.unmount();
 const comments=new Hooks(),commentSaved=[],commentDirty=[],commentProps={...commentComponent.props,onSaved:value=>commentSaved.push(value),onDraftChange:value=>commentDirty.push(value),onBusyChange(){}},co=()=>comments.render(commentComponent.type,commentProps);tree=co();await comments.flush();before=globalThis.__writes.length;await button(tree,'Ajouter le message').props.onClick();eq(globalThis.__writes.length,before);tree=co();ok(nodes(tree).some(node=>node.props?.role==='alert'));nodes(tree).find(node=>node.type==='textarea').props.onChange({target:{value:' Message de suivi '}});tree=co();await comments.flush();ok(commentDirty.at(-1));mark(tree,'Select').props.onChange('interne');tree=co();globalThis.__results.push({success:false,status:503});await button(tree,'Ajouter le message').props.onClick();tree=co();const commentAttempt=globalThis.__writes.at(-1);eq(commentAttempt.url,'/api/support/tickets/42/commentaires');eq(JSON.parse(commentAttempt.options.body).Contenu,'Message de suivi');eq(JSON.parse(commentAttempt.options.body).Visibilite,'interne');eq(JSON.parse(commentAttempt.options.body)._version,'v1');ok(nodes(tree).find(node=>node.type==='textarea').props.disabled);globalThis.__results.push({success:true,data:globalThis.__detail});await button(tree,'Vérifier l’enregistrement').props.onClick();eq(globalThis.__writes.at(-1).options.body,commentAttempt.options.body);eq(commentSaved.length,1);tree=co();await comments.flush();eq(nodes(tree).find(node=>node.type==='textarea').props.value,'');ok(!commentDirty.at(-1));comments.unmount();
 const documents=new Hooks(),docSaved=[],docProps={...documentComponent.props,onSaved:value=>docSaved.push(value),onDraftChange(){},onBusyChange(){}},du=()=>documents.render(documentComponent.type,docProps);tree=du();await documents.flush();before=globalThis.__writes.length;await button(tree,'Ajouter le justificatif').props.onClick();eq(globalThis.__writes.length,before);tree=du();let picker=nodes(tree).find(node=>node.type==='input'&&node.props.type==='file');picker.props.onChange({target:{files:[{type:'text/html',size:10}]}});tree=du();ok(nodes(tree).some(node=>node.props?.role==='alert'&&node.props.children.includes('PDF')));const sample=new File([new Uint8Array([1,2,3])],'preuve.pdf',{type:'application/pdf'});picker=nodes(tree).find(node=>node.type==='input'&&node.props.type==='file');picker.props.onChange({target:{files:[sample]}});tree=du();globalThis.__results.push({success:false,status:503});await button(tree,'Ajouter le justificatif').props.onClick();tree=du();const docAttempt=globalThis.__writes.at(-1);eq(docAttempt.url,'/api/support/tickets/42/documents');ok(docAttempt.options.body instanceof FormData);eq(docAttempt.options.body.get('_version'),'v1');eq(docAttempt.options.body.get('file').name,'preuve.pdf');ok(nodes(tree).find(node=>node.type==='input'&&node.props.type==='file').props.disabled);globalThis.__results.push({success:true,data:globalThis.__detail});await button(tree,'Vérifier l’enregistrement').props.onClick();eq(globalThis.__writes.at(-1).options.body,docAttempt.options.body);eq(docSaved.length,1);documents.unmount();
 const downloads=new Hooks(),downloadProps={...docProps,rows:[{ID_PieceFk:81,NomFichier:'preuve.pdf',MimeType:'application/pdf'}],canManage:false},dl=()=>downloads.render(documentComponent.type,downloadProps);tree=dl();await downloads.flush();const docsTable=mark(tree,'SimpleTable');eq(docsTable.props.getRowId(downloadProps.rows[0]),81);await docsTable.props.columns.find(column=>column.key==='actions').render(downloadProps.rows[0]).props.onClick();eq(globalThis.__downloads.at(-1).url,'/api/support/tickets/42/documents/81/download');eq(globalThis.__downloads.at(-1).options.contentType,'application/pdf');ok(!nodes(tree).some(node=>node.type==='input'&&node.props.type==='file'));downloads.unmount();
 ok(p.supportValidation(initial,['ID_PrioriteFk']).ID_PrioriteFk);ok(p.supportValidation({...initial,Objet:'a'.repeat(201)}).Objet);globalThis.__detail={...globalThis.__detail,record:{...globalThis.__record,ID_Support:99}};const wrong=new Hooks();wrong.render(p.Detail,ddp);await wrong.flush();tree=wrong.render(p.Detail,ddp);ok(mark(tree,'Frame').props.error.includes('ne correspond'));ok(!mark(tree,'SupportComments'));wrong.unmount();globalThis.__detail={...globalThis.__detail,record:globalThis.__record};
 for(const closed of [{Archive:false,StatutCode:'closed'},{Archive:true,StatutCode:'closed'}]){globalThis.__detail={...globalThis.__detail,record:{...globalThis.__record,...closed},canManage:true,canEdit:false,canComment:false,canUpload:false,transitions:[{key:closed.Archive?'restore':'reopen',label:closed.Archive?'Restaurer':'Rouvrir le dossier',requiresReason:true}]};const frozen=new Hooks();frozen.render(p.Detail,ddp);await frozen.flush();tree=frozen.render(p.Detail,ddp);ok(!button(tree,'Modifier le ticket'));ok(!button(tree,'Modifier le suivi'));ok(button(tree,closed.Archive?'Restaurer':'Rouvrir le dossier'));eq(mark(tree,'SupportComments').props.canManage,false);eq(mark(tree,'SupportDocuments').props.canManage,false);frozen.unmount();}
 globalThis.__detail={...globalThis.__detail,record:globalThis.__record};eq(p.supportHistoryLabel('start'),'Prise en charge');eq(p.supportHistoryLabel('verify'),'Vérification de la résolution');
 const isolated=new Hooks(),ir=()=>isolated.render(p.Register,rp);ir();await isolated.flush();tree=ir();eq(mark(tree,'SimpleTable').props.rows[0].ID_Support,42);let release;globalThis.__holdReads=new Promise(resolve=>release=resolve);globalThis.__scope={scopeKey:'B',entityId:'8'};tree=ir();eq(mark(tree,'SimpleTable').props.rows,[]);await isolated.flush();tree=ir();eq(mark(tree,'SimpleTable').props.rows,[]);ok(mark(tree,'SimpleTable').props.loading);release({success:true,data:[{...globalThis.__record,ID_Support:43,Objet:'Autre entreprise'}],meta:globalThis.__meta});await isolated.flush();tree=ir();eq(mark(tree,'SimpleTable').props.rows[0].ID_Support,43);isolated.unmount();delete globalThis.__holdReads;globalThis.__scope={scopeKey:'A',entityId:'7'};
 const catalogueSource=fs.readFileSync(path.join(root,'backend/database/migrations/20261030_06_support.sql'),'utf8').split('FOR item IN SELECT * FROM (VALUES').at(-1).split('AS c(id,label,type,visible)')[0];const catalogue=[...catalogueSource.matchAll(/\('([^']+)','[^']+','[^']+',(?:true|false)\)/g)].map(match=>match[1]);eq(catalogue.length,17);
 const configurable=new Hooks(),conf=()=>configurable.render(p.Register,rp);conf();await configurable.flush();tree=conf();const configuredTable=mark(tree,'SimpleTable');for(const key of catalogue)ok(configuredTable.props.columns.some(column=>column.key===key),'Colonne du catalogue sans présentation : '+key);const service=configuredTable.props.columns.find(column=>column.key==='ServiceConcerne');eq(service.render({ServiceConcerne:'Maintenance générale'}),'Maintenance générale');
 const realTable=await bundle(`export {SimpleTable} from './src/pages/logistique/logistiqueShared';`,[mocks([
  [/^react$/,'table-hooks',`export const useState=v=>globalThis.__hooks.state(v),useRef=v=>globalThis.__hooks.ref(v),useMemo=f=>f(),useEffect=(f,d)=>globalThis.__hooks.effect(f,d),useLayoutEffect=(f,d)=>globalThis.__hooks.effect(f,d);`],
  [/(CategoricalSelect|TablePagination|ColumnPicker|TableSettings|AppIcon|ActionButton)$/,'table-component',`export default function Component(){return null;}`],
 ])]);
 const actual=new Hooks(),serviceTree=actual.render(realTable.SimpleTable,{...configuredTable.props,rows:[{...globalThis.__record,ServiceConcerne:'Maintenance générale'}],tablePreferences:{ready:true,tableKeys:['ServiceConcerne'],exportKeys:['ServiceConcerne'],catalogue:[]},showControls:false,enableSelection:false});eq(nodes(serviceTree).filter(node=>node.type==='th').length,1);ok(nodes(serviceTree).some(node=>node.type==='div'&&node.props.className==='admin-header-label'&&node.props.children==='Service concerné'));ok(nodes(serviceTree).some(node=>node.type==='td'&&node.props.children==='Maintenance générale'));const allColumns=new Hooks(),allTree=allColumns.render(realTable.SimpleTable,{...configuredTable.props,tablePreferences:{ready:true,tableKeys:catalogue,exportKeys:catalogue.filter(key=>key!=='actions'),catalogue:[]},showControls:false,enableSelection:false});eq(nodes(allTree).filter(node=>node.type==='th').length,17);configurable.unmount();
 for(const file of fs.readdirSync(path.join(front,'src/pages/support'))){if(!/\.(jsx?|css)$/.test(file))continue;const source=fs.readFileSync(path.join(front,'src/pages/support',file),'utf8');ok(!/[ÃÂ]|â€™|â€”/.test(source),'UTF-8 invalide '+file);}
 {
 const batch=await bundle(`export * from './src/pages/support/supportBatch';export {default as Batch} from './src/pages/support/SupportBatchEditor';`,[fixture]);
 const batchContext={...globalThis.__context,requiredFields:['Objet','Description','ID_TypeSupportFk','ID_PrioriteFk','ID_CanalOrigineFk'],defaults:{ID_TypeSupportFk:11,ID_PrioriteFk:13,ID_CanalOrigineFk:15}};
 const imported=batch.supportExcelRows([['Objet','Description','ID_TypeSupportFk','DateEcheance'],['Incident Excel','Conserver la description','Incident','2026-11-07T09:30:00']],batchContext,()=> 'stable-1');eq(imported[0].clientRowId,'stable-1');eq(imported[0].data.ID_TypeSupportFk,'11');eq(imported[0].data.DateEcheance,'2026-11-07T09:30');eq(batch.supportBatchValidation(imported,batchContext),{});eq(batch.supportBatchPayload(imported,'request').rows[0].data.DateEcheance,'2026-11-07T09:30:00+01:00');ok(!Object.hasOwn(batch.supportBatchPayload(imported,'request').rows[0].data,'requestId'));
 assert.throws(()=>batch.supportExcelRows([['Objet'],...Array.from({length:101},()=>['x'])],batchContext),/100/);checks++;
 ok(batch.supportBatchValidation([{...imported[0],data:{...imported[0].data,ID_ResponsableFk:'999'}}],batchContext)['stable-1'].ID_ResponsableFk);
 const basket=new Hooks(),basketSaved=[],basketProps={context:batchContext,onClose(){},onSaved:result=>basketSaved.push(result)},br=()=>basket.render(batch.Batch,basketProps);tree=br();await basket.flush();eq(mark(tree,'Frame').props.canSubmit,false);
 globalThis.__results=[];globalThis.__results.push({success:true,data:{matrix:[['Objet','Description'],['Import A','Description A'],['Import B','Description B']]}});let fileInput=nodes(tree).find(node=>node.type==='input'&&node.props.type==='file');const excel=new File(['archive simulée'],'tickets.xlsx');before=globalThis.__writes.length;await fileInput.props.onChange({target:{files:[excel],value:'tickets.xlsx'}});tree=br();eq(globalThis.__writes.length,before+1);eq(globalThis.__writes.at(-1).url,'/api/support/tickets/import-excel');ok(globalThis.__writes.at(-1).options.body instanceof FormData);eq(globalThis.__writes.at(-1).options.body.get('fichier').name,'tickets.xlsx');eq(field(tree,'Objet').props.value,'Import A');ok(mark(tree,'Frame').props.dirty);
 field(tree,'Objet').props.onChange({target:{value:'Corrigé dans le panier'}});tree=br();eq(field(tree,'Objet').props.value,'Corrigé dans le panier');
 globalThis.__results.push({success:false,status:422,error:{details:{rows:{}}}});await mark(tree,'Frame').props.onSubmit();tree=br();let batchAttempt=globalThis.__writes.at(-1);eq(batchAttempt.url,'/api/support/tickets/batch');let batchBody=JSON.parse(batchAttempt.options.body);eq(batchBody.rows.length,2);eq(batchBody.rows[0].data.Objet,'Corrigé dans le panier');ok(batchBody.rows[0].clientRowId);eq(field(tree,'Description').props.value,'Description A');ok(!field(tree,'Objet').props.disabled);
 const rowId=batchBody.rows[1].clientRowId;globalThis.__results.push({success:false,status:422,error:{details:{rows:{[rowId]:{Description:'Description à préciser'}}}}});await mark(tree,'Frame').props.onSubmit();tree=br();eq(field(tree,'Objet').props.value,'Import B');eq(field(tree,'Description').props['aria-invalid'],true);eq(field(tree,'Description').props.value,'Description B');
 field(tree,'Description').props.onChange({target:{value:'Description B corrigée'}});tree=br();globalThis.__results.push({success:false,status:503});await mark(tree,'Frame').props.onSubmit();tree=br();batchAttempt=globalThis.__writes.at(-1);eq(mark(tree,'Frame').props.submitLabel,'Vérifier l’enregistrement');ok(field(tree,'Objet').props.disabled);before=globalThis.__writes.length;field(tree,'Objet').props.onChange({target:{value:'Interdit'}});tree=br();eq(field(tree,'Objet').props.value,'Import B');globalThis.__results.push({success:true,data:{count:2,records:[]}});await mark(tree,'Frame').props.onSubmit();eq(globalThis.__writes.at(-1).options.body,batchAttempt.options.body);eq(basketSaved.length,1);basket.unmount();
 const deniedBasket=new Hooks(),deniedRender=()=>deniedBasket.render(batch.Batch,{...basketProps,context:{...batchContext,canCreate:false}});tree=deniedRender();await deniedBasket.flush();ok(mark(tree,'Frame').props.readOnly);ok(nodes(tree).find(node=>node.props?.type==='file').props.disabled);before=globalThis.__writes.length;await mark(tree,'Frame').props.onSubmit();eq(globalThis.__writes.length,before);deniedBasket.unmount();
 const revoked=new Hooks(),revokedProps={...basketProps},rv=()=>revoked.render(batch.Batch,revokedProps);tree=rv();await revoked.flush();let finishRevoked;globalThis.__results.push(new Promise(resolve=>{finishRevoked=resolve;}));const revokedUpload=nodes(tree).find(node=>node.props?.type==='file').props.onChange({target:{files:[excel],value:'x'}});revokedProps.context={...batchContext,canCreate:false};tree=rv();finishRevoked({success:true,data:{matrix:[['Objet','Description'],['Réponse ignorée','Description']]}});await revokedUpload;tree=rv();ok(!field(tree,'Objet'));eq(mark(tree,'Frame').props.busy,false);revokedProps.context=batchContext;tree=rv();ok(!nodes(tree).find(node=>node.props?.type==='file').props.disabled);
 globalThis.__results.push({success:true,data:{matrix:[['Objet','Description','ID_TypeSupportFk','DateEcheance'],['À corriger','Description','Type inconnu importé','demain après-midi à confirmer']]}});await nodes(tree).find(node=>node.props?.type==='file').props.onChange({target:{files:[excel],value:'x'}});tree=rv();eq(field(tree,'DateEcheance').props.type,'text');eq(field(tree,'DateEcheance').props.value,'demain après-midi à confirmer');ok(field(tree,'DateEcheance').props['aria-invalid']);field(tree,'DateEcheance').props.onChange({target:{value:''}});tree=rv();eq(field(tree,'DateEcheance').props.type,'datetime-local');const unknownType=field(tree,'ID_TypeSupportFk');eq(unknownType.props.value,'Type inconnu importé');ok(unknownType.props.invalid);eq(unknownType.props.options.at(-1),{value:'Type inconnu importé',label:'Valeur à vérifier : Type inconnu importé',disabled:true});unknownType.props.onChange('11');tree=rv();field(tree,'Objet').props.onChange({target:{value:'Correction conservée'}});tree=rv();globalThis.__results.push({success:true,data:{matrix:[['Objet','Description'],['Second fichier','Autre description']]}});await nodes(tree).find(node=>node.props?.type==='file').props.onChange({target:{files:[excel],value:'x'}});tree=rv();eq(field(tree,'Objet').props.value,'Second fichier');eq(mark(tree,'Frame').props.submitLabel,'Enregistrer le panier (2)');const rowNav=nodes(tree).find(node=>node.type==='nav'&&node.props['aria-label']==='Dossiers du panier');nodes(rowNav).find(node=>node.type==='button').props.onClick();tree=rv();eq(field(tree,'Objet').props.value,'Correction conservée');const removeFirst=nodes(tree).find(node=>node.type?.name==='Button'&&node.props['aria-label']==='Retirer le dossier 1');removeFirst.props.onClick();tree=rv();eq(mark(tree,'Frame').props.submitLabel,'Enregistrer le panier (1)');eq(field(tree,'Objet').props.value,'Second fichier');revoked.unmount();
 const obsolete=new Hooks(),ob=()=>obsolete.render(batch.Batch,basketProps);tree=ob();await obsolete.flush();let release;const pendingUpload=new Promise(resolve=>{release=resolve;});globalThis.__results.push(pendingUpload);fileInput=nodes(tree).find(node=>node.props?.type==='file');const uploadPending=fileInput.props.onChange({target:{files:[excel],value:'x'}});globalThis.__scope={scopeKey:'OTHER',entityId:'8'};tree=ob();await obsolete.flush();release({success:true,data:{matrix:[['Objet','Description'],['Ancienne entreprise','Description']]}});await uploadPending;tree=ob();ok(mark(tree,'Frame').props.error.includes('entreprise a changé'));ok(!field(tree,'Objet'));obsolete.unmount();globalThis.__scope={scopeKey:'A',entityId:'7'};
 }
 const process=await bundle(`
   export {processQuery} from './src/pages/support/supportProcess';
   export {processModelPayload} from './src/pages/support/SupportProcessEditor';
 `,[fixture]);
 const payload=process.processModelPayload({
   name:'  Traitement ',description:' ',typeId:'11',active:true,revision:3,globalMinutes:'90',
   stages:[{name:' Revue ',validators:[{target:'userId',userId:'2'}],requiresReceipt:true,
     blockerReasonIds:['41'],returnReasonIds:['42'],rejectReasonIds:['43']}],
 },'requete-fictive');
 eq(payload.name,'Traitement');
 eq(payload.typeId,11);
 eq(payload.revision,3);
 eq(payload.stages[0],{
   name:'Revue',serviceId:null,roleId:null,responsibleId:null,minutes:null,
   requiresReceipt:true,allowReturn:false,requiresDocument:false,requiredInformation:'',
   validators:[{userId:2}],blockerReasonIds:[41],returnReasonIds:[42],rejectReasonIds:[43],
 });
 eq(Object.fromEntries(new URLSearchParams(process.processQuery({q:' dossier ',blocked:'false',stage:''},3,10))),
   {q:' dossier ',blocked:'false',take:'10',skip:'20'});

 const processDetail=new Hooks();
 const processDetailProps={...ddp,canReadJourney:true,initialTab:'parcours'};
 processDetail.render(p.Detail,processDetailProps);
 await processDetail.flush();
 const journeyComponent=mark(processDetail.render(p.Detail,processDetailProps),'SupportJourney');
 ok(journeyComponent.props.active);
 const visibleTabs=mark(processDetail.render(p.Detail,processDetailProps),'Tabs').props.tabs;
 eq(visibleTabs.length,6);
 globalThis.__journey={available:true,run:{
   modelName:'Traitement',version:2,revision:5,
   current:{id:70,name:'Revue',rejectReasons:[{id:43,label:'Contrôle incomplet'}]},
   steps:[],history:[],alerts:[{id:1,type:'stage',position:1,occurrence:1,status:'failed'}],
   actions:[{key:'reject',requiresReason:true}],
 }};
 const journey=new Hooks(),changes=[],journeyProps={...journeyComponent.props,onChanged:()=>changes.push(true)};
 const renderJourney=()=>journey.render(journeyComponent.type,journeyProps);
 renderJourney();
 await journey.flush();
 tree=renderJourney();
 ok(mark(tree,'JourneyAlerts'));
 ok(!button(tree,'Valider l’étape'));
 button(tree,'Refuser la validation').props.onClick();
 const actionComponent=mark(renderJourney(),'JourneyAction');
 const journeyAction=new Hooks(),renderAction=()=>journeyAction.render(actionComponent.type,actionComponent.props);
 tree=renderAction();
 before=globalThis.__writes.length;
 await button(tree,'Confirmer').props.onClick();
 eq(globalThis.__writes.length,before);
 tree=renderAction();
 ok(nodes(tree).some(node=>node.props?.role==='alert'&&node.props.children==='Choisissez un motif.'));
 eq(mark(tree,'Select').props.options.at(-1),{id:43,value:'43',label:'Contrôle incomplet',disabled:false});
 mark(tree,'Select').props.onChange('43');
 tree=renderAction();
 nodes(tree).find(node=>node.type==='textarea').props.onChange({target:{value:' Élément manquant ' }});
 tree=renderAction();
 globalThis.__results.push({success:false,status:503});
 await button(tree,'Confirmer').props.onClick();
 const processAttempt=globalThis.__writes.at(-1);
 const request=JSON.parse(processAttempt.options.body);
 eq(processAttempt.url,'/api/support/tickets/42/parcours');
 eq({action:request.action,revision:request.revision,reasonId:request.reasonId,reason:request.reason},
   {action:'reject',revision:5,reasonId:43,reason:'Élément manquant'});
 ok(/^[a-f0-9-]{36}$/.test(request.requestId));
 tree=renderAction();
 ok(mark(tree,'Select').props.disabled);
 globalThis.__results.push({success:true,data:globalThis.__journey});
 await button(tree,'Vérifier l’enregistrement').props.onClick();
 eq(globalThis.__writes.at(-1).options.body,processAttempt.options.body);
 eq(changes.length,1);
 journeyAction.unmount();
 journey.unmount();
 processDetail.unmount();
 console.log(JSON.stringify({success:true,checks,scope:'Helpers et handlers réels Support : création, conservation/rejeu, droits, contexte, transitions, listes/exports, kanban, KPI, fiches et parcours',limits:['DOM et API simulés ; pas de recette visuelle navigateur']}));
})().catch(error=>{console.error(error);process.exitCode=1;});
