// Helpers et composants réels, avec transport contrôlé ; aucune écriture métier.
const path=require('node:path'),Module=require('node:module'),assert=require('node:assert/strict');
const front=path.resolve(__dirname,'../..'),esbuild=require(path.join(front,'node_modules/esbuild'));
let checks=0;const eq=(a,b)=>{assert.deepEqual(a,b);checks++;},ok=(a,message)=>{assert(a,message);checks++;};
async function bundle(contents,plugins=[]){const result=await esbuild.build({stdin:{contents,resolveDir:front,loader:'jsx'},bundle:true,write:false,platform:'node',format:'cjs',jsx:'automatic',external:['react','react/jsx-runtime','react-dom/server'],define:{'import.meta.env':'{}'},loader:{'.css':'empty'},plugins,logLevel:'error'});const mod=new Module(path.join(front,'publication-proof.cjs'),module);mod.filename=path.join(front,'publication-proof.cjs');mod.paths=Module._nodeModulePaths(front);mod._compile(result.outputFiles[0].text,mod.filename);return mod.exports;}
const fixture={IdEntite:7,NomEntite:'Entreprise',PartageArticlesPublicParDefaut:false,_version:'v1',Localisations:[]};
const refs={defaultArticleVisibility:true,defaultCurrencyId:451,currencies:[{id:451,label:'USD',code:'USD'}]};
(async()=>{
 const p=await bundle("export * from './src/utils/entityProfile';export * from './src/pages/logistique/articleForm';export * from './src/pages/logistique/logisticsBatchForm';export {mapArticlePublic,mapPharmacyPublic,matchesSearch} from './src/services/mappers';export {default as Fields} from './src/components/EntityProfileFields';export {renderToStaticMarkup} from 'react-dom/server';export {createElement} from 'react';");
 // Le contrat public territorial reste composite, même si une entreprise partage son ID.
 const district=p.mapPharmacyPublic({key:'n3:7',level:3,id:7,name:'District Exemple',type:'District',province:{name:'Province Exemple'},contactsPublished:false},0);
 const site=p.mapPharmacyPublic({key:'n5:7',level:5,id:7,name:'Pharmacie Exemple',type:'Pharmacie',address:'Rue Exemple',hours:'Lundi : 08h–17h',contactsPublished:true},1);
 eq(district.id,'n3:7');eq(site.id,'n5:7');eq(site.territorialKey,'n5:7');eq(site.name,'Pharmacie Exemple');eq(site.hours,'Lundi : 08h–17h');eq(district.province,'Province Exemple');eq(district.phone,null);ok(p.matchesSearch(district,'district'));
 eq(p.mapPharmacyPublic({IdEntite:7,NomEntite:'Entreprise'},2).territorialKey,null);
 eq(p.entityProfileValues().PartageArticlesPublicParDefaut,true);
 const entity=p.entityProfileValues(fixture);eq(entity.PartageArticlesPublicParDefaut,false);
 eq(p.entityProfileValues({...fixture,PartageArticlesPublicParDefaut:true}).PartageArticlesPublicParDefaut,true);
 eq(p.entityProfileErrors(entity,'Réglage'),{});
 ok(p.entityProfileErrors({...entity,PartageArticlesPublicParDefaut:'false'},'Réglage').PartageArticlesPublicParDefaut);
 const payload=p.entityProfilePayload({...entity,PartageArticlesPublicParDefaut:true},{record:fixture,motif:'Réglage',requestId:'ticket'});
 eq(payload.PartageArticlesPublicParDefaut,true);eq(payload.IdEntite,7);eq(payload._version,'v1');eq(payload.motif,'Réglage');eq(payload.requestId,'ticket');
 const oldRecord={IdEntite:7,NomEntite:'Entreprise',_version:'v1'};
 ok(!Object.hasOwn(p.entityProfilePayload(p.entityProfileValues(oldRecord),{record:oldRecord,motif:'Réglage'}),'PartageArticlesPublicParDefaut'));
 const html=p.renderToStaticMarkup(p.createElement(p.Fields,{active:'identity',prefix:'proof-',values:entity,record:fixture,change(){},errors:{}}));
 ok(html.includes('Rendre les nouveaux articles visibles par défaut'));ok(html.includes('Les articles déjà créés conservent leur réglage.'));
 ok(!/id="proof-PartageArticlesPublicParDefaut"[^>]*checked/.test(html));
 const readOnly=p.renderToStaticMarkup(p.createElement(p.Fields,{active:'identity',prefix:'proof-',values:{...entity,PartageArticlesPublicParDefaut:true},record:fixture,change(){},readOnly:true}));
 ok(/id="proof-PartageArticlesPublicParDefaut"[^>]*disabled/.test(readOnly));ok(readOnly.includes('checked=""'));
 const fresh=p.articleForm(null,refs),old=p.articleForm({...fresh,ID_Article:2,VisibleCatalogue:false,QteArticle:'3'});
 eq(fresh.VisibleCatalogue,true);eq(p.articleForm(null,{defaultArticleVisibility:false}).VisibleCatalogue,false);eq(p.articleForm(null).VisibleCatalogue,false);eq(old.VisibleCatalogue,false);
 const valid={...fresh,NomArticle:'Produit',ID_CategorieArticleFk:'40',ID_TypeArticleFk:'46',ID_UniteFk:'34',ID_DeviseFk:'451',PUArticle:'10',PVArticle:'15'};
 eq(p.articleErrors(valid,true),{});eq(p.articlePayload(valid,null).VisibleCatalogue,true);
 ok(p.articleErrors({...valid,VisibleCatalogue:'false'},true).VisibleCatalogue);
 const existing={...valid,ID_Article:2,QteArticle:'3',VisibleCatalogue:false};
 const edited=p.articlePayload({...p.articleForm(existing),VisibleCatalogue:true},existing,'r2');
 eq(edited.VisibleCatalogue,true);eq(edited._version,'r2');ok(!Object.hasOwn(edited,'QteArticle'));ok(!Object.hasOwn(edited,'ID_UserFK'));
 ok(!Object.hasOwn(p.articlePayload(p.articleForm(existing),existing,'r2'),'VisibleCatalogue'));
 eq(p.articleForm({...existing,VisibleCatalogue:true}, {defaultArticleVisibility:false}).VisibleCatalogue,true);
 const row=p.logisticsBatchRow('articles',refs,{...valid},'row-1');eq(row.values.VisibleCatalogue,true);eq(p.logisticsRowPayload('articles',row).VisibleCatalogue,true);
 eq(p.logisticsBatchRow('articles',{...refs,defaultArticleVisibility:false}).values.VisibleCatalogue,false);
 ok(p.BATCH_KINDS.articles.columns.includes('VisibleCatalogue'));
 const pasted=p.logisticsBatchFromExcel('articles','Article\tVisible dans l’annuaire\nA\tNon\nB\tOui\nC\t',refs,{hasHeaders:true});
 eq(pasted.map(item=>item.values.VisibleCatalogue),[false,true,true]);eq(p.logisticsRowPayload('articles',pasted[0]).VisibleCatalogue,false);
 const invalid=p.logisticsBatchFromExcel('articles','Article\tVisibleCatalogue\nA\tpeut-être',refs,{hasHeaders:true});
 ok(p.validateLogisticsBatch('articles',invalid,refs).rows[invalid[0].clientRowId].VisibleCatalogue);
 const publicRow=p.mapArticlePublic({ID_Article:3,NomArticle:'Produit publié',RefArticle:'REF',PVArticle:'25.50',DeviseCode:'USD',EtatDisponibilite:'Stock déclaré',NomEntite:'Entreprise',AdresseEntite:'Adresse',PhoneEntite:'00123',ObsArticle:'NOTE PRIVÉE',InformationArticle:'INFORMATION PRIVÉE',PUArticle:'19.99',QteArticle:99},0);
 eq(publicRow.price,'25,50 USD');eq(publicRow.availability,'Stock déclaré');eq(publicRow.company,'Entreprise');eq(publicRow.phone,'00123');ok(!JSON.stringify(publicRow).includes('PRIVÉE'));ok(!JSON.stringify(publicRow).includes('19.99'));ok(!Object.hasOwn(publicRow,'QteArticle'));
 eq(p.mapArticlePublic({NomArticle:'Sans devise',PVArticle:'10'},0).price,'10,00 · Devise non renseignée');eq(p.mapArticlePublic({NomArticle:'Sans stock',ValideArticle:true},0).availability,'Disponibilité à confirmer');
 // L’image de la projection se charge par la route autorisée, jamais par un <img> sans JWT.
 const photoFixture={name:'photo-fixtures',setup(build){build.onResolve({filter:/^react$/},()=>({path:'react',namespace:'photo-fixture'}));build.onLoad({filter:/.*/,namespace:'photo-fixture'},()=>({contents:'export const useState=v=>[v,()=>{}];export const useEffect=f=>{globalThis.__clean=f();};',loader:'js'}));for(const[filter,name,source]of[[/\/services\/api$/,'api','export const API_BASE_URL="https://service.invalid";'],[/\/services\/authStorage$/,'auth','export const getAccessToken=()=>"fixture-token";'],[/\.\/AppIcon$/,'icon','export default function Icon(){}']]){build.onResolve({filter},()=>({path:name,namespace:'photo-'+name}));build.onLoad({filter:/.*/,namespace:'photo-'+name},()=>({contents:source,loader:'jsx'}));}}};
 const photos=await bundle("export {default as Photo} from './src/components/ArticlePhoto';",[photoFixture]);
 const reads=[];globalThis.fetch=async(url,options)=>{reads.push({url,options});return{ok:false};};
 photos.Photo({record:{ID_Article:3,PhotoArticle:'/api/public/articles/3/photo?v=0123456789abcdef'},publicCatalogue:true});
 eq(reads.length,1);eq(reads[0].url,'https://service.invalid/api/public/articles/3/photo?v=0123456789abcdef');eq(reads[0].options.headers.Authorization,'Bearer fixture-token');globalThis.__clean();ok(reads[0].options.signal.aborted);
 for(const source of ['/api/public/articles/4/photo?v=0123456789abcdef','/media/Article/private.png','/api/admin/photo','/api/public/articles/3/photo?token=bad']){photos.Photo({record:{ID_Article:3,PhotoArticle:source},publicCatalogue:true});eq(reads.length,1);}
 console.log(JSON.stringify({success:true,checks,coverage:['Défaut entreprise, conservation des anciens réglages et version','Création, édition et panier articles, collage Excel et booléens','Projection commerciale sans notes internes ni prix d’achat','Photo autorisée avec JWT, annulation et refus des autres chemins'],limits:['Helpers et rendu serveur ; transport et effets React contrôlés, aucun navigateur ni écriture applicative']}));
})().catch(error=>{console.error(error);process.exitCode=1;});
