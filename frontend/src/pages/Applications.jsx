import {useEffect,useState} from "react";
import {Link} from "react-router-dom";
import {useAuth} from "../contexts/AuthContext";
import {requestJson} from "../services/api";
import {accessSignature} from "../services/moduleAccess";
import ModuleHeader from "../components/ModuleHeader";
import AppIcon from "../components/AppIcon";
import ActionButton from "../components/ActionButton";
import "./WorkspaceHome.css";
import "./Applications.css";

const normalizeSearch = value => String(value || "").trim().normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLocaleLowerCase("fr");

export default function Applications() {
  const {user}=useAuth();
  const platform=Boolean(user?.moduleAccess?.platformAdmin);
  const [state,setState]=useState({loading:true,modules:[],error:""});
  const [search,setSearch]=useState("");
  const [revision,setRevision]=useState(0);
  useEffect(()=>{
    let active=true;setState({loading:true,modules:[],error:""});
    requestJson("/api/workspace/catalogue",{requiresAuth:true}).then(payload=>{
      if(active)setState({loading:false,modules:payload?.success ? payload.data.modules : [],error:payload?.success ? "" : payload?.message || "Le catalogue est indisponible."});
    });
    return()=>{active=false;};
  },[revision,user?.IdUser,user?.IdEntiteFk,accessSignature(user)]);
  const query=normalizeSearch(search);
  const visible=state.modules.filter(item=>normalizeSearch(item.label+" "+item.description).includes(query));
  function status(item) {
    if(platform)return "Accès plateforme";
    if(item.canRead)return item.base?"Socle inclus":"Activé";
    if(item.available)return "Accès selon le rôle";
    return item.reason==="LICENCE_INACTIVE"?"Licence inactive":"Non activé";
  }
  return <div className="applications-page"><ModuleHeader title="Applications"/>
    <main className="applications-main">
      <div className="applications-heading"><div><Link className="application-back" to="/"><AppIcon name="chevron-left"/>Mes applications</Link><h1>Découvrir les applications</h1><p>{platform ? "Administration de la plateforme" : (user?.entite?.NomEntite || "SauverNdeko") + " · Une offre adaptée à votre organisation."}</p></div>{user?.permissions?.canAccessAdmin ? <Link className="ui-action is-secondary" to="/abonnements"><AppIcon name="settings"/>Licences et applications</Link>:null}</div>
      <label className="applications-search"><AppIcon name="search"/><input type="search" aria-label="Rechercher une application" placeholder="Rechercher une application…" value={search} onChange={e=>setSearch(e.target.value)}/></label>
      {state.loading ? <p role="status">Chargement du catalogue…</p> : state.error ? <div className="application-message is-error" role="alert">{state.error}<ActionButton icon="refresh" onClick={()=>setRevision(x=>x+1)}>Réessayer</ActionButton></div> :
      <div className="application-catalogue">{visible.map(item=><article className={"application-card workspace-app is-"+item.tone} key={item.key}>
        <div className="application-card-top"><span className="workspace-app-icon"><i className={"bi bi-"+item.icon} aria-hidden="true"/></span><span className={"application-badge "+(item.canRead?"is-enabled":"")}>{status(item)}</span></div>
        <h2>{item.label}</h2><p>{item.description}</p>
        <div className="application-card-bottom">{item.canRead ? <Link to={item.path} className="application-open" aria-label={"Ouvrir " + item.label}>Ouvrir<AppIcon name="arrow-up-right"/></Link>:<span>{item.available ? "Contactez votre administrateur." : "À activer pour votre organisation."}</span>}</div>
      </article>)}</div>}
      {!state.loading&&!state.error&&!visible.length?<p className="application-message">Aucune application ne correspond à votre recherche.</p>:null}
      {!platform ? <p className="application-footnote">La licence est attribuée à l’organisation. Les accès dépendent aussi des droits de votre rôle.</p> : null}
    </main>
  </div>;
}
