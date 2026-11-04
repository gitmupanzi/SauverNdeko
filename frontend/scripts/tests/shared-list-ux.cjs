// Vrais composants React, handlers et état local simulés. Aucun navigateur ni appel API.
const fs=require('node:fs'),path=require('node:path'),Module=require('node:module'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../..'),front=path.join(root,'frontend'),esbuild=require(path.join(front,'node_modules/esbuild'));
let checks=0;
function eq(actual,expected){assert.deepEqual(actual,expected);checks++;}
function ok(value){assert.ok(value);checks++;}
class Hooks{
 constructor(){this.slots=[];this.cursor=0;}
 state(value){const i=this.cursor++;if(!this.slots[i])this.slots[i]={value:typeof value==='function'?value():value};return[this.slots[i].value,next=>{this.slots[i].value=typeof next==='function'?next(this.slots[i].value):next;}];}
 ref(value){const i=this.cursor++;return this.slots[i]||(this.slots[i]={current:value});}
 render(component,props){this.cursor=0;globalThis.__listHooks=this;return component(props);}
}
function nodes(node,out=[]){if(!node||typeof node!=='object')return out;if(Array.isArray(node)){node.forEach(item=>nodes(item,out));return out;}out.push(node);nodes(node.props?.children,out);return out;}
function text(node){if(node==null||typeof node==='boolean')return '';if(Array.isArray(node))return node.map(text).join('');return typeof node==='object'?text(node.props?.children):String(node);}
function find(tree,predicate){const result=nodes(tree).find(predicate);assert.ok(result,'Élément attendu absent');return result;}
function expand(node){if(!node||typeof node!=='object')return node;if(Array.isArray(node))return node.map(expand);if(typeof node.type==='function')return expand(node.type(node.props));return {...node,props:{...node.props,children:expand(node.props?.children)}};}
(async()=>{
 const built=await esbuild.build({stdin:{contents:`export {SimpleTable} from './src/pages/logistique/logistiqueShared';export {default as DataTableToolbar} from './src/components/DataTableToolbar';export {default as TablePagination} from './src/components/TablePagination';export {default as PublicTable} from './src/components/PublicTable';export {default as ListState} from './src/components/ListState';`,resolveDir:front},bundle:true,write:false,platform:'node',format:'cjs',jsx:'automatic',plugins:[{name:'test-fixtures',setup(build){
  build.onResolve({filter:/^react$/},()=>({path:'react',namespace:'fixture'}));
  build.onResolve({filter:/^react\/jsx-runtime$/},()=>({path:'jsx',namespace:'fixture'}));
  build.onResolve({filter:/contexts\/AuthContext$/},()=>({path:'auth',namespace:'fixture'}));
  build.onResolve({filter:/(CategoricalSelect|ColumnPicker|TableSettings|AppIcon)$/},()=>({path:'component',namespace:'fixture'}));
  build.onLoad({filter:/.*/,namespace:'fixture'},args=>({loader:'js',contents:args.path==='react'?`export const useState=v=>globalThis.__listHooks.state(v),useRef=v=>globalThis.__listHooks.ref(v),useMemo=f=>f(),useEffect=()=>{},useLayoutEffect=()=>{},useId=()=>'list-proof';`:args.path==='jsx'?`export const jsx=(type,props,key)=>({type,props,key}),jsxs=jsx,Fragment='fragment';`:args.path==='auth'?`export const useAuth=()=>({user:globalThis.__listUser});`:`export default function Component(){return null;}`}));
  build.onLoad({filter:/\.css$/},()=>({contents:'',loader:'js'}));
 }}]});
 const loaded=new Module(path.join(front,'shared-list-proof.cjs'));loaded.filename=path.join(front,'shared-list-proof.cjs');loaded.paths=Module._nodeModulePaths(front);loaded._compile(built.outputFiles[0].text,loaded.filename);
 const {SimpleTable,DataTableToolbar,TablePagination,PublicTable,ListState}=loaded.exports;
 globalThis.__listUser={permissions:{canExportData:true}};
 const calls=[],toolbar={search:'souris',setSearch:v=>calls.push(['draft',v]),onApply:()=>calls.push(['apply']),onReset:()=>calls.push(['reset']),take:25,onTake:v=>calls.push(['take',v]),toggleFilters:()=>calls.push(['filters']),toggleDensity:()=>calls.push(['density']),toggleColumns:()=>calls.push(['columns']),exportFile:()=>calls.push(['excel']),exportCsv:()=>calls.push(['csv']),filterControlsId:'filters-proof',activeFilters:1,density:'compact'};
 let tree=DataTableToolbar(toolbar),input=find(tree,n=>n.type==='input'),form=find(tree,n=>n.type==='form');
 eq(form.props.role,'search');ok(form.props['aria-label']);eq(input.props.enterKeyHint,'search');
 input.props.onChange({target:{value:'clavier'}});eq(calls,[['draft','clavier']]);
 let prevented=0;form.props.onSubmit({preventDefault:()=>prevented++});eq(prevented,1);eq(calls.at(-1),['apply']);
 find(tree,n=>n.type==='select').props.onChange({target:{value:'50'}});eq(calls.at(-1),['take',50]);
 for(const [label,kind] of [['Filtrer','filters'],['Réinitialiser','reset'],['Vue aérée','density'],['Excel','excel'],['CSV','csv']]){
  const button=find(tree,n=>typeof n.type==='function'&&text(n).startsWith(label));button.props.onClick();eq(calls.at(-1),[kind]);
 }
 tree=DataTableToolbar({...toolbar,pending:true,error:'Export indisponible.'});
 eq(find(tree,n=>n.type==='input').props['aria-describedby'],'list-proof-pending');
 eq(find(tree,n=>n.props?.id==='list-proof-pending').props.role,'status');
 eq(text(find(tree,n=>n.props?.role==='alert')),'Export indisponible.');
 for(const label of ['Excel','CSV'])eq(find(tree,n=>typeof n.type==='function'&&text(n)===label).props.disabled,true);
 tree=DataTableToolbar({...toolbar,loading:true});const count=calls.length;find(tree,n=>n.type==='form').props.onSubmit({preventDefault:()=>prevented++});eq(calls.length,count);
 globalThis.__listUser={permissions:{canExportData:false}};tree=DataTableToolbar(toolbar);
 for(const label of ['Excel','CSV'])eq(find(tree,n=>typeof n.type==='function'&&text(n)===label).props.disabled,true);
 tree=DataTableToolbar({...toolbar,search:'',activeFilters:0});eq(find(tree,n=>typeof n.type==='function'&&text(n)==='Réinitialiser').props.disabled,true);
 tree=DataTableToolbar({...toolbar,showFilters:false,showSettings:false,exportFile:null,exportCsv:null});eq(nodes(tree).filter(n=>typeof n.type==='function'&&['Filtrer','Colonnes','Excel','CSV'].includes(text(n))).length,0);

 const selected=[],consulted=[],changes=[],rows=[{id:17,name:'Souris',quantity:3},{id:42,name:'Clavier',quantity:5}],columns=[{key:'name',label:'Article'},{key:'quantity',label:'Quantité',align:'right'},{key:'actions',label:'Actions',sortable:false}],props={rows,columns,getRowId:r=>r.id,showControls:false,onRowSelect:r=>selected.push(r.id),onRowConsult:(r,key)=>consulted.push([r.id,key]),consultColumns:['quantity'],tableLabel:'Articles du bon'};
 const h=new Hooks();tree=h.render(SimpleTable,props);
 eq(find(tree,n=>n.props?.role==='region').props['aria-label'],'Articles du bon · tableau défilant');eq(find(tree,n=>n.type==='table').props['aria-label'],'Articles du bon');
 ok(nodes(tree).filter(n=>n.type==='th').every(n=>n.props.scope==='col'));
 eq(find(tree,n=>n.type==='th'&&text(n)==='Actions').props['aria-sort'],undefined);
 const dataRows=nodes(tree).filter(n=>n.type==='tr'&&n.props.onClick);eq(dataRows.map(n=>n.key),['17','42']);eq(dataRows.map(n=>n.props.tabIndex),[0,0]);
 dataRows[1].props.onClick();eq(selected,[42]);const target={};
 dataRows[0].props.onKeyDown({key:'Enter',target,currentTarget:target,preventDefault:()=>prevented++});eq(selected,[42,17]);
 dataRows[1].props.onKeyDown({key:' ',target,currentTarget:target,preventDefault:()=>prevented++});eq(selected,[42,17,42]);
 const before=selected.length;dataRows[0].props.onKeyDown({key:' ',target:{tagName:'INPUT'},currentTarget:target,preventDefault:()=>{throw Error('Clavier enfant intercepté');}});dataRows[0].props.onKeyDown({key:'ArrowDown',target,currentTarget:target});eq(selected.length,before);
 const cellLinks=nodes(tree).filter(n=>n.props?.className==='erp-object-link');cellLinks[1].props.onClick({stopPropagation:()=>prevented++});eq(consulted,[[42,'quantity']]);eq(text(cellLinks[1]),'5');
 const checkboxes=nodes(tree).filter(n=>n.type==='input'&&n.props.type==='checkbox');eq(checkboxes[0].props['aria-label'],'Sélectionner toutes les lignes de cette page');checkboxes[2].props.onChange();tree=h.render(SimpleTable,props);eq(nodes(tree).filter(n=>n.type==='input'&&n.props.type==='checkbox').map(n=>n.props.checked),[false,false,true]);
 tree=h.render(SimpleTable,{...props,loading:true});eq(find(tree,n=>n.props?.role==='region').props.inert,true);eq(nodes(tree).filter(n=>n.type==='tr'&&n.props.onClick).length,2);find(tree,n=>n.type==='tr'&&n.props.onClick).props.onKeyDown({key:'Enter',target,currentTarget:target,preventDefault:()=>{throw Error('Activation pendant chargement');}});eq(selected.length,before);
 const server=new Hooks(),serverProps={...props,onServerChange:v=>changes.push(v),serverMeta:{filteredCount:65},serverState:{take:25,skip:25,sortBy:'name',sortDir:'asc'}};
 tree=server.render(SimpleTable,serverProps);eq(find(tree,n=>n.type==='th'&&text(n)==='Article').props['aria-sort'],'ascending');find(tree,n=>n.props?.title==='Trier par Article').props.onClick();eq(changes.at(-1),{sortBy:'name',sortDir:'desc',skip:0});
 find(tree,n=>n.type===TablePagination).props.onPage(3);eq(changes.at(-1),{skip:50});
 tree=new Hooks().render(SimpleTable,{...props,rows:[]});eq(find(tree,n=>n.type===ListState).props.loading,false);ok(find(tree,n=>n.type===ListState).props.description);
 tree=new Hooks().render(SimpleTable,{...props,rows:[],loading:true});eq(find(tree,n=>n.type===ListState).props.title,'Chargement des résultats…');eq(find(tree,n=>n.type===ListState).props.description,undefined);

 tree=PublicTable({columns:[{key:'name',label:'Nom'}],rows:[{id:0,name:'Zéro'}],tableLabel:'Offres'});eq(find(tree,n=>n.type==='tr'&&n.key!==undefined).key,0);eq(find(tree,n=>n.type==='th').props.scope,'col');ok(find(tree,n=>n.props?.role==='region').props.tabIndex===0);
 tree=PublicTable({columns,rows:[]});ok(find(tree,n=>n.type===ListState));
 const pages=[];tree=expand(TablePagination({total:0,take:25,page:1,onPage:v=>pages.push(v)}));eq(nodes(tree).filter(n=>n.type==='nav').length,0);eq(text(find(tree,n=>n.props?.role==='status')),'Aucun résultat');
 tree=expand(TablePagination({total:4,take:25,page:1,onPage:v=>pages.push(v)}));eq(nodes(tree).filter(n=>n.type==='button').length,0);ok(text(tree).includes('Tous les résultats sont affichés'));
 tree=expand(TablePagination({total:65,take:25,page:2,onPage:v=>pages.push(v)}));find(tree,n=>n.props?.['aria-label']==='Précédent').props.onClick();find(tree,n=>n.props?.['aria-label']==='Suivant').props.onClick();eq(pages,[1,3]);eq(find(tree,n=>n.props?.['aria-current']==='page').props.children,2);ok(find(tree,n=>n.props?.['aria-label']==='Page 2 sur 3'));
 tree=expand(TablePagination({total:65,take:25,page:1,onPage:v=>pages.push(v)}));eq(find(tree,n=>n.props?.['aria-label']==='Précédent').props.disabled,true);
 tree=expand(TablePagination({total:65,take:25,page:3,onPage:v=>pages.push(v)}));eq(find(tree,n=>n.props?.['aria-label']==='Suivant').props.disabled,true);
 tree=expand(TablePagination({total:65,take:25,page:2,loading:true,onPage:v=>pages.push(v)}));ok(nodes(tree).filter(n=>n.type==='button').every(n=>n.props.disabled));
 tree=ListState({title:'Aucun professionnel',description:'Essayez un autre domaine.',action:'Réinitialiser'});eq(text(tree),'Aucun professionnelEssayez un autre domaine.Réinitialiser');eq(tree.props.role,undefined);tree=ListState({loading:true});ok(tree.props.className.includes('is-loading'));eq(nodes(tree).filter(n=>n.type==='button').length,0);
 const report={success:true,checks,coverage:['Vrais composants communs et handlers React','Recherche explicite et export protégé pendant filtre non appliqué/chargement ou permission absente','Sélection et consultation avec identifiants stables au clic et au clavier','Tri et pagination serveur, chargement conservant les lignes','États vide/chargement et en-têtes accessibles','Pagination aux limites et clavier de champs imbriqués préservé'],limits:['Arbres React et état simulés, pas de recette visuelle navigateur','Aucun appel applicatif ni mutation de données']};
 fs.mkdirSync(path.join(root,'.runtime'),{recursive:true});fs.writeFileSync(path.join(root,'.runtime/shared-list-ux-tests.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));
})().catch(error=>{console.error(error);process.exit(1);});
