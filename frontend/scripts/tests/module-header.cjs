// Composant réel, rendu JSX et handlers DOM contrôlés ; aucun navigateur/API.
const fs=require('node:fs'),path=require('node:path'),Module=require('node:module'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../..'),front=path.join(root,'frontend'),esbuild=require(path.join(front,'node_modules/esbuild'));
let checks=0;const eq=(a,b)=>{assert.deepEqual(a,b);checks++;},ok=value=>{assert(value);checks++;};
function nodes(tree,out=[]){if(!tree||typeof tree!=='object')return out;if(Array.isArray(tree)){tree.forEach(n=>nodes(n,out));return out;}if(tree.type)out.push(tree);nodes(tree.props?.children,out);return out;}
(async()=>{
 const built=await esbuild.build({stdin:{contents:"export {default as Header} from './src/components/ModuleHeader';",resolveDir:front},bundle:true,write:false,platform:'node',format:'cjs',jsx:'automatic',loader:{'.css':'empty'},plugins:[{name:'mocks',setup(build){
  build.onResolve({filter:/^react\/jsx-runtime$|^react-router-dom$|\/contexts\/AuthContext$|\.\/EntityScopePicker$|\.\/AccountControls$/},args=>({path:args.path,namespace:'fixture'}));
  build.onLoad({filter:/.*/,namespace:'fixture'},args=>({loader:'js',contents:args.path==='react/jsx-runtime'?`export const jsx=(type,props,key)=>({type,props,key}),jsxs=jsx,Fragment='fragment';`:args.path==='react-router-dom'?`export const Link='Link';`:args.path.endsWith('AuthContext')?`export const useAuth=()=>({user:globalThis.__headerUser});`:`export default '${args.path.endsWith('EntityScopePicker')?'Scope':'Account'}';`}));
 }}]});
 const loaded=new Module(path.join(front,'module-header-proof.cjs'));loaded.filename=path.join(front,'module-header-proof.cjs');loaded.paths=Module._nodeModulePaths(front);loaded._compile(built.outputFiles[0].text,loaded.filename);const {Header}=loaded.exports;
 globalThis.__headerUser={permissions:{canWriteData:true}};
 for(const title of ['Logistique','Caisse','Professionnels','Structures','Référentiels','Administration','Support','Paramètres','Guide utilisateur','Organisation territoriale','Produits','Mon profil']){
  const tree=Header({title}),all=nodes(tree),crumbs=all.find(n=>n.type==='nav');
  eq(crumbs.props['aria-label'],'Fil d’Ariane');eq(nodes(crumbs).find(n=>n.props['aria-current']==='page').props.children,title);eq(nodes(crumbs).find(n=>n.type==='Link').props.to,'/espace');
  eq(all.find(n=>n.props.className==='workspace-brand').props.to,'/espace');eq(all.filter(n=>n.type==='Scope').length,['Logistique','Caisse','Professionnels','Structures','Référentiels','Administration','Support','Paramètres','Guide utilisateur'].includes(title)?1:0);
 }
 eq(nodes(Header({title:'Structures',showEntityScope:false})).filter(n=>n.type==='Scope').length,0);
 const trigger={type:'button',props:{className:'module-sidebar-trigger'}};
 const start=nodes(Header({title:'Logistique',menuToggle:trigger})).find(n=>n.props.className==='module-header-start');
 eq(start.props.children[0],trigger);eq(start.props.children[1].type,'nav');
 eq(nodes(Header({title:'Applications'})).includes(trigger),false);
 const openMenu=nodes(Header({title:'Logistique',menuToggle:trigger,menuOpen:true}));
 eq(openMenu.some(n=>n.props.className==='module-skip-content'),false);
 eq(openMenu.find(n=>n.props.className==='module-location').props.inert,true);
 eq(openMenu.find(n=>n.props.className==='module-header-actions').props.inert,true);
 let tree=Header({title:'Administration'}),button=nodes(tree).find(n=>n.props.className==='module-skip-content');eq(button.props.type,'button');eq(button.props.children,'Aller au contenu');
 let focused=0,attributes=[],selector='';const content={hasAttribute:()=>false,setAttribute:(name,value)=>attributes.push([name,value]),focus:opts=>{eq(opts,{preventScroll:false});focused++;}};
 const shell={querySelector:value=>{selector=value;return content;}};
 button.props.onClick({currentTarget:{closest:value=>{eq(value,'.logistics-app,.applications-page');return shell;}}});eq(focused,1);eq(attributes,[['tabindex','-1']]);ok(selector.includes('.logistics-main-column'));ok(selector.includes('main'));
 content.hasAttribute=()=>true;attributes=[];button.props.onClick({currentTarget:{closest:()=>shell}});eq(attributes,[]);eq(focused,2);
 button.props.onClick({currentTarget:{closest:()=>null}});eq(focused,2);
 globalThis.__headerUser={permissions:{canWriteData:false}};tree=Header({title:'Logistique'});ok(nodes(tree).find(n=>n.props.className==='module-read-only'));eq(nodes(tree).find(n=>n.props.className==='module-read-only').props.children,'Consultation');
 const css=fs.readFileSync(path.join(front,'src/components/ModuleHeader.css'),'utf8');for(const text of ['.module-skip-content:focus-visible','@media(max-width:760px)','text-overflow:ellipsis','var(--erp-surface)','var(--erp-text)'])ok(css.includes(text));
 const report={success:true,checks,scope:'Vrai ModuleHeader : liens, repère module, permissions de consultation, contexte entreprise et accès clavier au contenu ; aucun appel API',limits:['DOM contrôlé, pas de recette visuelle navigateur']};fs.writeFileSync(path.join(root,'.runtime/module-header-tests.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));
})().catch(error=>{console.error(error);process.exit(1);});
