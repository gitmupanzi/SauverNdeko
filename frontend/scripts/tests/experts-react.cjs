// Cycle React réel via un renderer temporaire de même version : aucun navigateur ni appel applicatif.
// node experts-react.cjs /chemin/react-test-renderer/index.js (NODE_PATH=frontend/node_modules)
const path=require('node:path'),Module=require('node:module'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../..'),front=path.join(root,'frontend'),React=require(path.join(front,'node_modules/react')),esbuild=require(path.join(front,'node_modules/esbuild'));
const rendererPath=process.argv[2];if(!rendererPath)throw Error('Indiquez un react-test-renderer temporaire correspondant à la version de React.');
const Renderer=require(path.resolve(rendererPath)),{act}=React;let checks=0;
const eq=(a,b)=>{assert.deepEqual(a,b);checks++;},ok=value=>{assert(value);checks++;};
globalThis.IS_REACT_ACT_ENVIRONMENT=true;
globalThis.localStorage={getItem:()=>null,setItem(){}};globalThis.document={getElementById:()=>({focus(){}})};globalThis.requestAnimationFrame=fn=>fn();
let timerSequence=0;const timers=new Map(),nativeTimeout=globalThis.setTimeout,nativeClear=globalThis.clearTimeout;
globalThis.setTimeout=(fn,delay,...args)=>{if(delay===15000){const id='directory-'+(++timerSequence);timers.set(id,()=>{timers.delete(id);fn(...args);});return id;}return nativeTimeout(fn,delay,...args);};
globalThis.clearTimeout=id=>{if(timers.has(id)){timers.delete(id);return;}return nativeClear(id);};
const originalError=console.error;console.error=(...args)=>{if(!String(args[0]).includes('react-test-renderer is deprecated'))originalError(...args);};
const entries=[
 [/\/services\/authStorage$/,"storage",`export const getAccessToken=()=>"token-fixture";`],
 [/\/components\/ProductPhotoPicker$/,"photo",`export default function Photo(p){return <photo-stub {...p}/>;}`],
 [/\/contexts\/EntityScopeContext$/,'scope',`export const useEntityScope=()=>globalThis.__scope;`],
 [/\/contexts\/AuthContext$/,'auth',`export const useAuth=()=>({user:globalThis.__user,refreshUser:globalThis.__refreshUser});`],
 [/\/services\/api$/,'api',`export const requestJson=(path,options)=>globalThis.__request(path,options);export const API_BASE_URL="";`],
 [/\/components\/RegisterSurface$/,'surface',`export default function Surface(p){return <surface-stub actions={p.actions}>{p.actions}{p.children}</surface-stub>;}`],
 [/\/components\/DataTableToolbar$/,'toolbar',`export default function Toolbar(p){return <toolbar-stub {...p}/>;}`],
 [/\/components\/ActionButton$/,'button',`export default function Button(p){return <button-stub {...p}>{p.children}</button-stub>;}`],
 [/\/components\/SearchSelect$/,'select',`export default function Select(p){return <select-stub {...p}/>;}`],
 [/\/components\/RecordEditorFrame$/,'frame',`export default function Frame(p){return <frame-stub {...p}>{p.children}</frame-stub>;}`],
 [/\/components\/ConsultationTabs$/,'tabs',`export default function Tabs(p){return <tabs-stub {...p}/>;}`],
 [/\/components\/AppIcon$/,'icon',`export default function Icon(){return null;}`],
 [/\/components\/RegisterSettingsButton$/,'settings',`export default function Settings(p){return <settings-stub {...p}/>;}`],
 [/\/components\/RowActionsMenu$/,'menu',`export default function Menu(p){return <menu-stub {...p}/>;}`],
 [/\/ExpertReferences$/,'references',`export default function References(){return null;}`],
 [/\/ExpertAvatar$/,'avatar',`export default function Avatar(){return null;}`],
 [/\/logistique\/logistiqueShared$/,'table',`export function SimpleTable(p){return <table-stub {...p}/>;}`],
];
async function bundle(customContents=null,customEntries=entries){const built=await esbuild.build({stdin:{contents:customContents||"export {default as Directory} from './src/pages/experts/ExpertDirectory';export {default as Detail} from './src/pages/experts/ExpertDetail';export {default as Editor} from './src/pages/experts/ExpertEditor';",loader:'jsx',resolveDir:front},bundle:true,jsx:'automatic',external:['react','react/jsx-runtime'],platform:'node',format:'cjs',write:false,loader:{'.css':'empty'},plugins:[{name:'fixtures',setup(build){for(const[filter,name,source]of customEntries){build.onResolve({filter},()=>({path:name,namespace:name}));build.onLoad({filter:/.*/,namespace:name},()=>({contents:source,loader:'jsx',resolveDir:front}));}}}],logLevel:'error'});const compiled=new Module(path.join(front,'experts-real-react.cjs'),module);compiled.filename=path.join(front,'experts-real-react.cjs');compiled.paths=Module._nodeModulePaths(front);compiled._compile(built.outputFiles[0].text,compiled.filename);return compiled.exports;}
function text(node){if(node==null)return '';if(typeof node==='string'||typeof node==='number')return String(node);if(Array.isArray(node))return node.map(text).join(' ');return text(node.children);}
const scope={scopeKey:'u:9',entityId:'9',globalAdmin:false},context={canManage:true,canReadRegistry:true,canPublish:true,readOnly:false};
(async()=>{
 const {Directory,Detail,Editor}=await bundle();globalThis.__scope={...scope};globalThis.__user={};let calls=0,resolveRead,component;
 const props={context,references:{},onOpen(){},onContact(){},onManage:()=>globalThis.__managed=true};
 globalThis.__request=()=>{calls++;return new Promise(resolve=>{resolveRead=resolve;});};
 await act(async()=>{component=Renderer.create(React.createElement(Directory,props));});
 eq(component.root.findByType('toolbar-stub').props.loading,true);eq(calls,1);ok(text(component.toJSON()).includes('Recherche des professionnels…'));
 await act(async()=>resolveRead({success:true,data:{rows:[],total:0}}));
 eq(component.root.findByType('toolbar-stub').props.loading,false);ok(text(component.toJSON()).includes('Aucun profil publié'));eq(text(component.toJSON()).includes('Recherche des professionnels…'),false);eq(timers.size,0);
 await act(async()=>component.update(React.createElement(Directory,{...props,context:{...context},references:{}})));eq(calls,1);eq(component.root.findByType('toolbar-stub').props.loading,false);
 await act(async()=>component.root.findAllByType('button-stub').find(node=>node.props.children==='Profils professionnels').props.onClick());eq(globalThis.__managed,true);
 await act(async()=>component.unmount());eq(timers.size,0);
 // Erreur réseau rejetée : on sort de l'état d'attente et la relance fonctionne.
 calls=0;globalThis.__request=()=>{calls++;return calls===1?Promise.reject(Error('offline')):Promise.resolve({success:true,data:{rows:[],total:0}});};
 await act(async()=>{component=Renderer.create(React.createElement(Directory,props));});eq(component.root.findByType('toolbar-stub').props.loading,false);ok(text(component.toJSON()).includes('La recherche n’a pas abouti.'));eq(timers.size,0);
 await act(async()=>component.root.findAllByType('button-stub').find(node=>node.props.children==='Réessayer').props.onClick());eq(calls,2);eq(component.root.findByType('toolbar-stub').props.loading,false);ok(text(component.toJSON()).includes('Aucun profil publié'));await act(async()=>component.unmount());
 // GET pendante : le délai termine explicitement l'attente avant d'annuler le transport.
 let signal;globalThis.__request=(url,options)=>{signal=options.signal;return new Promise(()=>{});};
 await act(async()=>{component=Renderer.create(React.createElement(Directory,props));});eq(timers.size,1);await act(async()=>[...timers.values()][0]());eq(component.root.findByType('toolbar-stub').props.loading,false);eq(signal.aborted,true);ok(text(component.toJSON()).includes('La recherche prend trop de temps.'));await act(async()=>component.unmount());eq(timers.size,0);
 // Changement de périmètre : la réponse antérieure ne remplace jamais le résultat courant.
 const pending=[];globalThis.__request=(url,options)=>new Promise(resolve=>pending.push({resolve,signal:options.signal}));globalThis.__scope={...scope};
 await act(async()=>{component=Renderer.create(React.createElement(Directory,props));});globalThis.__scope={...scope,scopeKey:'u:10',entityId:'10'};
 await act(async()=>component.update(React.createElement(Directory,props)));eq(pending[0].signal.aborted,true);
 await act(async()=>pending[1].resolve({success:true,data:{rows:[],total:0}}));await act(async()=>pending[0].resolve({success:true,data:{rows:[{id:99,fullName:'Ancien périmètre'}],total:1}}));eq(component.root.findByType('toolbar-stub').props.loading,false);eq(text(component.toJSON()).includes('Ancien périmètre'),false);await act(async()=>component.unmount());eq(timers.size,0);
 // La publication est explicite, visible et les informations manquantes sont indiquées.
 globalThis.__scope={...scope};globalThis.__request=async()=>({success:true,data:{record:{IdProfessionnel:1,fullName:'Exemple',IdSecteurFk:10,TitrePublic:'Médecin',PresentationPublique:null,Publie:false,ValideProfessionnel:true,NomEntite:'Entreprise A'},canManage:true,canPublish:true}});
 await act(async()=>{component=Renderer.create(React.createElement(Detail,{id:1,manage:true,onClose(){},onEdit:()=>globalThis.__edit=true,onAction:()=>globalThis.__action=true}));});
 const publish=component.root.findAllByType('button-stub').find(node=>node.props.children==='Publier dans l’annuaire');ok(publish);eq(publish.props.disabled,true);ok(text(component.toJSON()).includes('présentation'));eq(globalThis.__action,undefined);await act(async()=>component.root.findAllByType('button-stub').find(node=>node.props.children==='Compléter le profil').props.onClick());eq(globalThis.__edit,true);await act(async()=>component.unmount());
 globalThis.__scope={...scope,scopeKey:'global:all',entityId:'',globalAdmin:true};globalThis.__request=async()=>({success:true,data:{record:{IdProfessionnel:1,fullName:'Exemple',Publie:false,ValideProfessionnel:true,NomEntite:'Entreprise A'},canManage:false,canPublish:false}});
 await act(async()=>{component=Renderer.create(React.createElement(Detail,{id:1,manage:true,onClose(){}}));});ok(text(component.toJSON()).includes('Fermez cette fiche, puis sélectionnez l’entreprise'));ok(text(component.toJSON()).includes('Entreprise A'));eq(component.root.findAllByType('button-stub').some(node=>node.props.children==='Publier dans l’annuaire'),false);await act(async()=>component.unmount());

 // La photo reste un brouillon local et suit le même UUID que l'ensemble du profil.
 globalThis.__scope={...scope};globalThis.__user={IdUser:3};globalThis.__refreshCount=0;globalThis.__refreshUser=async()=>{globalThis.__refreshCount++;};let photoReader,photoResult={success:false,status:503},photoWrites=[],savedRecord;
 globalThis.FileReader=class{readAsDataURL(file){this.result='data:image/png;base64,aW1hZ2U=';photoReader=this;}abort(){this.aborted=true;}};
 const refs={users:[{id:3,label:'Expert Exemple'}],secteurs:[{id:10,label:'Santé'}],types:[{id:11,label:'Médecin'}],specialites:[],competences:[],prestations:[],entities:[],typesLiens:[]};
 const existing={IdProfessionnel:21,IdUserFk:3,IdSecteurFk:10,IdTypeProfessionnelFk:11,TitrePublic:'Médecin',Publie:false,ValideProfessionnel:true,photo:'/api/professionnels/profils/21/photo?v=0123456789abcdef'};
 globalThis.__request=async(url,options={})=>{if(options.method){photoWrites.push(options.body);return photoResult;}return {success:true,data:url.includes('/references')?refs:{record:existing,_version:'3',canManage:true}};};
 await act(async()=>{component=Renderer.create(React.createElement(Editor,{context,onClose(){},onSaved:record=>{savedRecord=record;}}));});
 eq(component.root.findByType('frame-stub').props.submitLabel,'Enregistrer le brouillon');eq(component.root.findByType('photo-stub').props.title,'Photo de profil');
 for(const [key,value]of [['IdUserFk','3'],['IdSecteurFk','10'],['IdTypeProfessionnelFk','11']])await act(async()=>component.root.findAllByType('select-stub').find(node=>node.props.id.endsWith('-'+key)).props.onChange(value));
 await act(async()=>component.root.findAllByType('input').find(node=>node.props.id.endsWith('-TitrePublic')).props.onChange({target:{value:'Médecin'}}));
 await act(async()=>component.root.findByType('photo-stub').props.onChange({file:{name:'face.png',type:'image/png',size:8},remove:false}));eq(component.root.findByType('frame-stub').props.canSubmit,false);eq(photoWrites.length,0);await act(async()=>photoReader.onload());eq(component.root.findByType('frame-stub').props.canSubmit,true);
 await act(async()=>component.root.findByType('frame-stub').props.onSubmit());eq(photoWrites.length,1);eq(JSON.parse(photoWrites[0]).photoDataUrl,'data:image/png;base64,aW1hZ2U=');ok(!('photoDataUrl'in JSON.parse(photoWrites[0]).data));eq(component.root.findByType('photo-stub').props.disabled,true);eq(__refreshCount,0);
 photoResult={success:true,data:{record:existing}};await act(async()=>component.root.findByType('frame-stub').props.onSubmit());eq(photoWrites[1],photoWrites[0]);eq(__refreshCount,1);eq(savedRecord.IdProfessionnel,21);await act(async()=>component.unmount());
 // Retrait explicite : motif et version, sans fichier fictif ni mutation de la publication.
 await act(async()=>{component=Renderer.create(React.createElement(Editor,{id:21,context,onClose(){},onSaved(){}}));});eq(component.root.findByType('photo-stub').props.hasExistingPhoto,true);
 await act(async()=>component.root.findByType('photo-stub').props.onChange({file:null,remove:true}));await act(async()=>component.root.findByType('tabs-stub').props.onChange('gestion'));
 await act(async()=>component.root.findAllByType('textarea').find(node=>node.props.id.endsWith('-motif')).props.onChange({target:{value:'Retrait photo'}}));await act(async()=>component.root.findByType('frame-stub').props.onSubmit());eq(JSON.parse(photoWrites.at(-1)).removePhoto,true);ok(!('photoDataUrl'in JSON.parse(photoWrites.at(-1))));eq(JSON.parse(photoWrites.at(-1))._version,'3');ok(!('Publie'in JSON.parse(photoWrites.at(-1)).data));await act(async()=>component.unmount());
 // Abandonner ou rejeter une image ne lance aucune écriture.
 const count=photoWrites.length;await act(async()=>{component=Renderer.create(React.createElement(Editor,{id:21,context,onClose(){},onSaved(){}}));});await act(async()=>component.root.findByType('photo-stub').props.onChange({file:{name:'big.png',type:'image/png',size:9*1024*1024},remove:false}));eq(component.root.findByType('frame-stub').props.canSubmit,false);eq(photoWrites.length,count);
 await act(async()=>component.root.findByType('photo-stub').props.onChange({file:{name:'local.png',type:'image/png',size:8},remove:false}));const pendingPhoto=photoReader;await act(async()=>component.unmount());eq(pendingPhoto.aborted,true);eq(photoWrites.length,count);


 // Avatar réel : lecture bearer du brouillon, version de photo et révocation des aperçus.
 const avatarBundle=await bundle("export {default as Avatar} from './src/pages/experts/ExpertAvatar';",entries.filter(entry=>entry[1]!=='avatar'));
 const originalFetch=globalThis.fetch,originalCreate=URL.createObjectURL,originalRevoke=URL.revokeObjectURL;let photoFetches=[],revoked=[],blobSequence=0;
 globalThis.fetch=async(url,options)=>{photoFetches.push({url,options});return {ok:true,blob:async()=>new Blob(['photo'],{type:'image/jpeg'})};};URL.createObjectURL=()=>`blob:photo-${++blobSequence}`;URL.revokeObjectURL=url=>revoked.push(url);globalThis.__scope={...scope};
 const avatarProps={record:{fullName:'Expert Exemple',photo:'/api/professionnels/profils/21/photo?v=0123456789abcdef'}};
 await act(async()=>{component=Renderer.create(React.createElement(avatarBundle.Avatar,avatarProps));});eq(photoFetches.length,1);eq(photoFetches[0].options.headers.Authorization,'Bearer token-fixture');ok(photoFetches[0].options.headers.Accept.includes('image/png'));eq(component.root.findByType('img').props.src,'blob:photo-1');
 await act(async()=>component.update(React.createElement(avatarBundle.Avatar,{record:{...avatarProps.record,photo:'/api/professionnels/profils/21/photo?v=fedcba9876543210'}})));eq(photoFetches.length,2);eq(component.root.findByType('img').props.src,'blob:photo-2');ok(revoked.includes('blob:photo-1'));
 await act(async()=>component.update(React.createElement(avatarBundle.Avatar,{record:{...avatarProps.record,photo:'/api/professionnels/annuaire/21/photo?v=fedcba9876543210'}})));eq(photoFetches.length,3);
 await act(async()=>component.update(React.createElement(avatarBundle.Avatar,{record:{...avatarProps.record,photo:'/api/professionnels/profils/21/photo?secret=1'}})));eq(photoFetches.length,3);eq(component.root.findAllByType('img').length,0);ok(text(component.toJSON()).includes('EE'));await act(async()=>component.unmount());ok(revoked.includes('blob:photo-3'));
 globalThis.fetch=originalFetch;URL.createObjectURL=originalCreate;URL.revokeObjectURL=originalRevoke;
 // Réutilisation du sélecteur commun : les libellés Articles restent inchangés.
 const pickerBundle=await bundle("export {default as Picker} from './src/components/ProductPhotoPicker';",[...entries.filter(entry=>entry[1]!=='photo'),[/\/ArticlePhoto$/,'article-photo',`export default function ArticlePhoto(){return null;}`]]);
 const pickerProps={record:{},value:{file:null,remove:false},onChange(){}};await act(async()=>{component=Renderer.create(React.createElement(pickerBundle.Picker,pickerProps));});eq(component.root.findByType('section').props['aria-label'],'Photo du produit');eq(component.root.findByType('input').props['aria-label'],'Choisir la photo du produit');await act(async()=>component.unmount());
 await act(async()=>{component=Renderer.create(React.createElement(pickerBundle.Picker,{...pickerProps,title:'Photo de profil',hasExistingPhoto:true,renderCurrentPhoto:()=>React.createElement('avatar-preview'),facingMode:'user'}));});eq(component.root.findAllByType('avatar-preview').length,1);eq(component.root.findByType('input').props['aria-label'],'Choisir la photo de profil');await act(async()=>component.unmount());

 console.log(JSON.stringify({success:true,checks,renderer:require(path.resolve(path.dirname(rendererPath),'package.json')).version,coverage:['Effets et rerendus React réels','GET200 vide termine chargement','Aucune boucle après rerendu parent','Erreur rejetée et relance','Délai15s termine attente et annule transport','Cleanup/changement périmètre refuse réponse tardive','Brouillon et présentation manquante explicites','Publication manuelle visible et contexte entreprise expliqué','Photo locale puis écriture atomique, retry UUID identique, retrait, abandon et rafraîchissement compte','Lecture photo protégée versionnée, URL invalides refusées, Blob URLs révoquées','Sélecteur photo mutualisé compatible Articles'],limits:['RendererNode avec transports et composants communs simulés, aucun navigateur ni écritureDB']}));
})().catch(error=>{console.error(error);process.exitCode=1;}).finally(()=>{globalThis.setTimeout=nativeTimeout;globalThis.clearTimeout=nativeClear;console.error=originalError;});
