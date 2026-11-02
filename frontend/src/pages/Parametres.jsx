import {useEffect,useRef,useState} from "react";
import {useSearchParams} from "react-router-dom";
import {useAuth} from "../contexts/AuthContext";
import {useEntityScope} from "../contexts/EntityScopeContext";
import {moduleRights,mayOpen} from "../services/moduleAccess";
import {requestJson} from "../services/api";
import ModuleSidebar from "../components/ModuleSidebar";
import ModuleHeader from "../components/ModuleHeader";
import AppIcon from "../components/AppIcon";
import ActionButton from "../components/ActionButton";
import EntityProfileEditor from "../components/EntityProfileEditor";
import EntityProfileFields from "../components/EntityProfileFields";
import {entityProfileValues} from "../utils/entityProfile";
import "./logistique/LogistiqueModern.css";
import "./admin/AdminPortal.css";
import "./Parametres.css";

export const SETTINGS_TABS=[{key:"entreprise",label:"Entreprise",icon:"building",editor:"identity"},{key:"fiscalite",label:"Fiscalité",icon:"percent",editor:"fiscalite"},{key:"documents",label:"Documents",icon:"document",editor:"documents"},{key:"localisation",label:"Localisation",icon:"globe",editor:"localisation"}];
export const settingsTab=value=>SETTINGS_TABS.find(item=>item.key===value)||SETTINGS_TABS[0];
function Details({items}){return <dl className="settings-details">{items.map(([name,value])=><div key={name}><dt>{name}</dt><dd>{value==null||value===""?"Non renseigné":value}</dd></div>)}</dl>;}

export default function Parametres(){
  const {user}=useAuth(),scope=useEntityScope(),[params,setParams]=useSearchParams(),[revision,setRevision]=useState(0),[state,setState]=useState({key:"",data:null,error:"",loading:true}),[editor,setEditor]=useState(null),[feedback,setFeedback]=useState("");
  const [collapsed,setCollapsed]=useState(()=>{try{return localStorage.getItem("sauverndeko.settings.sidebar-collapsed")==="true";}catch{return false;}}),anchor=useRef(null),tab=settingsTab(params.get("onglet")),key=scope.scopeKey+":"+revision,current=state.key===key?state:{data:null,error:"",loading:true},profile=current.data?.profile,canManage=current.data?.canManage===true&&Boolean(scope.entityId);
  useEffect(()=>{try{localStorage.setItem("sauverndeko.settings.sidebar-collapsed",String(collapsed));}catch{}},[collapsed]);
  useEffect(()=>{setFeedback("");},[scope.scopeKey]);
  useEffect(()=>{const controller=new AbortController();setState({key,data:null,error:"",loading:true});setEditor(null);requestJson("/api/parametres/contexte",{requiresAuth:true,signal:controller.signal}).then(response=>{if(controller.signal.aborted)return;const data=response?.success?response.data:null,mismatch=data?.profile&&(!scope.entityId||String(data.profile.IdEntite)!==String(scope.entityId));setState({key,data:mismatch?null:data,error:mismatch?"L’entreprise reçue ne correspond pas au contexte choisi. Rechargez les paramètres.":response?.success?"":response?.message||"Les paramètres ne sont pas disponibles.",loading:false});});return()=>controller.abort();},[key]);
  function openEditor(){if(!canManage||!profile)return;setEditor({scope:scope.scopeKey,tab:tab.editor});}
  function closeEditor(){setEditor(null);requestAnimationFrame(()=>anchor.current?.focus());}
  function saved(){setEditor(null);setRevision(value=>value+1);setFeedback("Paramètres de l’entreprise enregistrés.");requestAnimationFrame(()=>anchor.current?.focus());}
  const values=profile?entityProfileValues(profile):null;
  return <div className={"logistics-modern logistics-app admin-portal settings-module"+(collapsed?" is-menu-collapsed":"")}>
    <ModuleSidebar title="Paramètres" collapsed={collapsed} onToggle={()=>setCollapsed(value=>!value)} storageKey="sauverndeko.settings.navigation" activeKey={tab.key} onNavigate={value=>setParams({onglet:value})} groups={[{key:"entreprise",label:"Entreprise",items:SETTINGS_TABS}]} footerItems={[{key:"logistique",label:"Logistique",icon:"box",to:"/logistique",hidden:!moduleRights(user,"logistique").canRead},{key:"referentiels",label:"Référentiels",icon:"tag",to:"/referentiels",hidden:!mayOpen(user,"/referentiels")},{key:"admin",label:"Administration",icon:"shield",to:"/admin",hidden:!moduleRights(user,"administration").canRead},{key:"applications",label:"Applications",icon:"apps",to:"/"}]}/>
    <ModuleHeader title="Paramètres"/>
    <main className="admin-main settings-main">
      <header className="settings-heading"><div><h1>{tab.label}</h1><p>{profile?.NomEntite||"Les paramètres de votre entreprise."}</p></div><ActionButton ref={anchor} icon="edit" variant="primary" disabled={!canManage||!profile||current.loading} onClick={openEditor}>Modifier</ActionButton></header>
      {feedback?<p className="admin-feedback" role="status"><AppIcon name="check-circle"/>{feedback}</p>:null}
      {current.error?<div className="admin-error" role="alert"><span>{current.error}</span><ActionButton icon="refresh" onClick={()=>setRevision(value=>value+1)}>Réessayer</ActionButton></div>:null}
      {current.loading?<div className="settings-placeholder" role="status">Chargement des paramètres…</div>:!profile&&!current.error?<section className="settings-placeholder"><AppIcon name="building" size={28}/><h2>Choisissez une entreprise</h2><p>Utilisez le sélecteur dans l’en-tête pour consulter ses paramètres.</p></section>:null}
      {profile?<div className="settings-content">
        {tab.key==="entreprise"?<><section className="record-editor-section"><h2><AppIcon name="building"/>Coordonnées</h2><Details items={[["Nom de l’entreprise",profile.NomEntite],["Adresse e-mail",profile.EmailEntite],["Téléphone",profile.PhoneEntite],["Téléphone secondaire",profile.PhoneSecondaireEntite],["Site web",profile.SiteWebEntite],["Adresse",profile.AdresseEntite]]}/></section><section className="record-editor-section"><div className="entity-document-section-head"><h2><AppIcon name="list"/>Identifiants légaux</h2>{canManage?<ActionButton icon="edit" onClick={()=>setEditor({scope:scope.scopeKey,tab:"legal"})}>Modifier</ActionButton>:null}</div>{profile.IdentifiantsLegauxEntite?.length?<Details items={profile.IdentifiantsLegauxEntite.map(item=>[item.libelle,item.valeur])}/>:<p className="record-editor-note">Aucun identifiant renseigné.</p>}</section></>:<EntityProfileFields active={tab.editor} prefix="settings-profile-" values={values} record={profile} readOnly disabled={false} change={()=>{}} logo={{file:null,remove:false}} onLogoChange={()=>{}} contextKey={scope.scopeKey}/>}
      </div>:null}
    </main>
    {editor?.scope===scope.scopeKey&&canManage?<EntityProfileEditor context="settings" mode="edit" initialTab={editor.tab} onClose={closeEditor} onSaved={saved}/>:null}
  </div>;
}
