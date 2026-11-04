// Rendu réel et événements du filtre partagé, sans navigateur ni requête applicative.
const path=require('node:path'),Module=require('node:module'),assert=require('node:assert/strict');
const front=path.resolve(__dirname,'../..'),esbuild=require(path.join(front,'node_modules/esbuild'));
let checks=0;const eq=(a,b)=>{assert.deepEqual(a,b);checks++;},ok=value=>{assert(value);checks++;};
(async()=>{
 const built=await esbuild.build({stdin:{contents:"export {default as Criteria} from './src/components/AppliedCriteria';export {createElement} from 'react';export {renderToStaticMarkup} from 'react-dom/server';",resolveDir:front,loader:'jsx'},bundle:true,platform:'node',format:'cjs',jsx:'automatic',external:['react','react/jsx-runtime','react-dom/server'],loader:{'.css':'empty'},write:false,logLevel:'error'});
 const compiled=new Module(path.join(front,'criteria-proof.cjs'));compiled.filename=path.join(front,'criteria-proof.cjs');compiled.paths=Module._nodeModulePaths(front);compiled._compile(built.outputFiles[0].text,compiled.filename);const {Criteria,createElement,renderToStaticMarkup}=compiled.exports;
 eq(Criteria({}),null);eq(Criteria({items:[null,{key:'q',value:''}]}),null);
 const items=[{key:'sector',label:'Secteur',value:'Santé'},{key:'count',label:'Nombre',value:0}],removed=[];const tree=Criteria({items,onRemove:key=>removed.push(key)}),buttons=tree.props.children;
 eq(buttons.length,2);const html=renderToStaticMarkup(createElement(Criteria,{items,onRemove(){}}));ok(html.includes('role="group"'));ok(html.includes('aria-label="Critères appliqués"'));ok(html.includes('aria-label="Retirer le filtre Secteur : Santé"'));ok(html.includes('type="button"'));ok(html.includes('<strong>0</strong>'));
 let focused=0,focusOptions;const search={focus:options=>{focused++;focusOptions=options;}},target={ownerDocument:{},closest:selector=>{eq(selector,'.erp-register');return{querySelector:selector=>{eq(selector,'.erp-table-search input[type="search"]');return search;}}}};target.ownerDocument.activeElement=target;
 buttons[0].props.onClick({detail:0,currentTarget:target});eq(removed,['sector']);eq(focused,1);eq(focusOptions,{preventScroll:true});
 buttons[1].props.onClick({detail:1,currentTarget:target});eq(removed,['sector','count']);eq(focused,1);
 target.ownerDocument.activeElement=null;buttons[0].props.onClick({detail:0,currentTarget:target});eq(focused,1);
 const disabled=renderToStaticMarkup(createElement(Criteria,{items,disabled:true}));eq((disabled.match(/disabled=""/g)||[]).length,2);
 console.log(JSON.stringify({success:true,checks,coverage:['Critères appliqués seulement, zéro et libellés accessibles','Suppression ciblée et bouton sans soumission de formulaire','Retour recherche sans défilement après activation clavier ; pointeur inchangé','Désactivation pendant lecture'],limits:['SSR et handlers React réels, focus avec objet DOM contrôlé ; aucun navigateur']}));
})().catch(error=>{console.error(error);process.exitCode=1;});
