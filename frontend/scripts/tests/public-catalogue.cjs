// Brochure publique et frontière d’accès : aucun navigateur, aucune donnée métier.
const path=require('node:path'),Module=require('node:module'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../..'),front=path.join(root,'frontend');
const esbuild=require(path.join(front,'node_modules/esbuild')),React=require(path.join(front,'node_modules/react')),server=require(path.join(front,'node_modules/react-dom/server'));
let checks=0;const eq=(a,b)=>{assert.deepEqual(a,b);checks++;},ok=(value,message)=>{assert(value,message);checks++;};
const stubs=[
 [/\/contexts\/AuthContext$/,'auth',`export const useAuth=()=>globalThis.__auth;`],
 [/\/components\/ThemePicker$/,'theme',`export default function Theme(){return <button aria-label="Choisir le thème">Thème</button>;}`],
 [/^react-router-dom$/,'router',`export function Link({to,children,...props}){return <a href={to} {...props}>{children}</a>;}export const useLocation=()=>globalThis.__location,useMatch=p=>globalThis.__location.pathname===p?{}:null,useNavigate=()=>()=>{};export function Navigate(){}export function Route(){}export function Routes(){}`],
];
async function bundle(contents,extra=[]){const built=await esbuild.build({stdin:{contents,loader:'jsx',resolveDir:front},bundle:true,platform:'node',format:'cjs',jsx:'automatic',write:false,external:['react','react/jsx-runtime'],loader:{'.css':'empty'},define:{'import.meta.env':'{}'},plugins:[{name:'fixtures',setup(build){build.onResolve({filter:/^\.\/pages\//},args=>args.kind==='dynamic-import'?{path:args.path.split('/').pop(),namespace:'unloaded-page'}:undefined);build.onLoad({filter:/.*/,namespace:'unloaded-page'},()=>({contents:'export default function Unloaded(){}',loader:'jsx'}));for(const[filter,name,source]of[...extra,...stubs]){build.onResolve({filter},()=>({path:name,namespace:name}));build.onLoad({filter:/.*/,namespace:name},()=>({contents:source,loader:'jsx',resolveDir:front}));}}}],logLevel:'error'});const compiled=new Module(path.join(front,'public-catalogue-proof.cjs'));compiled.filename=path.join(front,'public-catalogue-proof.cjs');compiled.paths=Module._nodeModulePaths(front);compiled._compile(built.outputFiles[0].text,compiled.filename);return compiled.exports;}
(async()=>{
 const page=await bundle("export {default,catalogueDestination} from './src/pages/PublicCatalogue';");
 globalThis.fetch=()=>{throw Error('La brochure ne doit pas appeler une API.');};
 for(const path of ['/produits','/experts','/pharmacies','/logistique']){
  eq(page.catalogueDestination(path,false),'/login?redirect='+encodeURIComponent(path));eq(page.catalogueDestination(path,true),path);
 }
 globalThis.__auth={isAuthenticated:false,loading:false};
 const html=server.renderToStaticMarkup(React.createElement(page.default));
 eq((html.match(/<h1(?:\s|>)/g)||[]).length,1);ok(html.includes('Aller au contenu'));ok(html.includes('id="catalogue-main"'));ok(html.includes('id="services"'));ok(html.includes('id="entreprises"'));ok(html.includes('id="demarche"'));eq((html.match(/<details>/g)||[]).length,3);
 for(const path of ['/produits','/experts','/pharmacies','/logistique'])ok(html.includes('href="/login?redirect='+encodeURIComponent(path)+'"'));
 ok(html.includes('Les annuaires et les échanges sont accessibles après connexion.'));ok(html.includes('Les prévisions et les effets sur la santé restent à évaluer.'));ok(html.includes('Sa publication ne constitue pas une vérification des diplômes'));ok(!html.includes('En amélioration'));ok(!html.includes('/register'));ok(!html.includes('onclick='));ok(!html.includes('data:image'));
 for(const [,href]of html.matchAll(/href="([^"]+)"/g)){ok(href.startsWith('#')||href.startsWith('/'),'Lien local attendu');if(href.startsWith('#'))ok(html.includes('id="'+href.slice(1)+'"'),'Ancre existante');}
 globalThis.__auth={isAuthenticated:true,loading:false};const signed=server.renderToStaticMarkup(React.createElement(page.default));ok(signed.includes('Mes applications'));ok(signed.includes('Ouvrir mes applications'));ok(signed.includes('href="/experts"'));ok(signed.includes('href="/produits"'));ok(!signed.includes('/login?redirect='));
 // App invoquée avec les hooks de routage contrôlés. Les lazy views ne chargent
 // aucun module métier ; usePublicCatalogue fait échouer le test s’il est appelé.
 const app=await bundle("export {default} from './src/App';",[
  [/\/components\/LazyView$/,'lazy',`export default function lazyView(load){const kind=/PublicCatalogue/.test(String(load))?"PublicCatalogue":/WorkspaceHome/.test(String(load))?"WorkspaceHome":/Logistique/.test(String(load))?"Logistique":/Pharmacies/.test(String(load))?"Pharmacies":/Products/.test(String(load))?"Products":/Experts/.test(String(load))?"Experts":"LazyPage";function View(){}View.proofKind=kind;return View;}`],
  [/\/hooks\/usePublicCatalogue$/,'catalogue',`export function usePublicCatalogue(){throw Error("Catalogue métier monté sur une brochure publique");}`],
  [/\/pages\/Login$/,'login',`export default function Login(){}export function SessionLoading(){}`],
  [/\/components\/(ModuleSidebar|ModuleHeader|AdminRoute|Navbar|ProtectedRoute|ModuleGate)$/,'component',`export default function Boundary(){}`],
 ]);
 globalThis.__location={pathname:'/catalogue',search:'',hash:''};
 for(const auth of[{loading:true,isAuthenticated:false},{loading:false,isAuthenticated:false},{loading:false,isAuthenticated:true}]){globalThis.__auth={...auth,user:null};eq(app.default().type.proofKind,'PublicCatalogue');}
 globalThis.__auth={loading:false,isAuthenticated:false,user:null};
 for(const pathname of['/','/produits','/pharmacies','/experts','/logistique','/discussions','/admin']){globalThis.__location={pathname,search:'',hash:''};const view=app.default();eq(view.type.name,'Navigate');ok(view.props.to.startsWith('/login'));}
 globalThis.__auth={loading:true,isAuthenticated:false,user:null};globalThis.__location={pathname:'/',search:'',hash:''};eq(app.default().type.name,'SessionLoading');
 globalThis.__auth={loading:false,isAuthenticated:true,user:{IdUser:2}};globalThis.__location={pathname:'/',search:'',hash:''};eq(app.default().type.proofKind,'WorkspaceHome');
 globalThis.__location={pathname:'/experts',search:'',hash:''};const experts=app.default();eq(experts.type.name,'Boundary');eq(experts.props.children.type.proofKind,'Experts');
 globalThis.__location={pathname:'/produits',search:'',hash:''};const produits=app.default();eq(produits.type.name,'Boundary');eq(produits.props.children.type.proofKind,'Products');
 globalThis.__location={pathname:'/logistique',search:'',hash:''};const logistique=app.default();eq(logistique.type.name,'Boundary');eq(logistique.props.children.type.name,'Boundary');eq(logistique.props.children.props.children.type.proofKind,'Logistique');
 console.log(JSON.stringify({success:true,checks,coverage:['Brochure sans fetch ni donnée métier','Liens réels et retour après connexion','Entrée ERP protégée et ModuleGate préservé','Une page accessible avant restauration de session','Structure sémantique, ancres et FAQ','Fonctions en développement et recherche présentées sans résultat inventé'],limits:['Rendu HTML serveur et hooks contrôlés ; pas de recette navigateur']}));
})().catch(error=>{console.error(error);process.exitCode=1;});
