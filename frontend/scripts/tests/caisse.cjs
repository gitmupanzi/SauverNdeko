// Composants et handlers réels, transports/DOM simulés ; aucune écriture en base.
const path=require('node:path'),Module=require('node:module'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../..'),front=path.join(root,'frontend'),esbuild=require(path.join(front,'node_modules/esbuild'));let checks=0;
const eq=(a,b)=>{assert.deepEqual(a,b);checks++;},ok=value=>{assert(value);checks++;};
function mocks(entries){return{name:'fixtures',setup(build){for(const[filter,name,source]of entries){build.onResolve({filter},()=>({path:name,namespace:name}));build.onLoad({filter:/.*/,namespace:name},()=>({contents:source,loader:'jsx',resolveDir:front}));}}};}
async function bundle(contents,entries=[]){const result=await esbuild.build({stdin:{contents,resolveDir:front,loader:'jsx'},bundle:true,jsx:'automatic',external:['react','react/jsx-runtime','react-dom/server'],platform:'node',format:'cjs',write:false,define:{'import.meta.env':'{}'},loader:{'.css':'empty'},plugins:[mocks(entries)],logLevel:'error'});const compiled=new Module(path.join(front,'caisse-proof.cjs'),module);compiled.filename=path.join(front,'caisse-proof.cjs');compiled.paths=Module._nodeModulePaths(front);compiled._compile(result.outputFiles[0].text,compiled.filename);return compiled.exports;}
class Hooks{constructor(){this.slots=[];this.cursor=0;this.queue=[];}state(value){const i=this.cursor++;if(!this.slots[i])this.slots[i]={value:typeof value==='function'?value():value};return[this.slots[i].value,next=>this.slots[i].value=typeof next==='function'?next(this.slots[i].value):next];}ref(value){const i=this.cursor++;if(!this.slots[i])this.slots[i]={current:value};return this.slots[i];}id(){return 'cash-'+this.cursor++;}effect(fn,deps=[]){const i=this.cursor++,old=this.slots[i];if(!old||deps.some((v,j)=>!Object.is(v,old.deps[j])))this.queue.push(()=>{old?.clean?.();this.slots[i]={deps,clean:fn()};});}render(component,props={}){this.cursor=0;globalThis.__hooks=this;return component(props);}async flush(){for(const effect of this.queue.splice(0))effect();await new Promise(resolve=>setImmediate(resolve));await new Promise(resolve=>setImmediate(resolve));}unmount(){this.slots.forEach(slot=>slot?.clean?.());}}
function nodes(node,out=[]){if(!node||typeof node!=='object')return out;if(Array.isArray(node)){node.forEach(n=>nodes(n,out));return out;}if(node.type)out.push(node);nodes(node.props?.children,out);return out;}
const named=(tree,name)=>nodes(tree).find(node=>node.type?.name===name),allNamed=(tree,name)=>nodes(tree).filter(node=>node.type?.name===name);
const reactHooks=`export const useState=v=>globalThis.__hooks.state(v),useRef=v=>globalThis.__hooks.ref(v),useId=()=>globalThis.__hooks.id(),useEffect=(f,d)=>globalThis.__hooks.effect(f,d),useMemo=f=>f();`;
globalThis.document={getElementById:id=>({focus(){globalThis.__focus=id;},scrollIntoView(){}})};globalThis.requestAnimationFrame=fn=>fn();globalThis.localStorage={getItem:()=>null,setItem(){}};globalThis.window={matchMedia:()=>({matches:true})};
const scope={scopeKey:'user:7',entityId:'7',globalAdmin:false},context={entityId:7,readOnly:false,tabs:{caisses:{canRead:true,canManage:true,canExport:true},ecritures:{canRead:true,canManage:true,canExport:true},clotures:{canRead:true,canManage:true,canExport:true}},canCreateEntries:true,canEditDrafts:true,canValidateEntries:false},references={caisses:[{IdCaisse:3,CodeCaisse:'CAI-3',NomCaisse:'Principale',DeviseCode:'USD',IdDeviseFk:451,MontantCaisse:'90071992547409.93',Actif:true}],devises:[{id:451,abbr:'USD',label:'Dollar'}],typesCaisses:[],responsables:[],typesPaiements:[],tiers:[]};
const common=[[/^react$/,'hooks',reactHooks],[/\/contexts\/EntityScopeContext$/,'scope',`export const useEntityScope=()=>globalThis.__scope;`],[/\/contexts\/AuthContext$/,'auth',`export const useAuth=()=>({user:globalThis.__user});`],[/\/services\/api$/,'api',`export const requestJson=(path,options)=>globalThis.__request(path,options);export async function downloadApiFile(path,options){globalThis.__exports.push({path,options});}`],[/\/hooks\/useTablePreferences$/,'preferences',`export default function useTablePreferences(key){globalThis.__tableKey=key;return {ready:true,canExport:true,catalogue:[{id:'CodeFactureFk',label:'Code facture'}],exportKeys:['CodePaiement','MontantPaiement'],error:''};}`]];
const stubs=[[/\/CaisseReferences$/,'refs-drawer',`export default function References(){}`],[/\/components\/RegisterSettingsButton$/,'settings-button',`export default function SettingsButton(){}`],[/\/components\/RecordEditorFrame$/,'frame',`export default function Frame(){}`],[/\/components\/ConsultationTabs$/,'tabs',`export default function Tabs(){}`],[/\/components\/SearchSelect$/,'select',`export default function Select(){}`],[/\/components\/ActionButton$/,'button',`export default function Button(){}`],[/\/components\/AppIcon$/,'icon',`export default function Icon(){}`],[/\/components\/RegisterSurface$/,'surface',`export default function Surface(){}`],[/\/components\/DataTableToolbar$/,'toolbar',`export default function Toolbar(){}`],[/\/components\/RowActionsMenu$/,'menu',`export default function Menu(){}`],[/\/logistique\/logistiqueShared$/,'table',`export const formatDate=v=>String(v||'—'),asArrayPayload=v=>Array.isArray(v?.data)?v.data:[];export function SimpleTable(){}`]];
(async()=>{
 const domain=await bundle("export * from './src/pages/caisse/caisseModel';export * from './src/pages/caisse/caisseBatch';export * from './src/services/moduleAccess';export * from './src/services/entityScope';");
 eq(domain.moduleForPath('/caisse'),'caisse');eq(domain.mayOpen({moduleAccess:{modules:{caisse:{canRead:false}}}},'/caisse'),false);eq(domain.caisseTab('impossible'),'tableau-de-bord');eq(domain.caisseTab('clotures'),'clotures');
 domain.configureEntityScope({userId:2,entityId:7,globalAdmin:true});const snapshot=domain.captureEntityScope('/api/caisse/clotures');eq(snapshot.headers,{'X-Entite-ID':'7'});domain.configureEntityScope({userId:2,entityId:8,globalAdmin:true});eq(domain.entityScopeIsCurrent(snapshot),false);
 for(const[value,expected]of [['0.01','0.01'],[' 15,95 ','15.95'],['9007199254740993.93','9007199254740993.93'],['0',null],['1e3',null],['-1',null],['1.001',null],['NaN',null],['1.2.3',null],['10000000000000000',null]])eq(domain.caisseAmount(value),expected);
 eq(domain.caisseAmount('0',{zero:true}),'0');ok(domain.validCaisseDate('2026-11-02T15:34:57'));eq(domain.validCaisseDate('2026-02-31T10:00'),false);eq(domain.validCaisseDate('2026-11-02T25:00'),false);eq(domain.caisseDateInput('2026-11-02T12:34:56Z'),'2026-11-02T13:34:56');
 for(const response of [null,undefined,{},{success:true},{success:false,status:0},{success:false,status:502}])ok(domain.caisseResponseUncertain(response));eq(domain.caisseResponseUncertain({success:false,status:409}),false);eq(domain.caisseResponseUncertain({success:false,status:422}),false);
 eq(domain.caisseValues('caisses',null,references).IdDeviseFk,'451');eq(domain.caisseValues('caisses',null,{}).IdDeviseFk,'');
 let values={...domain.caisseValues('ecritures',null,references),IdCaisseFk:'3',LibellePaiement:'Paiement fournisseur',MontantPaiement:'9007199254740993,93',SensMouvement:'-1',motif:' Achat '};
 eq(domain.caisseErrors('ecritures',values),{});const body=domain.caissePayload('ecritures',values,{version:'12',requestId:'id'});eq(body.data.MontantPaiement,'9007199254740993.93');eq(body.data.SensMouvement,-1);eq(body._version,'12');eq(body.motif,'Achat');ok(body.data.DatePaiement.endsWith('+01:00'));ok(!('CodePaiement'in body.data));eq(typeof body.data.MontantPaiement,'string');
 eq(domain.caisseQuery({q:' test ',filters:{IdDeviseFk:'451',dateMin:'2026-01-01',empty:''}},{take:25,skip:50,sortBy:'DatePaiement',sortDir:'desc'}).get('page'),'3');eq(domain.caisseBarPercent('9007199254740993.93','9007199254740993.93'),100);eq(domain.caisseBarPercent('0.01','0.04'),25);
 globalThis.__scope={...scope};globalThis.__user={IdUser:2,permissions:{canWriteData:true,canExportData:true}};globalThis.__writes=[];globalThis.__exports=[];globalThis.__result={success:false,status:503,message:'Réponse incertaine'};globalThis.__saved=null;globalThis.__detail={record:{IdPaiement:22,CodePaiement:'ECR-22',IdCaisseFk:3,LibellePaiement:'Dépense',MontantPaiement:'1.00',SensMouvement:-1,DatePaiement:'2026-11-02T12:34:56Z',EtatEcriture:'DRAFT'},_version:'12',canManage:true,canValidate:true,canReverse:false};
 globalThis.__request=async(path,options)=>{if(options.method){globalThis.__writes.push({path,options});return globalThis.__result;}return {success:true,data:globalThis.__detail};};
 const editor=await bundle("export {default} from './src/pages/caisse/CaisseEditor';",[...common,...stubs]);
 const eh=new Hooks(),props={kind:'ecritures',context,references,onClose(){},onSaved:value=>globalThis.__saved=value},render=()=>eh.render(editor.default,props);
 let tree=render();await eh.flush();tree=render();eq(named(tree,'Frame').props.readOnly,false);await named(tree,'Frame').props.onSubmit();eq(__writes.length,0);ok(named(render(),'Frame').props.dirty===false);ok(globalThis.__focus.includes('motif'));
 function setField(key,value){let tree=render(),node=nodes(tree).find(n=>n.type==='input'&&n.props.id?.endsWith('-'+key));if(node)node.props.onChange({target:{value}});else{node=allNamed(tree,'Select').find(n=>n.props.id?.endsWith('-'+key));if(node)node.props.onChange(value);else throw Error('Champ absent '+key);}}
 named(render(),'Tabs').props.onChange('operation');setField('IdCaisseFk','3');setField('LibellePaiement','Règlement exact');setField('MontantPaiement','9007199254740993,93');named(render(),'Tabs').props.onChange('tracabilite');nodes(render()).find(n=>n.type==='textarea'&&n.props.id.endsWith('-motif')).props.onChange({target:{value:'Justification'}});
 await named(render(),'Frame').props.onSubmit();eq(__writes.length,1);const exact=__writes[0].options.body;eq(JSON.parse(exact).data.MontantPaiement,'9007199254740993.93');tree=render();eq(named(tree,'Frame').props.submitLabel,'Vérifier l’opération');ok(nodes(tree).find(n=>n.type==='textarea').props.disabled);nodes(tree).find(n=>n.type==='textarea').props.onChange({target:{value:'Autre motif'}});eq(nodes(render()).find(n=>n.type==='textarea').props.value,'Justification');globalThis.__result={success:true,data:{record:{IdPaiement:23,CodePaiement:'ECR-23'},_version:'1'}};await named(render(),'Frame').props.onSubmit();eq(__writes.at(-1).options.body,exact);eq(__saved.IdPaiement,23);eh.unmount();
 const denied=new Hooks();globalThis.__detail={...__detail,canReverse:false};denied.render(editor.default,{...props,id:22,mode:'contrepasser'});await denied.flush();tree=denied.render(editor.default,{...props,id:22,mode:'contrepasser'});eq(named(tree,'Frame').props.readOnly,true);const before=__writes.length;await named(tree,'Frame').props.onSubmit();eq(__writes.length,before);denied.unmount();
 const edit=new Hooks();const editProps={...props,id:22,mode:'edit'};edit.render(editor.default,editProps);await edit.flush();tree=edit.render(editor.default,editProps);eq(nodes(tree).find(n=>n.type==='input'&&n.props.id.endsWith('-MontantPaiement')).props.value,'1.00');eq(allNamed(tree,'Select').find(n=>n.props.id.endsWith('-IdCaisseFk')).props.disabled,true);globalThis.__scope={...scope,scopeKey:'user:8',entityId:'8'};tree=edit.render(editor.default,editProps);eq(named(tree,'Frame').props.readOnly,true);await named(tree,'Frame').props.onSubmit();eq(__writes.length,before);edit.unmount();
 const batchReferences={...references,caisses:[{...references.caisses[0],_version:'9007199254740993',SoldeTheorique:'100.00'}]};
 const pasted=domain.caisseBatchPaste('ecritures','Caisse\tDate et heure\tMouvement\tLibellé\tMontant\nCAI-3\t02/11/2026 12:34\tSortie\tEssai\t1\u202f234,50\n3\t2026-11-02 12:34:59\tEncaissement\tAutre essai\t2,55',batchReferences);
 eq(pasted.length,2);eq(pasted[0].values.IdCaisseFk,'3');
 eq(pasted[0].values.SensMouvement,'-1');eq(domain.caisseBatchErrors('ecritures',pasted,batchReferences),{});
 const batchBody=domain.caisseBatchPayload('ecritures',pasted,false,'request-fixture');
 eq(batchBody.rows[0].data.MontantPaiement,'1234.50');eq(batchBody.rows[0].data.DatePaiement,'2026-11-02T12:34+01:00');
 eq(batchBody.valider,false);assert.throws(()=>domain.caisseBatchPaste('caisses','Devise\tDevise\nUSD\tUSD',batchReferences),/en-têtes en double/);
 const counted=domain.caisseBatchPaste('clotures','Caisse\tDate et heure du comptage\tMontant compté\tMotif\nPrincipale\t02/11/2026 12:30\t99,50\tÉcart\n3\t02/11/2026 12:40\t99,50\tÉcart',batchReferences);
 const closureIssues=domain.caisseBatchErrors('clotures',counted,batchReferences);
 ok(closureIssues[counted[0].clientRowId].IdCaisseFk);ok(closureIssues[counted[1].clientRowId].IdCaisseFk);
 ok(closureIssues[counted[0].clientRowId]._version);
 counted[0].balance={version:'9007199254740993',record:{NombreBrouillons:1}};
 ok(domain.caisseBatchErrors('clotures',counted.slice(0,1),batchReferences)[counted[0].clientRowId]._version);
 counted[0].balance.record.NombreBrouillons=0;
 eq(domain.caisseBatchErrors('clotures',counted.slice(0,1),batchReferences),{});
 eq(domain.caisseBatchPayload('clotures',counted.slice(0,1),false,'count-fixture').rows[0]._version,'9007199254740993');
 globalThis.__scope={...scope};globalThis.__writes=[];globalThis.__batchResult=()=>({success:false,status:503});
 globalThis.__request=async(path,options)=>{__writes.push({path,options});return __batchResult(JSON.parse(options.body));};
 const batch=await bundle("export {default} from './src/pages/caisse/CaisseBatchEditor';",[...common,...stubs]);
 const bh=new Hooks(),bp={...props,kind:'caisses',references:batchReferences},br=()=>bh.render(batch.default,bp);
 tree=br();await bh.flush();await named(tree,'Frame').props.onSubmit();eq(__writes.length,0);
 tree=br();let basket=named(tree,'SimpleTable');let row=basket.props.rows[0];
 let nameInput=nodes(basket.props.columns.find(c=>c.key==='NomCaisse').render(row)).find(node=>node.type==='input');
 nameInput.props.onChange({target:{value:'Caisse recette'}});
 await named(br(),'Frame').props.onSubmit();eq(__writes.length,1);
 const sameBatch=__writes[0].options.body;eq(named(br(),'Frame').props.submitLabel,'Vérifier l’enregistrement');
 globalThis.__batchResult=payload=>({success:true,data:{requestId:payload.requestId,count:payload.rows.length,records:payload.rows.map(row=>({clientRowId:row.clientRowId,id:44}))}});
 await named(br(),'Frame').props.onSubmit();eq(__writes.at(-1).options.body,sameBatch);eq(__saved.count,1);bh.unmount();
 globalThis.__scope={...scope};globalThis.__calls=[];globalThis.__result={success:true,data:{record:{ID_ClotureCaisse:'9007199254740993'}}};globalThis.__request=async(path,options)=>{__calls.push({path,options});if(options.method){__writes.push({path,options});return __result;}return {success:true,data:{record:references.caisses[0],_version:'25',canManage:true}};};
 const closure=new Hooks(),cp={...props,kind:'clotures',defaults:{IdCaisseFk:'3'}},cr=()=>closure.render(editor.default,cp);cr();await closure.flush();tree=cr();ok(__calls.some(call=>call.path.includes('/clotures/preparation?caisseId=3')));nodes(tree).find(n=>n.type==='input'&&n.props.id.endsWith('-MontantCompte')).props.onChange({target:{value:'0'}});named(cr(),'Tabs').props.onChange('tracabilite');nodes(cr()).find(n=>n.type==='textarea').props.onChange({target:{value:'Comptage terminé'}});await named(cr(),'Frame').props.onSubmit();eq(JSON.parse(__writes.at(-1).options.body)._version,'25');eq(JSON.parse(__writes.at(-1).options.body).data.MontantCompte,'0');ok(!('MontantCaisse'in JSON.parse(__writes.at(-1).options.body).data));closure.unmount();
 globalThis.__request=async(path,options)=>{__calls.push({path,options});return {success:true,data:{rows:[{IdPaiement:22,CodePaiement:'ECR-22',MontantPaiement:'1.00',EtatEcriture:'POSTED',IdReglementFk:9}],total:52,page:1,take:25}};};
 const register=await bundle("export {default} from './src/pages/caisse/CaisseRegister';",[...common,...stubs]);const rh=new Hooks(),rp={kind:'ecritures',context,references,refresh:0,onOpen:value=>globalThis.__opened=value},rr=()=>rh.render(register.default,rp);rr();await rh.flush();tree=rr();let table=named(tree,'SimpleTable');eq(table.props.serverMeta.filteredCount,52);eq(table.props.rows[0].IdPaiement,22);eq(table.props.enableSelection,false);table.props.onServerChange({skip:25});rr();await rh.flush();ok(__calls.at(-1).path.includes('page=2'));tree=rr();const action=named(tree,'SimpleTable').props.columns.find(c=>c.key==='actions').render(table.props.rows[0]);eq(named(action,'Menu').props.items.some(i=>i.label==='Contrepasser'),false);named(named(rr(),'SimpleTable').props.toolbar,'Toolbar').props.exportFile();await rh.flush();ok(__exports.at(-1).path.includes('/registres/ecritures.xlsx?'));ok(__exports.at(-1).path.includes('columns='));
 globalThis.__scope={...scope,scopeKey:'user:8',entityId:'8'};tree=rr();eq(named(tree,'SimpleTable').props.rows.length,0);eq(named(tree,'SimpleTable').props.loading,true);rh.unmount();
 // La sélection transmet ses identifiants et ses révisions, indépendamment de la pagination.
 globalThis.__scope={...scope};
 globalThis.__request=async()=>({success:true,data:{rows:[
  {IdPaiement:22,CodePaiement:'ECR-22',EtatEcriture:'DRAFT',_version:'12',ValidationAutorisee:true},
  {IdPaiement:23,CodePaiement:'ECR-23',EtatEcriture:'DRAFT',_version:'99',ValidationAutorisee:false},
 ],total:52,page:1,take:25}});
 const validator=new Hooks(), vp={...rp,context:{...context,canValidateEntries:true},onOpen:value=>globalThis.__validationSelection=value.rows};
 const vr=()=>validator.render(register.default,vp);
 vr();await validator.flush();
 table=named(vr(),'SimpleTable');eq(table.props.enableSelection,true);
 table.props.onSelectionChange(table.props.rows);
 allNamed(named(vr(),'SimpleTable').props.toolbar,'Button').find(node=>node.props.children==='Valider la sélection').props.onClick();
 eq(__validationSelection.map(({id,_version})=>({id,_version})),[{id:22,_version:'12'},{id:23,_version:'99'}]);
 validator.unmount();

 // Un aperçu bloquant préserve les raisons et interdit la validation partielle.
 const validation=await bundle("export {default} from './src/pages/caisse/CaisseValidation';",[...common,...stubs]);
 const selected=__validationSelection;
 const totals=[{currencyId:1,currency:'USD',entries:'2.00',exits:'0.00'},{currencyId:2,currency:'CDF',entries:'0.00',exits:'1800.00'}];
 let block=true, attempts=[];
 globalThis.__request=async(path,options)=>{
  attempts.push({path,body:options.body});
  if(path.endsWith('/apercu'))return {success:true,data:{count:2,totals,rows:[
   {id:22,code:'ECR-22',eligible:true},{id:23,code:'ECR-23',eligible:!block,reason:'Écriture modifiée.'},
  ]}};
  return attempts.filter(attempt=>!attempt.path.endsWith('/apercu')).length===1
   ? {success:false,status:503}:{success:true,data:{count:2,replayed:true}};
 };
 const validationProps={rows:selected,onClose(){},onSaved:value=>globalThis.__validationSaved=value};
 const blocked=new Hooks(),blockedView=()=>blocked.render(validation.default,validationProps);
 blockedView();await blocked.flush();
 tree=blockedView();eq(nodes(tree).filter(n=>n.type==='dl').length,2);
 ok(nodes(tree).some(n=>n.props.children==='Écriture modifiée.'));
 nodes(tree).find(n=>n.type==='textarea').props.onChange({target:{value:'Contrôle journalier'}});
 eq(named(blockedView(),'Frame').props.canSubmit,false);await named(blockedView(),'Frame').props.onSubmit();
 eq(attempts.length,1);blocked.unmount();
 block=false;
 const confirming=new Hooks(),confirmView=()=>confirming.render(validation.default,validationProps);
 confirmView();await confirming.flush();
 nodes(confirmView()).find(n=>n.type==='textarea').props.onChange({target:{value:' Contrôle journalier '}});
 eq(named(confirmView(),'Frame').props.canSubmit,true);
 await named(confirmView(),'Frame').props.onSubmit();
 eq(named(confirmView(),'Frame').props.submitLabel,'Vérifier la validation');
 ok(nodes(confirmView()).find(n=>n.type==='textarea').props.disabled);
 await named(confirmView(),'Frame').props.onSubmit();
 eq(attempts.at(-2).body,attempts.at(-1).body);
 eq(JSON.parse(attempts.at(-1).body).motif,'Contrôle journalier');
 eq(__validationSaved.message,'2 écritures validées.');confirming.unmount();

 // Le choix d’une validation indépendante exige un agent habilité.
 const settings=await bundle("export {default} from './src/pages/caisse/CaisseValidationSettings';",[...common,...stubs]);
 attempts=[];
 let eligibleValidators=[{id:4,label:'Agent indépendant'},{id:5,label:'Agent de relève'}];
 globalThis.__request=async(path,options)=>{
  if(!options.method)return {success:true,data:{mode:'MANUAL',validatorIds:[],eligibleValidators,_version:'50',canManage:true}};
  attempts.push({path,body:options.body});
  return {success:true,data:{}};
 };
 const configure=new Hooks(),configurationProps={companyName:'Entreprise test',onClose(){},onSaved:value=>globalThis.__configurationSaved=value};
 const settingsView=()=>configure.render(settings.default,configurationProps);
 const settingsSelect=label=>allNamed(settingsView(),'Select').find(node=>node.props.label===label);
 const addAgent=()=>settingsSelect('Ajouter un agent');
 settingsView();await configure.flush();
 settingsSelect('Mode pour les nouvelles écritures').props.onChange('OTHER_AGENT');
 nodes(settingsView()).find(n=>n.type==='textarea').props.onChange({target:{value:'Séparation des tâches'}});
 eq(named(settingsView(),'Frame').props.canSubmit,false);
 await named(settingsView(),'Frame').props.onSubmit();eq(attempts.length,0);
 addAgent().props.onChange('4');
 addAgent().props.onChange('5');
 eq(addAgent().props.options,[]);
 eq(addAgent().props.disabled,true);
 allNamed(settingsView(),'Button').find(node=>node.props['aria-label']==='Retirer Agent de relève').props.onClick();
 eq(addAgent().props.options.map(({value})=>value),['5']);
 eligibleValidators=[...eligibleValidators,{id:6,label:'Nouvel agent'}];
 await allNamed(settingsView(),'Button').find(node=>node.props.children==='Actualiser les agents').props.onClick();
 eq(addAgent().props.options.map(({value})=>value),['5','6']);
 eq(settingsSelect('Mode pour les nouvelles écritures').props.value,'OTHER_AGENT');
 eq(named(settingsView(),'Frame').props.canSubmit,true);
 await named(settingsView(),'Frame').props.onSubmit();
 const savedSettings=JSON.parse(attempts[0].body);
 eq(savedSettings.validatorIds,[4]);eq(savedSettings.mode,'OTHER_AGENT');eq(savedSettings._version,'50');
 ok(savedSettings.requestId);ok(__configurationSaved.message);configure.unmount();

 // Le règlement garde la caisse choisie et rejoue exactement la même demande.
 globalThis.__user={IdUser:2,IdEntiteFk:7,permissions:{canWriteData:true},moduleAccess:{modules:{logistique:{canRead:true,canManage:true},caisse:{canRead:true,canManage:true}}}};globalThis.__writes=[];globalThis.__paymentSaved=null;globalThis.__paymentResult={success:false,status:503};
 const preparation={success:true,data:{facture:{ID_Commande:88,CodeFacture:'FAC-88',CodeCmd:'BS-88',DeviseCode:'USD',MontantFacture:'100.00',Reste:'100.00'},defaults:{DateReglement:'2026-11-02T12:00:00+01:00'},references:{reglementModes:[{id:1,label:'Espèces',abbr:'Espèces'}],caisses:[{id:3,label:'Principale',code:'USD'}]}},meta:{revision:'payment-v1',canCreate:true,maximumAmount:'100.00'}};
 globalThis.__request=async(path,options={})=>{if(options.method){__writes.push({path,options});return __paymentResult;}return preparation;};
 const payment=await bundle("export {default} from './src/pages/logistique/ReglementEditor';",[...common,...stubs,[/\/logistiqueShared$/,'payment-shared',`export const formatDate=v=>String(v||'—'),asArrayPayload=v=>Array.isArray(v?.data)?v.data:[];export function SimpleTable(){}`],[/\/hooks\/useReferencesRefresh$/,'references-refresh',`export default function refresh(){}`],[/\/components\/BusinessDocuments$/,'documents',`export default function Documents(){}`],[/\/components\/DrawerDialog$/,'drawer',`export default function Drawer(){}`]]);
 const ph=new Hooks(),pp={commandeId:88,onClose(){},onSaved:record=>globalThis.__paymentSaved=record},pr=()=>ph.render(payment.default,pp);pr();await ph.flush();tree=pr();eq(named(tree,'PaymentFrame').props.canSubmit,true);let cashSelect=allNamed(tree,'Select').find(node=>node.props.label==='Enregistrer en caisse');ok(cashSelect);cashSelect.props.onChange('3');allNamed(pr(),'Select').find(node=>node.props.label==='Mode de règlement').props.onChange('1');nodes(pr()).find(node=>node.type==='input'&&node.props.name==='MontantRegle').props.onChange({target:{value:'2,35'}});await named(pr(),'PaymentFrame').props.onSubmit();eq(__writes.length,1);const paymentBody=__writes[0].options.body;eq(JSON.parse(paymentBody).caisseId,'3');eq(JSON.parse(paymentBody).MontantRegle,'2.35');ok(JSON.parse(paymentBody).requestId);tree=pr();eq(allNamed(tree,'Select').find(node=>node.props.label==='Enregistrer en caisse').props.disabled,true);allNamed(tree,'Select').find(node=>node.props.label==='Enregistrer en caisse').props.onChange('4');eq(allNamed(pr(),'Select').find(node=>node.props.label==='Enregistrer en caisse').props.value,'3');globalThis.__paymentResult={success:true,data:{ID_Reglement:998}};await named(pr(),'PaymentFrame').props.onSubmit();eq(__writes.at(-1).options.body,paymentBody);eq(__paymentSaved.ID_Reglement,998);ph.unmount();
 const absent=new Hooks();globalThis.__request=async()=>({...preparation,data:{...preparation.data,references:{...preparation.data.references,caisses:[]}}});absent.render(payment.default,pp);await absent.flush();eq(allNamed(absent.render(payment.default,pp),'Select').some(node=>node.props.label==='Enregistrer en caisse'),false);absent.unmount();
 // La série respecte les jours réels et garde les périodes sans mouvement à zéro.
 const chart=await bundle("export {default, caisseFlowDays} from './src/pages/caisse/CaisseFlowChart';",common);
 const daily=[{DateJour:'2026-11-07',Entrees:'10.25',Sorties:'5'},{DateJour:'2026-11-03',Entrees:'25',Sorties:'0'}];
 const period={dateMin:'2026-11-02',dateMax:'2026-11-08'};
 const points=chart.caisseFlowDays(daily,period);
 eq(points.map(day=>new Date(day.timestamp).getUTCDate()),[2,3,4,6,7,8]);
 eq(points.map(day=>String(day.Entrees)),['0','25','0','0','10.25','0']);
 eq(chart.caisseFlowDays([],period),[]);
 const chartHooks=new Hooks();
 const chartProps={rows:daily,currency:'USD',filters:period};
 const chartTree=chartHooks.render(chart.default,chartProps);
 eq(nodes(chartTree).filter(node=>node.type==='polyline').length,2);
 nodes(chartTree).find(node=>node.type==='input').props.onChange({target:{value:'4'}});
 eq(nodes(chartHooks.render(chart.default,chartProps)).find(node=>node.type==='time').props.dateTime,'2026-11-07');
 chartHooks.unmount();
 console.log(JSON.stringify({success:true,checks,coverage:['Montants exacts et fuseau Kinshasa','Périmètre Caisse distinct de Logistique','Formulaires partagés création/modification','Rejeu du même UUID et corps après réponse incertaine','Clôture datée avec révision serveur et détection des brouillons','Aperçu multidevise et rejet des lignes bloquées','Rejeu exact de la validation et mode indépendant avec agent admissible','Pagination et exports serveurs','Écritures de règlement sans contrepassation indépendante','Données masquées immédiatement au changement d’entreprise'],limits:['Fixtures API/DOM ; aucune recette visuelle dans le navigateur']}));
})().catch(error=>{console.error(error);process.exitCode=1;});
