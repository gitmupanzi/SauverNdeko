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
globalThis.requestAnimationFrame=fn=>{fn();return 1;};globalThis.cancelAnimationFrame=()=>{};globalThis.document={getElementById:()=>({focus(){},querySelector(){return null;}})};

globalThis.__scope={scopeKey:'entity-7',entityId:'7',canCreate:true,canWrite:true};
globalThis.__depot={depotId:'1',defaultDepotId:'1',depots:[{ID_Depot:1,NomDepot:'Principal',Principal:true,Actif:true},{ID_Depot:2,NomDepot:'Secondaire',Actif:true}]};
globalThis.__writes=[];globalThis.__reads=[];globalThis.__responses=[];
globalThis.__read=(url)=>url.startsWith('/depots/')?{success:true,data:{ID_Depot:1,NomDepot:'Principal',CodeDepot:'D1',Actif:true,Principal:true,Version:7},meta:{canEdit:true,revision:'7'}}:url.startsWith('/transferts/')?{success:true,data:globalThis.__transfer,meta:{revision:'7'}}:{success:true,data:[{ID_Article:3,NomArticle:'Produit',StockDisponible:'4.125',QteArticle:'5',DecimalesStock:3}],meta:{filteredCount:1}};
const fixture=mocks([
 [/\/hooks\/useLogisticsRegisterSettings$/,'register-settings',`export default function useSettings(){return{columnsAnchorRef:{current:null},columnsOpen:false,tableProps:{},toolbarProps:{},open(){}};}`],
 [/\/components\/RegisterSettingsButton$/,'register-settings-button',`export default function SettingsButton(){}`],
 [/^react$/,'hooks',`export const useState=v=>globalThis.__hooks.state(v),useRef=v=>globalThis.__hooks.ref(v),useId=()=>globalThis.__hooks.id(),useEffect=(f,d)=>globalThis.__hooks.effect(f,d),useMemo=f=>f();`],
 [/\/contexts\/EntityScopeContext$/,'scope',`export const useEntityScope=()=>globalThis.__scope;`],
 [/\/contexts\/DepotScopeContext$/,'depot',`export const useDepotScope=()=>globalThis.__depot;export function DepotField(){}`],
 [/\/components\/ConsultationProvider$/,'consult',`export const useConsultations=()=>({openProduct(){},openOrder(){}});`],
 [/\/components\/RecordEditorFrame$/,'frame',`export default function Frame(){}`],
 [/\/components\/RegisterSurface$/,'register',`export default function Surface(){}`],
 [/\/components\/ActionButton$/,'button',`export default function Button(){}`],
 [/\/components\/SearchSelect$/,'select',`export default function Select(){}`],
 [/\/components\/RowActionsMenu$/,'actions',`export default function Actions(){}`],
 [/\/components\/DataTableToolbar$/,'toolbar',`export default function Toolbar(){}`],
 [/\/components\/BusinessDocuments$/,'documents',`export default function Documents(){}`],
 [/\/components\/LotFields$/,'lots',`export default function Lots(){}`],
 [/\.\/logistiqueShared$/,'shared',`export function SimpleTable(){};export const formatNumber=x=>String(x??'—'),formatDate=x=>x;`],
 [/\/services\/depots$/,'transport',`export async function depotRead(url,query){globalThis.__reads.push({url,query});return globalThis.__read(url,query);}export async function depotWrite(url,payload,method){globalThis.__writes.push({url,payload,method});return globalThis.__responses.shift()||{success:true,status:200,data:{ID_Depot:1,ID_TransfertDepot:5,...payload}};}export const depotRecord=r=>r.data,depotRevision=(r,m)=>String(m.revision??r.Version),depotFailure=(r,f)=>r.message||f,depotUncertain=r=>!r.status||r.status>=500;`],
]);
async function mount(Component,props={}){const hooks=new Hooks(),render=()=>hooks.render(Component,props);for(let i=0;i<3;i++){render();await hooks.flush();}return{hooks,render,change(key,value){const item=control(render(),key);ok(item,'Champ '+key);item.props.onChange(item.type==='input'||item.type==='textarea'?{target:{value,checked:value}}:value);},frame(){return named(render(),'Frame').props;}};}
const button=(tree,label)=>nodes(tree).find(node=>node.type?.name==='Button'&&node.props.children===label);
const table=(tree,label)=>nodes(tree).find(node=>node.type?.name==='SimpleTable'&&node.props.columns.some(col=>col.key===label));
(async()=>{
 const ui=await bundle("export {DepotEditor} from './src/pages/logistique/Depots';export {TransferEditor} from './src/pages/logistique/Transferts';export * from './src/pages/logistique/transfertForm';",[fixture]);
 let form=ui.transferForm(null,'1','451');form={...form,ID_DepotDestinationFk:'2',Motif:'Approvisionnement',lignes:[{ID_ArticleFk:'3',QteDemandee:'1,125',Lots:[],ObsLigne:''}]};eq(ui.transferErrors(form),[]);eq(ui.transferPayload(form).lignes[0].QteDemandee,'1.125');eq(ui.transferPayload(form).lignes[0].ObsLigne,'');eq(ui.transferPayload(form).transfert.ReferenceTransfert,'');ok(ui.transferErrors({...form,ID_DepotDestinationFk:'1'}).some(x=>x.includes('différents')));ok(ui.transferErrors({...form,ID_DeviseFk:''}).length);ok(ui.transferErrors({...form,lignes:[...form.lignes,...form.lignes]}).some(x=>x.includes('Regroupez')));ok(ui.transferErrors({...form,lignes:[{...form.lignes[0],QteDemandee:'0.1',DecimalesStock:0}]}).length);eq(ui.transferActionLines({lignes:[{ID_ArticleFk:3}]},{3:'1,125'}),[{ID_ArticleFk:'3',Quantite:'1.125'}]);
 // Le formulaire de dépôt appelle le contrat réel et conserve une même preuve en cas de réponse incertaine.
 let saved=[],editor=await mount(ui.DepotEditor,{onSaved:r=>saved.push(r),onClose(){}});editor.change('NomDepot','Dépôt neuf');globalThis.__responses=[{success:false,status:503,message:'Indisponible'}];await editor.frame().onSubmit();eq(globalThis.__writes.length,1);eq(editor.frame().submitLabel,'Réessayer');editor.change('NomDepot','Interdit pendant la vérification');await editor.frame().onSubmit();eq(globalThis.__writes[0].payload,globalThis.__writes[1].payload);eq(saved.length,1);eq(globalThis.__writes[0].payload.NomDepot,'Dépôt neuf');editor.hooks.unmount();
 editor=await mount(ui.DepotEditor,{depotId:1,onSaved:r=>saved.push(r)});editor.change('NomDepot','Nom corrigé');await editor.frame().onSubmit();ok(editor.frame().error.includes('motif'));editor.change('motif','Correction');await editor.frame().onSubmit();eq(globalThis.__writes.at(-1).payload._version,'7');eq(globalThis.__writes.at(-1).method,'PUT');editor.hooks.unmount();
 globalThis.__scope={...globalThis.__scope,canWrite:false};editor=await mount(ui.DepotEditor,{onSaved:r=>saved.push(r)});eq(editor.frame().canSubmit,false);const before=globalThis.__writes.length;await editor.frame().onSubmit();eq(globalThis.__writes.length,before);editor.hooks.unmount();globalThis.__scope={...globalThis.__scope,canWrite:true};
 // Le catalogue du transfert utilise le disponible local et sauvegarde une demande sans écriture de caisse.
 const refs={currencies:[{id:451,label:'USD',code:'USD'}],defaultCurrencyId:451};editor=await mount(ui.TransferEditor,{references:refs,onSaved:r=>saved.push(r)});editor.change('destination','2');const motive=nodes(editor.render()).find(n=>n.type==='textarea');motive.props.onChange({target:{value:'Réassort'}});const catalogue=table(editor.render(),'StockDisponible');const add=catalogue.props.columns.find(c=>c.key==='actions').render(catalogue.props.rows[0]);add.props.onClick();await editor.frame().onSubmit();eq(globalThis.__writes.at(-1).url,'/transferts');eq(globalThis.__writes.at(-1).payload.transfert.ID_DepotSourceFk,'1');eq(globalThis.__writes.at(-1).payload.transfert.ID_DepotDestinationFk,'2');eq(globalThis.__writes.at(-1).payload.lignes[0].ID_ArticleFk,'3');ok(globalThis.__reads.some(r=>r.url==='/registre/articles'&&r.query.depotId==='1'));editor.hooks.unmount();
 globalThis.__transfer={ID_TransfertDepot:5,CodeTransfert:'TRF-5',ID_DepotSourceFk:1,ID_DepotDestinationFk:2,ID_DeviseFk:451,DateTransfert:'2026-11-07T12:00:00',Motif:'Réassort',ReferenceTransfert:'',EtatCode:'TR_TRANSIT',Version:7,lignes:[{ID_ArticleFk:3,NomArticle:'Produit',QteDemandee:'4.125',QteTransit:'4.125',Lots:[]}],capabilities:{canEdit:false,canReceive:true,canResolveGap:true}};
 editor=await mount(ui.TransferEditor,{transferId:5,references:refs,onSaved:r=>saved.push(r)});button(editor.render(),'Enregistrer la réception').props.onClick();let actionTable=table(editor.render(),'Quantite');actionTable.props.columns.find(c=>c.key==='Quantite').render(actionTable.props.rows[0]).props.onChange({target:{value:'-1'}});await editor.frame().onSubmit();ok(editor.frame().error.includes('positives'));actionTable=table(editor.render(),'Quantite');actionTable.props.columns.find(c=>c.key==='Quantite').render(actionTable.props.rows[0]).props.onChange({target:{value:'1,125'}});await editor.frame().onSubmit();eq(globalThis.__writes.at(-1).url,'/transferts/5/receptionner');eq(globalThis.__writes.at(-1).payload.lignes,[{ID_ArticleFk:'3',Quantite:'1.125'}]);eq(globalThis.__writes.at(-1).payload._version,'7');eq(globalThis.__writes.at(-1).payload.motif,'');editor.hooks.unmount();
 // Un écart sélectionné reprend le transit entier, sans saisie libre de quantité.
 editor=await mount(ui.TransferEditor,{transferId:5,references:refs,onSaved:r=>saved.push(r)});button(editor.render(),'Constater un écart définitif').props.onClick();actionTable=table(editor.render(),'Quantite');const choice=nodes(actionTable.props.columns.find(c=>c.key==='Quantite').render(actionTable.props.rows[0])).find(n=>n.type==='input');eq(choice.props.type,'checkbox');choice.props.onChange({target:{checked:true}});await editor.frame().onSubmit();ok(editor.frame().error.includes('motif'));const reason=nodes(editor.render()).find(n=>n.type==='textarea');reason.props.onChange({target:{value:'Perte justifiée'}});await editor.frame().onSubmit();eq(globalThis.__writes.at(-1).payload.lignes,[{ID_ArticleFk:'3',Quantite:'4.125'}]);editor.hooks.unmount();
 console.log(JSON.stringify({success:true,checks,scope:'Helpers exacts et handlers réels dépôts/transferts, transport et DOM simulés, aucune base ni écriture applicative'}));
})().catch(error=>{console.error(error);process.exit(1);});
