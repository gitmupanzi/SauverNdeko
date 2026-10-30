// Hooks du vrai SimpleTable, éléments DOM simulés ; aucun navigateur ni appel applicatif.
const fs=require('node:fs'),path=require('node:path'),Module=require('node:module'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../..'),front=path.join(root,'frontend'),esbuild=require(path.join(front,'node_modules/esbuild'));
let checks=0;
function eq(actual,expected){assert.deepEqual(actual,expected);checks++;}
class Hooks{
 constructor(){this.slots=[];this.cursor=0;this.layout=[];}
 ref(value){const i=this.cursor++;return this.slots[i]||(this.slots[i]={current:value});}
 state(value){const i=this.cursor++;if(!this.slots[i])this.slots[i]={value:typeof value==='function'?value():value};return[this.slots[i].value,next=>{this.slots[i].value=typeof next==='function'?next(this.slots[i].value):next;}];}
 effect(fn,deps=[],layout=false){const i=this.cursor++,old=this.slots[i];if(!old||deps.some((value,j)=>!Object.is(value,old.deps[j])))this.layout.push(()=>{old?.clean?.();this.slots[i]={deps,clean:layout?fn():undefined};});}
 render(component,props){this.cursor=0;globalThis.__tableHooks=this;return component(props);}
 flush(){for(const effect of this.layout.splice(0))effect();}
 unmount(){for(const slot of this.slots)slot?.clean?.();}
}
function nodes(node,out=[]){if(!node||typeof node!=='object')return out;if(Array.isArray(node)){node.forEach(item=>nodes(item,out));return out;}out.push(node);nodes(node.props?.children,out);return out;}
(async()=>{
 const result=await esbuild.build({stdin:{contents:"export {SimpleTable} from './src/pages/logistique/logistiqueShared';",resolveDir:front},bundle:true,write:false,platform:'node',format:'cjs',jsx:'automatic',plugins:[{name:'test-doubles',setup(build){
  build.onResolve({filter:/^react$/},()=>({path:'react',namespace:'fixture'}));
  build.onResolve({filter:/^react\/jsx-runtime$/},()=>({path:'jsx',namespace:'fixture'}));
  build.onResolve({filter:/(CategoricalSelect|TablePagination|ColumnPicker|TableSettings|AppIcon|ActionButton)$/},()=>({path:'component',namespace:'fixture'}));
  build.onLoad({filter:/.*/,namespace:'fixture'},args=>({loader:'js',contents:args.path==='react'?`export const useState=v=>globalThis.__tableHooks.state(v),useRef=v=>globalThis.__tableHooks.ref(v),useMemo=f=>f(),useEffect=(f,d)=>globalThis.__tableHooks.effect(f,d),useLayoutEffect=(f,d)=>globalThis.__tableHooks.effect(f,d,true);`:args.path==='jsx'?`export const jsx=(type,props,key)=>({type,props,key}),jsxs=jsx,Fragment='fragment';`:`export default function Component(){return null;}`}));
  build.onLoad({filter:/\.css$/},()=>({contents:'',loader:'js'}));
 }}]});
 const loaded=new Module(path.join(front,'table-layout-proof.cjs'));loaded.filename=path.join(front,'table-layout-proof.cjs');loaded.paths=Module._nodeModulePaths(front);loaded._compile(result.outputFiles[0].text,loaded.filename);
 const {SimpleTable}=loaded.exports,events=new Map(),observers=[];
 globalThis.window={addEventListener:(name,fn)=>events.set(name,fn),removeEventListener:(name,fn)=>{if(events.get(name)===fn)events.delete(name);},getComputedStyle:()=>({maxHeight:'500px'})};
 globalThis.ResizeObserver=class{constructor(callback){this.callback=callback;observers.push(this);}observe(element){this.element=element;}disconnect(){this.disconnected=true;}};
 const props={columns:[{key:'name',label:'Article',filterType:'text'}],rows:[{id:1,name:'Premier'}],getRowId:row=>row.id,showControls:false,filtersVisible:true};
 let headingHeight=46;const variables=new Map(),wrap={getBoundingClientRect:()=>({height:200}),style:{setProperty:(name,value)=>variables.set(name,value),removeProperty:name=>variables.delete(name)}},heading={getBoundingClientRect:()=>({height:headingHeight})};
 const h=new Hooks();let tree=h.render(SimpleTable,props);
 const headingNode=nodes(tree).find(node=>node.type==='tr'&&node.props.ref),wrapNode=nodes(tree).find(node=>node.props?.className==='public-table-wrap logistics-table-wrap admin-table-wrap');
 assert(headingNode&&wrapNode);checks++;headingNode.props.ref.current=heading;wrapNode.props.ref.current=wrap;h.flush();
 eq(variables.get('--erp-table-heading-height'),'46px');eq(observers[0].element,heading);
 headingHeight=72;observers[0].callback();eq(variables.get('--erp-table-heading-height'),'72px');
 headingHeight=60;events.get('resize')();eq(variables.get('--erp-table-heading-height'),'60px');
 tree=h.render(SimpleTable,{...props,filtersVisible:false});h.flush();eq(variables.has('--erp-table-heading-height'),false);eq(observers[0].disconnected,true);eq(events.has('resize'),false);
 headingHeight=52;tree=h.render(SimpleTable,props);h.flush();eq(variables.get('--erp-table-heading-height'),'52px');h.unmount();eq(observers[1].disconnected,true);eq(events.has('resize'),false);eq(variables.has('--erp-table-heading-height'),false);
 delete globalThis.ResizeObserver;const fallback=new Hooks();tree=fallback.render(SimpleTable,props);nodes(tree).find(node=>node.type==='tr'&&node.props.ref).props.ref.current=heading;nodes(tree).find(node=>node.props?.className==='public-table-wrap logistics-table-wrap admin-table-wrap').props.ref.current=wrap;fallback.flush();headingHeight=68;events.get('resize')();eq(variables.get('--erp-table-heading-height'),'68px');fallback.unmount();eq(events.has('resize'),false);
 const report={success:true,checks,coverage:['Actual SimpleTable layout effects','Heading measured initially and after wrapped-label resize','Column filters toggle without stale observer','Observer and window-listener cleanup','Resize fallback without ResizeObserver'],limits:['Fake DOM dimensions, no browser scrolling/layout screenshot','No application data or requests']};fs.writeFileSync(path.join(root,'.runtime/table-layout-tests.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));
})().catch(error=>{console.error(error);process.exit(1);});
