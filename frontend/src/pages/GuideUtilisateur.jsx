import {useEffect,useId,useRef,useState} from "react";
import {Link,useSearchParams} from "react-router-dom";
import {useAuth} from "../contexts/AuthContext";
import {useEntityScope} from "../contexts/EntityScopeContext";
import {requestJson} from "../services/api";
import {accessSignature} from "../services/moduleAccess";
import {guideArticleValid,guideContextValid,guideLocation,searchGuideArticles} from "../services/userGuide";
import ModuleSidebar from "../components/ModuleSidebar";
import ModuleHeader from "../components/ModuleHeader";
import ActionButton from "../components/ActionButton";
import AppIcon from "../components/AppIcon";
import "./logistique/LogistiqueModern.css";
import "./admin/AdminPortal.css";
import "./GuideUtilisateur.css";

function GuideIcon({name,size=20}){return name?.startsWith("bi-")?<i className={"bi "+name} aria-hidden="true"/>:<AppIcon name={name||"book"} size={size}/>;}
function ArticleCard({module,article,showModule=false,onOpen}){
  return <Link className="guide-article-card" to={guideLocation(module.key,article.id)} onClick={onOpen}>{showModule?<small>{module.label}</small>:null}<span className="guide-article-title"><strong>{article.title}</strong><AppIcon name="chevron-right"/></span><p>{article.summary}</p></Link>;
}
function GuideError({message,onRetry}){return <div className="guide-message is-error" role="alert"><AppIcon name="alert" size={24}/><div><h2>Le guide n’est pas disponible</h2><p>{message}</p></div>{onRetry?<ActionButton icon="refresh" onClick={onRetry}>Réessayer</ActionButton>:null}<Link to="/guide" className="ui-action is-secondary">Tous les guides</Link></div>;}

export default function GuideUtilisateur(){
  const {user}=useAuth(),scope=useEntityScope(),[params]=useSearchParams(),[revision,setRevision]=useState(0),[query,setQuery]=useState(""),[contextState,setContextState]=useState({key:"",data:null,error:"",loading:true}),[articleState,setArticleState]=useState({key:"",data:null,error:"",loading:true});
  const [collapsed,setCollapsed]=useState(()=>{try{return localStorage.getItem("sauverndeko.guide.sidebar-collapsed")==="true";}catch{return false;}}),heading=useRef(null),searchingRef=useRef(false),searchId=useId();
  const moduleKey=params.get("module")||"",articleId=params.get("article")||"",scopeKey=scope.scopeKey+":"+accessSignature(user),contextKey=scopeKey+":"+revision,current=contextState.key===contextKey?contextState:{data:null,error:"",loading:true},modules=current.data?.modules||[],selected=modules.find(module=>module.key===moduleKey),articleMeta=selected?.articles.find(article=>article.id===articleId),articleKey=[contextKey,moduleKey,articleId,current.data?.revision||""].join(":"),detail=articleState.key===articleKey?articleState:{data:null,error:"",loading:true};
  const invalidSelection=!current.loading&&!current.error&&((moduleKey&&!selected)||(articleId&&!moduleKey)||(articleId&&selected&&!articleMeta)),searching=Boolean(query.trim()),results=searching?searchGuideArticles(modules,query):[];
  searchingRef.current=searching;
  useEffect(()=>{try{localStorage.setItem("sauverndeko.guide.sidebar-collapsed",String(collapsed));}catch{}},[collapsed]);
  useEffect(()=>{setQuery("");},[scopeKey]);
  useEffect(()=>{
    const controller=new AbortController();setContextState({key:contextKey,data:null,error:"",loading:true});
    requestJson("/api/guide/contexte",{requiresAuth:true,signal:controller.signal}).then(response=>{
      if(controller.signal.aborted)return;const data=response?.success?response.data:null;
      const mismatch=data&&String(data.entityId||"")!==String(scope.entityId||"");
      setContextState({key:contextKey,data:data&&guideContextValid(data)&&!mismatch?data:null,error:response?.success?(!guideContextValid(data)||mismatch?"La liste des guides reçue ne correspond pas à votre espace. Rechargez la page.":""):response?.message||"Impossible de charger les guides.",loading:false});
    });return()=>controller.abort();
  },[contextKey]);
  useEffect(()=>{
    if(!selected||!articleMeta||current.loading||current.error)return;
    const controller=new AbortController();setArticleState({key:articleKey,data:null,error:"",loading:true});
    requestJson("/api/guide/articles/"+encodeURIComponent(moduleKey)+"/"+encodeURIComponent(articleId),{requiresAuth:true,signal:controller.signal}).then(response=>{
      if(controller.signal.aborted)return;const valid=response?.success&&guideArticleValid(response.data,selected,articleId,current.data.revision);
      setArticleState({key:articleKey,data:valid?response.data:null,error:valid?"":response?.success?"Le guide a été mis à jour. Rechargez son contenu.":response?.message||"Impossible de charger ce tutoriel.",loading:false});
      if(valid&&!searchingRef.current)requestAnimationFrame(()=>{heading.current?.focus({preventScroll:true});heading.current?.scrollIntoView({block:"start",behavior:"instant"});});
    });return()=>controller.abort();
  },[articleKey,Boolean(selected),Boolean(articleMeta)]);
  const reload=()=>setRevision(value=>value+1),article=detail.data?.article;
  return <div className={"logistics-modern logistics-app admin-portal guide-module"+(collapsed?" is-menu-collapsed":"")}>
    <ModuleSidebar title="Guide utilisateur" collapsed={collapsed} onToggle={()=>setCollapsed(value=>!value)} storageKey="sauverndeko.guide.navigation" activeKey={moduleKey||"accueil"} groups={[{key:"accueil",label:"Prise en main",items:[{key:"accueil",label:"Tous les guides",icon:"book",to:"/guide"}]},{key:"modules",label:"Par application",items:modules.map(module=>({key:module.key,label:module.label,icon:module.icon,to:guideLocation(module.key)}))}]} footerItems={[{key:"applications",label:"Applications",icon:"apps",to:"/espace"}]}/>
    <ModuleHeader title="Guide utilisateur"/>
    <main className="admin-main guide-main" id="guide-contenu">
      <header className="guide-heading"><div><p className="guide-eyebrow">PRISE EN MAIN</p><h1 ref={heading} tabIndex={-1}>{searching?"Rechercher dans les guides":articleId&&articleMeta?articleMeta.title:selected?.label||"Guide utilisateur"}</h1><p>{searching?"Retrouvez un parcours dans vos applications.":selected?.description||"Des étapes simples et des exemples pour utiliser vos applications."}</p></div>{selected&&!searching?<Link className="ui-action is-secondary" to={selected.path}><AppIcon name="arrow-up-right"/>Ouvrir {selected.label}</Link>:null}</header>
      <form className="guide-search" role="search" onSubmit={event=>event.preventDefault()}><label className="visually-hidden" htmlFor={searchId}>Rechercher dans les guides autorisés</label><AppIcon name="search" size={20}/><input id={searchId} type="search" placeholder="Rechercher : créer un article, facture, licence…" value={query} onChange={event=>setQuery(event.target.value)} disabled={current.loading||Boolean(current.error)}/>{query?<button type="button" aria-label="Effacer la recherche" onClick={()=>setQuery("")}><AppIcon name="close"/></button>:null}</form>
      {current.loading?<div className="guide-message" role="status"><AppIcon name="book" size={28}/><p>Chargement des guides…</p></div>:current.error?<GuideError message={current.error} onRetry={reload}/>:searching?<section aria-labelledby="guide-resultats"><div className="guide-section-heading"><h2 id="guide-resultats">{results.length} tutoriel{results.length===1?"":"s"}</h2><ActionButton icon="reset" onClick={()=>setQuery("")}>Effacer</ActionButton></div>{results.length?<div className="guide-article-grid">{results.map(result=><ArticleCard key={result.module.key+":"+result.article.id} {...result} showModule onOpen={()=>setQuery("")}/>)}</div>:<div className="guide-message"><AppIcon name="search" size={26}/><h2>Aucun tutoriel trouvé</h2><p>Essayez un autre mot, comme « stock » ou « utilisateur ».</p></div>}</section>:invalidSelection?<GuideError message="Ce tutoriel n’existe pas ou n’est pas accessible avec vos applications actuelles."/>:articleId?<>
        <nav className="guide-breadcrumb" aria-label="Fil d’Ariane"><Link to="/guide">Tous les guides</Link><AppIcon name="chevron-right" size={13}/><Link to={guideLocation(moduleKey)}>{selected.label}</Link><AppIcon name="chevron-right" size={13}/><span aria-current="page">{articleMeta.title}</span></nav>
        {detail.loading?<div className="guide-message" role="status"><AppIcon name="book" size={28}/><p>Chargement du tutoriel…</p></div>:detail.error?<GuideError message={detail.error} onRetry={reload}/>:article?<div className="guide-reading-layout"><article className="guide-lesson" aria-label={article.title}><p className="guide-lesson-intro">{article.summary}</p><ol className="guide-steps">{article.steps.map((step,index)=><li key={index} id={"guide-etape-"+index}><span className="guide-step-number" aria-hidden="true">{index+1}</span><div><h2>{step.title}</h2><p>{step.text}</p></div></li>)}</ol><section className="guide-example" aria-labelledby="guide-exemple"><span className="guide-example-icon"><AppIcon name="book" size={22}/></span><div><small>EXEMPLE CONCRET</small><h2 id="guide-exemple">{article.example.title}</h2><p>{article.example.text}</p></div></section>{article.notes.length?<section className="guide-notes"><h2><AppIcon name="help"/>À retenir</h2><ul>{article.notes.map((note,index)=><li key={index}>{note}</li>)}</ul></section>:null}{article.links.length?<nav className="guide-related" aria-label="Mettre en pratique">{article.links.map(link=><Link key={link.path+link.label} to={link.path} className="ui-action is-secondary"><AppIcon name="arrow-up-right"/>{link.label}</Link>)}</nav>:null}</article><aside className="guide-contents" aria-label="Sommaire du tutoriel"><h2>Dans ce tutoriel</h2><ol>{article.steps.map((step,index)=><li key={index}><a href={"#guide-etape-"+index}>{step.title}</a></li>)}</ol><Link to={guideLocation(moduleKey)}><AppIcon name="chevron-left"/>Tous les tutoriels {selected.label}</Link></aside></div>:null}
      </>:selected?<><nav className="guide-breadcrumb" aria-label="Fil d’Ariane"><Link to="/guide">Tous les guides</Link><AppIcon name="chevron-right" size={13}/><span aria-current="page">{selected.label}</span></nav><div className="guide-section-heading"><h2>{selected.articles.length} tutoriel{selected.articles.length===1?"":"s"}</h2></div><div className="guide-article-grid">{selected.articles.map(item=><ArticleCard key={item.id} module={selected} article={item}/>)}</div></>:<><div className="guide-section-heading"><h2>Choisissez une application</h2><span>{modules.length} guide{modules.length===1?"":"s"}</span></div>{modules.length?<div className="guide-module-grid">{modules.map(module=><Link key={module.key} className="guide-module-card" to={guideLocation(module.key)}><span className="guide-module-icon"><GuideIcon name={module.icon}/></span><h2>{module.label}</h2><p>{module.description}</p><span className="guide-module-foot">{module.articles.length} tutoriel{module.articles.length===1?"":"s"}<AppIcon name="chevron-right"/></span></Link>)}</div>:<div className="guide-message"><AppIcon name="book" size={28}/><h2>Aucun guide disponible</h2><p>Les guides apparaissent selon les applications autorisées pour votre compte.</p></div>}<p className="guide-scope-note"><AppIcon name="shield"/>Les guides disponibles suivent vos applications et vos droits d’accès.</p></>}
    </main>
  </div>;
}
