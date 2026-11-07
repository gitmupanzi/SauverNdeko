// Réels helpers et handlers React, sans écriture applicative ni navigateur.
const fs=require('node:fs'),path=require('node:path'),Module=require('node:module'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../..'),front=path.join(root,'frontend'),esbuild=require(path.join(front,'node_modules/esbuild'));let checks=0;
const eq=(a,b)=>{assert.deepEqual(a,b);checks++;},ok=(a,message)=>{assert(a,message);checks++;},throws=(fn,pattern)=>{assert.throws(fn,pattern);checks++;};
async function bundle(contents,plugins=[]){const result=await esbuild.build({stdin:{contents,resolveDir:front,loader:'jsx'},bundle:true,write:false,platform:'node',format:'cjs',external:['react','react/jsx-runtime','react-dom/server'],jsx:'automatic',define:{'import.meta.env':'{}'},loader:{'.css':'empty'},plugins,logLevel:'error'});const compiled=new Module(path.join(front,'logistics-batch-proof.cjs'),module);compiled.filename=path.join(front,'logistics-batch-proof.cjs');compiled.paths=Module._nodeModulePaths(front);compiled._compile(result.outputFiles[0].text,compiled.filename);return compiled.exports;}
function mocks(entries){return{name:'fixtures',setup(build){for(const[filter,name,source]of entries){build.onResolve({filter},()=>({path:name,namespace:name}));build.onLoad({filter:/.*/,namespace:name},()=>({contents:source,loader:'jsx',resolveDir:front}));}}};}
const tick=()=>new Promise(resolve=>setImmediate(resolve));
class Hooks{constructor(){this.slots=[];this.cursor=0;this.queue=[];}state(value){const i=this.cursor++;if(!this.slots[i])this.slots[i]={value:typeof value==='function'?value():value};return[this.slots[i].value,next=>{this.slots[i].value=typeof next==='function'?next(this.slots[i].value):next;}];}ref(value){const i=this.cursor++;if(!this.slots[i])this.slots[i]={current:value};return this.slots[i];}id(){return'proof-'+this.cursor++;}effect(fn,deps=[]){const i=this.cursor++,old=this.slots[i];if(!old||deps.some((v,j)=>!Object.is(v,old.deps[j])))this.queue.push(()=>{old?.clean?.();this.slots[i]={deps,clean:fn()};});}render(component,props){this.cursor=0;globalThis.__hooks=this;return component(props);}async flush(){for(const effect of this.queue.splice(0))effect();await tick();await tick();}unmount(){this.slots.forEach(slot=>slot?.clean?.());}}
function nodes(node,out=[]){if(!node||typeof node!=='object')return out;if(Array.isArray(node)){node.forEach(n=>nodes(n,out));return out;}if(node.type)out.push(node);nodes(node.props?.children,out);return out;}
const mark=(tree,name)=>nodes(tree).find(n=>n.type?.name===name),button=(tree,label)=>nodes(tree).find(n=>n.type?.name==='Button'&&n.props.children===label),input=(tree,suffix)=>nodes(tree).find(n=>n.type==='input'&&n.props.id?.endsWith(suffix));
globalThis.requestAnimationFrame=fn=>fn();globalThis.document={getElementById:()=>({focus(){}})};
const refs={defaultTypeClientId:3,defaultCurrencyId:451,typesClients:[{id:3,label:'Client',active:true}],users:[],professionnels:[],entites:[],articleCategories:[{id:40,label:'Matériel',active:true}],articleTypes:[{id:46,label:'Produit',active:true}],articleUnits:[{id:34,label:'pcs',active:true}],weightUnits:[],articleCurrencies:[{id:451,label:'USD',code:'USD',active:true}],currencies:[{id:451,label:'USD',code:'USD',active:true}],types:[{id:40,label:'Matériel',active:true}],etats:[],responsables:[],services:[{id:25,label:'Informatique',active:true}],localisations:[],canCreate:true};
(async()=>{
 const p=await bundle("export * from './src/pages/logistique/logisticsBatchForm';");
 let row=p.logisticsBatchRow('tiers',refs);eq(row.values.ID_TypeClientFk,'3');eq(row._pristine,true);eq(row.values.Actif,true);
 let pasted=p.logisticsBatchFromExcel('tiers','Nom du tiers\tType de client\tNature\tE-mail\tTéléphone\nAlice\tClient\tPersonne\ta@example.invalid\t00123',{...refs},{hasHeaders:true});eq(pasted.length,1);eq(pasted[0].values.ID_TypeClientFk,'3');eq(pasted[0].values.Telephone,'00123');eq(pasted[0]._pristine,false);eq(p.validateLogisticsBatch('tiers',pasted,refs),{header:{},rows:{}});
 const duplicate={...pasted[0],clientRowId:'other'};eq(Object.keys(p.validateLogisticsBatch('tiers',[pasted[0],duplicate],refs).rows).length,2);duplicate.values={...duplicate.values,Adresse:'Autre adresse'};eq(p.validateLogisticsBatch('tiers',[pasted[0],duplicate],refs),{header:{},rows:{}});
 throws(()=>p.logisticsBatchFromExcel('tiers','Nom\tIdEntiteFk\nA\t9',refs,{hasHeaders:true}),/non reconnu/);throws(()=>p.logisticsBatchFromExcel('tiers','Nom\tNom du tiers\nA\tB',refs,{hasHeaders:true}),/plusieurs/);throws(()=>p.logisticsBatchFromExcel('tiers','Email\na@example.invalid',refs,{hasHeaders:true}),/Ajoutez/);throws(()=>p.logisticsBatchFromExcel('tiers',Array.from({length:101},()=> 'Alice').join('\n'),refs),/100/);
 pasted=p.logisticsBatchFromExcel('articles','Article\tCatégorie\tType\tUnité\tStock initial\tPrix d’achat\tPrix de vente\tDevise\nOrdinateur\tMatériel\tProduit\tpcs\t1,25\t10,50\t15,75\tUSD',refs,{hasHeaders:true});row=pasted[0];eq(row.values.ID_DeviseFk,'451');eq(row.values.ID_UniteFk,'34');eq(p.validateLogisticsBatch('articles',pasted,refs),{header:{},rows:{}});let data=p.logisticsRowPayload('articles',row);eq(data.PUArticle,'10.50');eq(data.PVArticle,'15.75');eq(data.QteArticle,'1.25');ok(!('PhotoArticle'in data));ok(p.BATCH_KINDS.articles.columns.includes('ID_DeviseFk'));
 row.initialLots=[{NumeroLot:'LOT-1',Quantite:'1.25',DatePeremptionLot:''}];const ticket=p.logisticsBatchTicket('articles',[row]);eq(ticket.rows[0].data.LotsInitiaux,row.initialLots);eq(ticket.rows[0].clientRowId,row.clientRowId);ok(!('requestId'in ticket.rows[0].data));const frozen=p.logisticsBatchBody('articles',ticket,[row]);row.initialLots[0].NumeroLot='MODIF';eq(JSON.parse(frozen).rows[0].data.LotsInitiaux[0].NumeroLot,'LOT-1');
 const photo=new File(['photo'],'image.png',{type:'image/png'});row.photo={file:photo,remove:false};const fileBody=p.logisticsBatchBody('articles',ticket,[row]);eq(fileBody.get('photo_'+row.clientRowId).name,'image.png');eq(JSON.parse(fileBody.get('payload')).requestId,ticket.requestId);row.photo={file:{size:9*1024*1024,type:'image/png'}};ok(p.validateLogisticsBatch('articles',[row],refs).rows[row.clientRowId].photo);
 pasted=p.logisticsBatchFromExcel('immobilisations','Nom du bien\tType de matériel\tQuantité\tPrix unitaire\tDevise\tService\tSuivi individuel\tDate et heure d’entrée\tMotif\nBureau\tMatériel\t2\t100,50\tUSD\tInformatique\tNon\t30/10/2026 10:45\tAcquisition',refs,{hasHeaders:true});row=pasted[0];eq(row.values.ID_ServiceFk,'25');eq(row.values.SuiviIndividuel,false);eq(row.values.DateEntree,'2026-10-30T10:45:00');eq(p.validateLogisticsBatch('immobilisations',pasted,refs),{header:{},rows:{}});data=p.logisticsRowPayload('immobilisations',row);eq(data.Quantite,'2');eq(data.PrixUnitaire,'100.50');eq(data.motif,'Acquisition');ok(!('requestId'in data));eq(data.DateEntree,'2026-10-30T10:45:00+01:00');
 const articleA=p.logisticsBatchRow('articles',refs,{NomArticle:'A',ID_CategorieArticleFk:'40',ID_TypeArticleFk:'46',ID_UniteFk:'34',PUArticle:'1',PVArticle:'2',CodeArticleInterne:'SKU-A',CodeArticleExterne:'123'}),articleB={...articleA,clientRowId:'article-b',values:{...articleA.values,NomArticle:'B',CodeArticleInterne:'SKU-a'}};eq(p.validateLogisticsBatch('articles',[articleA,articleB],refs),{header:{},rows:{}});articleB.values.CodeArticleInterne=' SKU-A ';eq(Object.keys(p.validateLogisticsBatch('articles',[articleA,articleB],refs).rows).length,2);
 const openingRefs={...refs,defaultArticleVisibility:true,articleCurrencies:[...refs.articleCurrencies,{id:450,label:'CDF',code:'CDF',active:true}]};
 const openingHeaders='Article\tCatégorie\tType\tUnité\tStock initial\tPrix d’achat\tPrix de vente\tDevise\tDate de péremption\tVisible dans l’annuaire';
 const openingText=openingHeaders+'\nSouris\tMatériel\tProduit\tpcs\t2\t5\t9\tUSD\t30/11/2027\tOui\nÉcran\tMatériel\tProduit\tpcs\t0\t10\t15\tCDF';
 const openingRows=p.logisticsBatchFromExcel('articles',openingText,openingRefs,{hasHeaders:true});
 const excelCells=Object.freeze([
  Object.freeze([...openingHeaders.split('\t'),'Code interne','Informations','N° lot']),
  Object.freeze(['Souris','Matériel','Produit','pcs','2','5','9','USD','2027-11-30','Oui','000123','Ligne 1\nLigne 2','0012']),
 ]);
 const [excelRow]=p.logisticsBatchFromMatrix('articles',excelCells,openingRefs,{hasHeaders:true});
 eq(excelRow.values.CodeArticleInterne,'000123');eq(excelRow.values.InformationArticle,'Ligne 1\nLigne 2');
 eq(excelRow.values.DatePeremptionArticle,'2027-11-30');eq(excelRow.values.VisibleCatalogue,false);
 eq(excelRow.initialLots[0].NumeroLot,'0012');eq(excelCells.length,2);
 throws(()=>p.logisticsBatchFromMatrix('articles',[['Article'],['Nom','Colonne en trop']],openingRefs,{hasHeaders:true}),/ligne 2/i);

 eq(p.logisticsBatchRow('articles',openingRefs).values.VisibleCatalogue,true);
 eq(openingRows.map(row=>row.values.VisibleCatalogue),[false,false]);
 eq(openingRows[0].values.DatePeremptionArticle,'2027-11-30');
 eq(p.logisticsRowPayload('articles',openingRows[0]).DatePeremptionArticle,'2027-11-30');
 eq(p.validateLogisticsBatch('articles',openingRows,openingRefs,'',true),{header:{},rows:{}});
 ok(!('openingReceipt'in p.logisticsBatchTicket('articles',openingRows)));
 eq(p.logisticsBatchTicket('articles',openingRows,'',true).openingReceipt,true);
 ok(!('openingReceipt'in p.logisticsBatchTicket('tiers',[], '',true)));
 const zeroRow=openingRows[1];
 ok(p.validateLogisticsBatch('articles',[zeroRow],openingRefs,'',true).header.openingReceipt.includes('positive'));
 zeroRow.values.QteArticle='1,25';
 ok(p.validateLogisticsBatch('articles',openingRows,openingRefs,'',true).header.openingReceipt.includes('devise'));
 zeroRow.values.QteArticle=' ';
 ok(p.validateLogisticsBatch('articles',openingRows,openingRefs,'',true).rows[zeroRow.clientRowId].QteArticle.includes('0'));
 zeroRow.values.QteArticle='0';
 const firstRow=openingRows[0];
 firstRow.values.DatePeremptionArticle='31/02/2027';
 firstRow.values.PUArticle='';
 firstRow.values.ValideArticle=false;
 const invalid=p.validateLogisticsBatch('articles',openingRows,{...openingRefs,commandeCurrencies:[]},'',true).rows[firstRow.clientRowId];
 ok(invalid.DatePeremptionArticle);ok(invalid.PUArticle);ok(invalid.ValideArticle);ok(invalid.ID_DeviseFk);
 const largeText=Array.from({length:600},(_,i)=>'Article '+(i+1)+'\tMatériel\tProduit\tpcs\t1\t5\t9\tUSD').join('\n');
 const largeRows=p.logisticsBatchFromExcel('articles',largeText,openingRefs,{openingReceipt:true});
 eq(largeRows.length,600);
 eq(p.validateLogisticsBatch('articles',largeRows,openingRefs,'',true),{header:{},rows:{}});
 ok(p.validateLogisticsBatch('articles',largeRows,openingRefs).header.rows.includes('100'));
 throws(()=>p.logisticsBatchFromExcel('articles',largeText,openingRefs),/100/);
 throws(()=>p.logisticsBatchFromExcel('articles',largeText+'\nArticle supplémentaire',openingRefs,{openingReceipt:true}),/600/);
 throws(()=>p.logisticsBatchFromExcel('tiers',largeText,openingRefs,{openingReceipt:true}),/100/);
 const lotPaste='Article\tCatégorie\tType\tUnité\tStock initial\tPrix d’achat\tPrix de vente\tDevise\tN° lot\tDate de péremption du lot\nSouris\tMatériel\tProduit\tpcs\t2\t5\t9\tUSD\t0012\t30/11/2027';
 const [lotRow]=p.logisticsBatchFromExcel('articles',lotPaste,openingRefs,{hasHeaders:true,openingReceipt:true});
 eq(lotRow.initialLots,[{NumeroLot:'0012',Quantite:'2',DatePeremptionLot:'2027-11-30'}]);
 eq(p.logisticsBatchTicket('articles',[lotRow],'',true).rows[0].data.LotsInitiaux,lotRow.initialLots);
 eq(p.validateLogisticsBatch('articles',[lotRow],openingRefs,'',true),{header:{},rows:{}});
 lotRow.initialLots[0].DatePeremptionLot='';
 eq(p.validateLogisticsBatch('articles',[lotRow],openingRefs,'',true),{header:{},rows:{}});
 lotRow.initialLots[0].DatePeremptionLot='2027-02-31';
 ok(p.validateLogisticsBatch('articles',[lotRow],openingRefs,'',true).rows[lotRow.clientRowId].LotsInitiaux.includes('date'));
 lotRow.initialLots[0].DatePeremptionLot='';lotRow.values.QteArticle='3';
 ok(p.validateLogisticsBatch('articles',[lotRow],openingRefs,'',true).rows[lotRow.clientRowId].LotsInitiaux.includes('somme'));
 const assetA=p.logisticsBatchRow('immobilisations',refs,{NomImmobilisation:'PC A',Reference:'MARQUE-A',ID_CategorieFk:'40',Quantite:'1',PrixUnitaire:'10',NumeroSerie:'123'}),assetB={...assetA,clientRowId:'asset-b',values:{...assetA.values,NomImmobilisation:'PC B',Reference:'MARQUE-B'}};eq(p.validateLogisticsBatch('immobilisations',[assetA,assetB],refs,'Acquisition'),{header:{},rows:{}});
 const unknown=p.logisticsBatchFromExcel('tiers','Nom du tiers\tType de client\nA\tAutre',refs,{hasHeaders:true})[0];ok(p.validateLogisticsBatch('tiers',[unknown],refs).rows[unknown.clientRowId].ID_TypeClientFk);const inactive={...refs,typesClients:[{id:3,label:'Client',active:false}]};ok(p.validateLogisticsBatch('tiers',[p.logisticsBatchRow('tiers',inactive,{Nom:'A'})],inactive).rows);

 globalThis.__scope={scopeKey:'A',entityId:'7',canCreate:true,canWrite:true,entities:[{id:7,label:'Entreprise fictive'}]};globalThis.__user={IdUser:1,permissions:{canWriteData:true}};globalThis.__refs=refs;globalThis.__calls=[];globalThis.__responses=[];
 const absolute=path.join(front,'src/pages/logistique/TiersEditor.jsx').replaceAll('\\','/');
 const serviceNames=[...fs.readFileSync(path.join(front,'src/services/logistique.js'),'utf8').matchAll(/export (?:async )?function (\w+)/g)].map(match=>match[1]);
 const serviceMock=serviceNames.map(name=>'export async function '+name+'(){return {success:true,data:globalThis.__refs};}').join('\n');
 const fixture=mocks([
 [/^react$/,'hooks',`export const useState=v=>globalThis.__hooks.state(v),useRef=v=>globalThis.__hooks.ref(v),useId=()=>globalThis.__hooks.id(),useEffect=(f,d)=>globalThis.__hooks.effect(f,d),useLayoutEffect=(f,d)=>globalThis.__hooks.effect(f,d),useMemo=(f)=>f(),useCallback=(f)=>f();`],
 [/\/contexts\/AuthContext$/,'auth',`export const useAuth=()=>({user:globalThis.__user});`],
 [/\/contexts\/EntityScopeContext$/,'scope',`export const useEntityScope=()=>globalThis.__scope;`],
 [/\/hooks\/useReferencesRefresh$/,'refresh',`export default function useReferencesRefresh(){}`],
 [/\/components\/RecordEditorFrame$/,'frame',`export default function Frame(){}`],
 [/\/components\/ActionButton$/,'button',`export default function Button(){}`],
 [/\/components\/AppIcon$/,'icon',`export default function Icon(){}`],
 [/\/components\/SearchSelect$/,'select',`export default function Select(){}`],
 [/\/modele-import-articles\.xlsx\?url$/,'article-template',`export default "/assets/modele-import-articles.xlsx";`],
 [/\.\/logistiqueShared$/,'grid',`export function SimpleTable(){};export const buildReferenceOptions=()=>[],formatDate=x=>x,formatCurrency=x=>x;`],
 [/\.\/TiersEditor$/,'tiers-editor',`export {tiersForm,tiersFormErrors,tiersPayload} from ${JSON.stringify(absolute)};export default function TiersDraft(){}`],
 [/\.\/ArticleEditor$/,'article-editor',`export default function ArticleDraft(){}`],
 [/\.\/ImmobilisationEditor$/,'asset-editor',`export default function AssetDraft(){}`],
 [/\/services\/api$/,'api',`export async function requestJson(path,options={}){if(path.endsWith('/references'))return {success:true,data:globalThis.__refs};globalThis.__calls.push({path,options});return globalThis.__responses.shift()||{success:false,status:503,message:'Indisponible'};}export async function downloadApiFile(path,options={}){globalThis.__calls.push({path,options});return globalThis.__responses.shift();}export async function fetchViewData(){return {success:true,data:[]};}`],
 [/\/services\/tiers$/,'tiers-api',`export async function tiersRequest(){return {success:true,data:globalThis.__refs};}export function tiersChanged(){}export const optionalOptions=()=>[];export const tiersRecord=x=>x?.data;`],
 [/\/services\/immobilisations$/,'asset-api',`export async function immobilisationsRequest(){return {success:true,data:globalThis.__refs};}export const immobilisationRecord=x=>x?.data;`],
 [/\/services\/logistique$/,'logistique-api',serviceMock],
 ]);
 const ui=await bundle("export {default} from './src/pages/logistique/LogisticsBatchComposer';",[fixture]);let saved=[];
 const hooks=new Hooks(),props={kind:'tiers',onClose(){},onSaved(...args){saved.push(args);}},render=()=>hooks.render(ui.default,props);
 let tree=render();await hooks.flush();tree=render();let frame=mark(tree,'Frame'),grid=mark(tree,'SimpleTable');eq(frame.props.title,'Nouveau tiers');eq(grid.props.rows.length,1);eq(grid.props.rows[0]._pristine,true);eq(frame.props.dirty,false);
 ok(!nodes(tree).some(node=>node.type==='a'&&node.props.download));
 const initialId=grid.props.rows[0].clientRowId;function setCell(field,value){let t=render(),g=mark(t,'SimpleTable'),r=g.props.rows.find(row=>row.clientRowId===initialId);const cell=g.props.columns.find(c=>c.key===field).render(r),control=nodes(cell).find(n=>n.type==='input'||n.type?.name==='Select');control.props.onChange(control.type==='input'?{target:{value}}:value);}
 setCell('Nom','Alice');tree=render();grid=mark(tree,'SimpleTable');eq(grid.props.rows[0]._pristine,false);eq(mark(tree,'Frame').props.dirty,true);eq(grid.props.rows[0].values.Nom,'Alice');
 await mark(tree,'Frame').props.onSubmit();tree=render();eq(globalThis.__calls.length,1);const firstCall=globalThis.__calls[0];eq(firstCall.path,'/api/logistique/saisie-multiple/tiers');const body=JSON.parse(firstCall.options.body);eq(body.rows.length,1);eq(body.rows[0].data.Nom,'Alice');eq(body.rows[0].clientRowId,initialId);eq(mark(tree,'Frame').props.submitLabel,'Vérifier l’enregistrement');ok(button(tree,'Ajouter une ligne').props.disabled);eq(mark(tree,'Frame').props.discardLabel,'Fermer la saisie');ok(mark(tree,'Frame').props.discardMessage.includes('n’annule pas'));eq(mark(tree,'Frame').props.dirty,true);
 globalThis.__responses.push({success:false,status:422,error:{details:{rows:{[initialId]:{Nom:'Doublon'}},header:{}}}});await mark(tree,'Frame').props.onSubmit();tree=render();eq(globalThis.__calls[1].options.body,firstCall.options.body);eq(mark(tree,'Frame').props.submitLabel,'Enregistrer l’ensemble');eq(mark(tree,'SimpleTable').props.rows[0].values.Nom,'Alice');ok(!button(tree,'Ajouter une ligne').props.disabled);eq(mark(tree,'Frame').props.error,'Corrigez les lignes indiquées. Aucune ligne de cette demande n’a été enregistrée.');
 setCell('Nom','Alice corrigée');globalThis.__responses.push({success:true,status:201,data:{requestId:'wrong',count:1,records:[{clientRowId:initialId,ID_Client:10}]}});tree=render();await mark(tree,'Frame').props.onSubmit();tree=render();eq(saved.length,0);eq(mark(tree,'Frame').props.submitLabel,'Vérifier l’enregistrement');const last=JSON.parse(globalThis.__calls.at(-1).options.body);ok(last.requestId!==body.requestId);globalThis.__responses.push({success:true,status:200,data:{requestId:last.requestId,count:1,records:[{clientRowId:initialId,ID_Client:10}]}});await mark(tree,'Frame').props.onSubmit();eq(saved.length,1);
 hooks.unmount();
 // Le collage remplace seulement la première ligne vierge réellement intacte.
 async function pasteScenario(editBlank=false){globalThis.__calls=[];const h=new Hooks(),r=()=>h.render(ui.default,props);r();await h.flush();let t=r();if(editBlank){const g=mark(t,'SimpleTable'),cell=g.props.columns.find(c=>c.key==='Telephone').render(g.props.rows[0]);nodes(cell).find(n=>n.type==='input').props.onChange({target:{value:'001'}});t=r();}button(t,'Coller depuis Excel').props.onClick();t=r();nodes(t).find(n=>n.type==='textarea').props.onChange({target:{value:Array.from({length:100},(_,i)=>'Personne '+i+'\tClient\tPersonne').join('\n')}});t=r();button(t,'Ajouter au panier').props.onClick();t=r();const g=mark(t,'SimpleTable');if(editBlank){eq(g.props.rows.length,1);eq(g.props.rows[0].values.Telephone,'001');ok(nodes(t).some(n=>n.props?.children==='Le panier peut contenir 100 lignes au maximum.'));}else eq(g.props.rows.length,100);h.unmount();}
 await pasteScenario(false);await pasteScenario(true);
 globalThis.__calls=[];
 const openingHooks=new Hooks(),openingSaved=[];
 const openingProps={...props,kind:'articles',references:openingRefs,onSaved(data){openingSaved.push(data);}};
 const renderOpening=()=>openingHooks.render(ui.default,openingProps);
 renderOpening();await openingHooks.flush();let openingTree=renderOpening();
 const templateLink=nodes(openingTree).find(node=>node.type==='a'&&node.props.download);
 eq(templateLink.props.href,'/assets/modele-import-articles.xlsx');
 eq(templateLink.props.download,'modele-import-articles.xlsx');
 eq(input(openingTree,'group-opening-stock').props.checked,false);
 input(openingTree,'group-opening-stock').props.onChange({target:{checked:true}});
 openingTree=renderOpening();
 await mark(openingTree,'Frame').props.onSubmit();openingTree=renderOpening();
 eq(globalThis.__calls.length,0);ok(input(openingTree,'group-opening-stock').props['aria-invalid']);
 button(openingTree,'Coller depuis Excel').props.onClick();openingTree=renderOpening();
 eq(nodes(openingTree).find(node=>node.type==='input'&&node.props.type==='checkbox'&&!node.props.id).props.checked,true);
 nodes(openingTree).find(node=>node.type==='textarea').props.onChange({target:{value:openingText}});
 openingTree=renderOpening();
 button(openingTree,'Ajouter au panier').props.onClick();openingTree=renderOpening();
 eq(mark(openingTree,'SimpleTable').props.rows.length,2);
 await mark(openingTree,'Frame').props.onSubmit();openingTree=renderOpening();
 const openingBody=globalThis.__calls[0].options.body,openingData=JSON.parse(openingBody);
 eq(openingData.openingReceipt,true);eq(openingData.rows.map(row=>row.data.VisibleCatalogue),[false,false]);
 ok(input(openingTree,'group-opening-stock').props.disabled);
 const openingResult={requestId:openingData.requestId,count:2,records:openingData.rows.map(({clientRowId})=>({clientRowId}))};
 globalThis.__responses.push({success:true,status:201,data:openingResult});
 await mark(openingTree,'Frame').props.onSubmit();openingTree=renderOpening();
 eq(openingSaved.length,0);eq(mark(openingTree,'Frame').props.submitLabel,'Vérifier l’enregistrement');
 eq(globalThis.__calls[1].options.body,openingBody);
 const receipt={id:'120',code:'BE-120'};
 globalThis.__responses.push({success:true,status:200,data:{...openingResult,openingReceipt:receipt}});
 await mark(openingTree,'Frame').props.onSubmit();eq(openingSaved[0].openingReceipt,receipt);
 eq(globalThis.__calls[2].options.body,openingBody);
 openingHooks.unmount();
 globalThis.__calls=[];
 const largeHooks=new Hooks(),renderLarge=()=>largeHooks.render(ui.default,openingProps);
 const focusedRows=[];
 globalThis.document={getElementById:id=>({focus(){focusedRows.push(id);}})};
 renderLarge();await largeHooks.flush();let largeTree=renderLarge();
 button(largeTree,'Coller depuis Excel').props.onClick();largeTree=renderLarge();
 nodes(largeTree).find(node=>node.type==='input'&&node.props.type==='checkbox'&&!node.props.id).props.onChange({target:{checked:false}});
 const badText=largeText.replace('Article 515\tMatériel\tProduit\tpcs\t1\t5','Article 515\tMatériel\tProduit\tpcs\t1\t');
 nodes(largeTree).find(node=>node.type==='textarea').props.onChange({target:{value:badText}});
 largeTree=renderLarge();
 button(largeTree,'Ajouter au panier').props.onClick();largeTree=renderLarge();
 eq(mark(largeTree,'SimpleTable').props.rows.length,1);
 ok(nodes(largeTree).some(node=>node.props?.children==='Limitez le panier à 100 lignes.'));
 input(largeTree,'group-opening-stock').props.onChange({target:{checked:true}});
 largeTree=renderLarge();
 button(largeTree,'Ajouter au panier').props.onClick();largeTree=renderLarge();
 let largeGrid=mark(largeTree,'SimpleTable');
 eq(largeGrid.props.rows.length,600);eq(largeGrid.props.defaultRowsPerPage,50);eq(largeGrid.props.page,1);
 ok(button(largeTree,'Ajouter une ligne').props.disabled);
 const badRow=largeGrid.props.rows[514];
 button(largeTree,'Aller à la première ligne à corriger').props.onClick();largeTree=renderLarge();await largeHooks.flush();
 largeGrid=mark(largeTree,'SimpleTable');eq(largeGrid.props.page,11);ok(focusedRows.at(-1).endsWith(badRow.clientRowId+'PUArticle'));
 const editPrice=largeGrid.props.columns.find(column=>column.key==='PUArticle').render(badRow);
 nodes(editPrice).find(node=>node.type==='input').props.onChange({target:{value:'5'}});
 largeTree=renderLarge();largeGrid=mark(largeTree,'SimpleTable');largeGrid.props.onPageChange(1);
 largeTree=renderLarge();eq(mark(largeTree,'SimpleTable').props.page,1);
 input(largeTree,'group-opening-stock').props.onChange({target:{checked:false}});largeTree=renderLarge();
 await mark(largeTree,'Frame').props.onSubmit();largeTree=renderLarge();
 eq(globalThis.__calls.length,0);ok(nodes(largeTree).some(node=>node.props?.children==='Limitez le panier à 100 lignes.'));
 eq(mark(largeTree,'SimpleTable').props.rows[514].values.PUArticle,'5');
 input(largeTree,'group-opening-stock').props.onChange({target:{checked:true}});largeTree=renderLarge();
 await mark(largeTree,'Frame').props.onSubmit();
 const largePayload=JSON.parse(globalThis.__calls[0].options.body);
 eq(largePayload.rows.length,600);eq(largePayload.openingReceipt,true);eq(largePayload.rows[514].data.PUArticle,'5');
 largeHooks.unmount();

 // Un classeur est lu dans le panier et reste modifiable avant l'enregistrement.
 globalThis.__calls=[];
 const fileHooks=new Hooks(),fileSaved=[];
 const fileRender=()=>fileHooks.render(ui.default,{...openingProps,onSaved(data){fileSaved.push(data);}});
 fileRender();await fileHooks.flush();let fileTree=fileRender(),fileGrid=mark(fileTree,'SimpleTable');
 const oldDraft=fileGrid.props.rows[0];
 nodes(fileGrid.props.columns.find(column=>column.key==='NomArticle').render(oldDraft)).find(node=>node.type==='input').props.onChange({target:{value:'Article saisi'}});
 fileTree=fileRender();
 const fileControl=t=>nodes(t).find(node=>node.type==='input'&&node.props.type==='file');
 const upload=t=>(file=new File(['workbook'],'Articles.xlsx'))=>{
  const target={files:[file],value:file.name};
  const task=fileControl(t).props.onChange({currentTarget:target});
  eq(target.value,'');
  return task;
 };
 let pickerOpened=0;
 fileControl(fileTree).props.ref.current={click(){pickerOpened++;}};
 button(fileTree,'Importer un fichier Excel').props.onClick();
 eq(pickerOpened,1);eq(button(fileTree,'Importer un fichier Excel').props.variant,'primary');
 await upload(fileTree)(new File(['ancien format'],'articles.xls'));
 await upload(fileTree)(new File([new Uint8Array(4*1024*1024+1)],'articles.xlsx'));
 fileTree=fileRender();eq(globalThis.__calls.length,0);
 ok(nodes(fileTree).some(node=>node.props?.role==='alert'&&node.props.children.includes('.xlsx')));
 let resolvePreview;
 globalThis.__responses.push(new Promise(resolve=>{resolvePreview=resolve;}));
 const reading=upload(fileTree)();fileTree=fileRender();
 eq(mark(fileTree,'Frame').props.canSubmit,false);
 ok(button(fileTree,'Ajouter une ligne').props.disabled);ok(button(fileTree,'Coller depuis Excel').props.disabled);
 ok(input(fileTree,'group-opening-stock').props.disabled);
 ok(nodes(fileTree).some(node=>node.props?.role==='status'&&node.props.children==='Lecture du fichier Excel…'));
 await mark(fileTree,'Frame').props.onSubmit();
 eq(globalThis.__calls.length,1);
 eq(globalThis.__calls[0].path,'/api/logistique/saisie-multiple/articles/apercu-excel');
 eq(globalThis.__calls[0].options.method,'POST');
 eq(globalThis.__calls[0].options.body.get('file').name,'Articles.xlsx');
 const invalidFileRow=[...excelCells[1]];invalidFileRow[5]='';
 resolvePreview({success:true,data:{cells:[excelCells[0],invalidFileRow]}});
 await reading;fileTree=fileRender();await fileHooks.flush();
 fileGrid=mark(fileTree,'SimpleTable');
 eq(fileGrid.props.rows.length,2);eq(fileGrid.props.rows[0].clientRowId,oldDraft.clientRowId);
 eq(fileGrid.props.rows[0].values.NomArticle,'Article saisi');
 const fileDraft=fileGrid.props.rows[1];
 eq(fileDraft.values.CodeArticleInterne,'000123');
 ok(focusedRows.at(-1).endsWith(fileDraft.clientRowId+'PUArticle'));
 const price=nodes(fileGrid.props.columns.find(column=>column.key==='PUArticle').render(fileDraft)).find(node=>node.type==='input');
 ok(price.props['aria-invalid']);ok(!price.props.disabled);
 eq(fileSaved.length,0);eq(globalThis.__calls.length,1);
 ok(nodes(fileTree).some(node=>node.props?.role==='status'&&node.props.children==='1 ligne ajoutée au panier.'));
 globalThis.__responses.push({success:false,status:422,message:'La feuille Articles est introuvable.'});
 await upload(fileTree)();fileTree=fileRender();await fileHooks.flush();
 eq(mark(fileTree,'SimpleTable').props.rows.length,2);
 ok(nodes(fileTree).some(node=>node.props?.role==='alert'&&node.props.children==='La feuille Articles est introuvable.'));
 ok(focusedRows.at(-1).endsWith('import-excel'));
 globalThis.__responses.push({success:true,data:{cells:[['Article'],[123]]}});
 await upload(fileTree)();fileTree=fileRender();
 eq(mark(fileTree,'SimpleTable').props.rows.length,2);
 ok(nodes(fileTree).some(node=>node.props?.role==='alert'&&node.props.children.includes('aperçu')));
 const maxRows=Array.from({length:100},(_,index)=>['Classeur '+index]);
 globalThis.__responses.push({success:true,data:{cells:[['Article'],...maxRows]}});
 await upload(fileTree)();fileTree=fileRender();
 eq(mark(fileTree,'SimpleTable').props.rows.length,2);
 ok(nodes(fileTree).some(node=>node.props?.role==='alert'&&node.props.children.includes('100 lignes')));
 input(fileTree,'group-opening-stock').props.onChange({target:{checked:true}});
 fileTree=fileRender();
 globalThis.__responses.push({success:true,data:{cells:[['Article'],...maxRows]}});
 await upload(fileTree)();fileTree=fileRender();
 eq(mark(fileTree,'SimpleTable').props.rows.length,102);
 globalThis.__responses.push(new Promise(resolve=>{resolvePreview=resolve;}));
 const closing=upload(fileTree)();
 const previewSignal=globalThis.__calls.at(-1).options.signal;
 fileHooks.unmount();
 eq(previewSignal.aborted,true);
 resolvePreview({success:true,data:{cells:excelCells}});
 await closing;
 eq(fileSaved.length,0);

 // Les paniers tiers et immobilisations proposent le même fichier contrôlé,
 // sans enregistrer ni remplacer une saisie déjà commencée.
 for(const kind of ['tiers','immobilisations']){
  globalThis.__calls=[];globalThis.__responses=[];globalThis.__refs=refs;
  const h=new Hooks(),r=()=>h.render(ui.default,{...props,kind});r();await h.flush();let t=r();
  ok(button(t,'Télécharger le modèle Excel'));ok(button(t,'Importer un fichier Excel'));
  await button(t,'Télécharger le modèle Excel').props.onClick();t=r();
  eq(globalThis.__calls[0].path,'/api/logistique/saisie-multiple/'+kind+'/modele-excel');
  const cells=kind==='tiers'?[['Nom','ID_TypeClientFk','Telephone','Actif'],['Alice importée','Inconnu','00123','oui']]
    :[['NomImmobilisation','ID_CategorieFk','Quantite','SuiviIndividuel','PrixUnitaire','ID_DeviseFk','DateEntree','motif'],
      ['Bureaux','Matériel','2','Non','100,50','USD','2026-11-07T09:10:11','Reprise']];
  globalThis.__responses.push({success:true,data:{cells}});
  const file=new File(['xlsx'],'panier.xlsx'),target={files:[file],value:file.name};
  await nodes(t).find(n=>n.type==='input'&&n.props.type==='file').props.onChange({currentTarget:target});
  t=r();let g=mark(t,'SimpleTable');eq(g.props.rows.length,1);eq(target.value,'');
  const call=globalThis.__calls.at(-1);eq(call.path,'/api/logistique/saisie-multiple/'+kind+'/import-excel');eq(call.options.body.get('fichier').name,'panier.xlsx');
  const line=g.props.rows[0];eq(line.values[kind==='tiers'?'Nom':'NomImmobilisation'],kind==='tiers'?'Alice importée':'Bureaux');
  eq(globalThis.__calls.filter(c=>c.path.endsWith('/'+kind)).length,0);
  if(kind==='tiers'){
   eq(line.values.Telephone,'00123');eq(line.values.Actif,true);eq(line.values.ID_TypeClientFk,'Inconnu');
   const c=g.props.columns.find(c=>c.key==='ID_TypeClientFk').render(line),select=nodes(c).find(n=>n.type?.name==='Select');
   ok(select.props.invalid);ok(select.props.options.find(o=>o.value==='Inconnu').disabled);
   select.props.onChange('3');t=r();eq(mark(t,'SimpleTable').props.rows[0].values.ID_TypeClientFk,'3');
  }else{
   eq(line.values.ID_CategorieFk,'40');eq(line.values.SuiviIndividuel,false);eq(line.values.DateEntree,'2026-11-07T09:10:11');
   eq(p.validateLogisticsBatch(kind,g.props.rows,refs),{header:{},rows:{}});
  }
  // Une perte d'accès intervenue pendant la lecture ne peut appliquer sa réponse.
  let finish;globalThis.__responses.push(new Promise(resolve=>finish=resolve));
  const nextTarget={files:[file],value:file.name};
  const pending=nodes(t).find(n=>n.type==='input'&&n.props.type==='file').props.onChange({currentTarget:nextTarget});
  globalThis.__user={...globalThis.__user,permissions:{canWriteData:false}};t=r();
  finish({success:true,data:{cells}});await pending;t=r();eq(mark(t,'SimpleTable').props.rows.length,1);eq(mark(t,'Frame').props.readOnly,true);
  h.unmount();globalThis.__user={...globalThis.__user,permissions:{canWriteData:true}};
 }
 const invalidTiers=p.logisticsBatchFromMatrix('tiers',[['Nom','ID_TypeClientFk','Actif'],['A','3','incompréhensible']],refs,{hasHeaders:true});
 ok(p.validateLogisticsBatch('tiers',invalidTiers,refs).rows[invalidTiers[0].clientRowId].Actif);
 const dates=p.logisticsBatchFromMatrix('immobilisations',[['NomImmobilisation','DateEntree','DateAcquisition'],['Bien','2026-11-07T08:09:10Z','2026-11-07T00:00:00']],refs,{hasHeaders:true});
 eq(dates[0].values.DateEntree,'2026-11-07T09:09:10');eq(dates[0].values.DateAcquisition,'2026-11-07');
 const invalidDate=p.logisticsBatchFromMatrix('immobilisations',[['NomImmobilisation','DateEntree'],['Bien','2026-02-31T08:09:10Z']],refs,{hasHeaders:true});
 eq(invalidDate[0].values.DateEntree,'2026-02-31T08:09:10Z');ok(p.validateLogisticsBatch('immobilisations',invalidDate,refs).rows[invalidDate[0].clientRowId].DateEntree);

 const h=new Hooks(),r=()=>h.render(ui.default,props);r();await h.flush();tree=r();globalThis.__scope={...globalThis.__scope,scopeKey:'B',entityId:'8'};tree=r();eq(mark(tree,'Frame').props.readOnly,true);ok(!mark(tree,'SimpleTable'));eq(mark(tree,'Frame').props.error,'L’entreprise a changé. Rouvrez la saisie dans le nouvel espace.');h.unmount();
 // Les erreurs d’en-tête reçoivent réellement le focus, sans effacer le panier.
 for(const field of ['photos','motif']){globalThis.__refs=refs;const focused=[];globalThis.document={getElementById:id=>({focus(){focused.push(id);}})};const h=new Hooks(),r=()=>h.render(ui.default,props);r();await h.flush();let t=r();const grid=mark(t,'SimpleTable'),cell=grid.props.columns.find(c=>c.key==='Nom').render(grid.props.rows[0]);nodes(cell).find(n=>n.type==='input').props.onChange({target:{value:'Test'}});globalThis.__responses.push({success:false,status:422,error:{details:{rows:{},header:{[field]:'À corriger'}}}});t=r();await mark(t,'Frame').props.onSubmit();t=r();await h.flush();ok(focused.some(id=>id.endsWith(field)));eq(mark(t,'SimpleTable').props.rows[0].values.Nom,'Test');h.unmount();}
 // Les droits retournés par les références priment sur les droits généraux du compte.
 globalThis.__refs={...refs,canCreate:false};const deniedHooks=new Hooks(),deniedRender=()=>deniedHooks.render(ui.default,props);deniedRender();await deniedHooks.flush();tree=deniedRender();eq(mark(tree,'Frame').props.readOnly,true);ok(mark(tree,'Frame').props.error.includes('ne permet pas'));ok(button(tree,'Ajouter une ligne').props.disabled);const callsBefore=globalThis.__calls.length;await mark(tree,'Frame').props.onSubmit();eq(globalThis.__calls.length,callsBefore);deniedHooks.unmount();globalThis.__refs=refs;
 // Les nouveaux libellés de fermeture restent optionnels pour les éditeurs existants.
 const realFrame=await bundle("export {default} from './src/components/RecordEditorFrame.jsx';",[mocks([[/^react$/,'frame-hooks',`export const useState=v=>globalThis.__hooks.state(v),useRef=v=>globalThis.__hooks.ref(v),useId=()=>globalThis.__hooks.id(),useEffect=(f,d)=>globalThis.__hooks.effect(f,d);`],[/\.\/DrawerDialog$/,'drawer',`export default function Drawer(){}`],[/\.\/ActionButton$/,'frame-button',`export default function Button(){}`]])]);
 const frameHooks=new Hooks();let closed=0;const frameProps={title:'Fiche',dirty:true,onClose:()=>closed++},frameRender=()=>frameHooks.render(realFrame.default,frameProps);tree=frameRender();mark(tree,'Drawer').props.onClose();tree=frameRender();const footer=mark(tree,'Drawer').props.footer;ok(nodes(footer).some(n=>n.type==='span'&&n.props.children==='Abandonner les modifications ?'));button(footer,'Abandonner').props.onClick();eq(closed,1);frameProps.busy=true;tree=frameRender();mark(tree,'Drawer').props.onClose();eq(closed,1);ok(button(mark(tree,'Drawer').props.footer,'Abandonner').props.disabled);frameHooks.unmount();
 console.log(JSON.stringify({success:true,checks,scope:'Helpers réels et événements React avec doubles API/auth, sans navigateur ni écriture applicative'}));
})().catch(error=>{console.error(error);process.exit(1);});
