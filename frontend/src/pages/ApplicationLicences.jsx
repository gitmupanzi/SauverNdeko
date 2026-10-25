import {formatDate} from "./logistique/logistiqueShared";
import {useCallback,useEffect,useId,useRef,useState} from "react";
import {Link,useLocation,useNavigate} from "react-router-dom";
import {useAuth} from "../contexts/AuthContext";
import {requestJson} from "../services/api";
import ModuleHeader from "../components/ModuleHeader";
import ActionButton from "../components/ActionButton";
import AppIcon from "../components/AppIcon";
import DrawerDialog from "../components/DrawerDialog";
import SearchSelect from "../components/SearchSelect";
import "../components/DataTable.css";
import "./Applications.css";

const RIGHTS=[["canRead","Consulter"],["canManage","Gérer"],["canExport","Exporter"]];
const TABS=[["licences","Modules de la licence"],["roles","Droits des rôles"]];
function date(value) {return formatDate(value);}
function licenseDraft(data,id) {const licence=data?.licences?.find(x=>String(x.IdLicence)===String(id));return Object.fromEntries((data?.catalogue || []).map(m=>[m.CodeModule,Boolean(licence?.activations?.find(x=>x.CodeModule===m.CodeModule)?.Actif)]));}
function roleDraft(role,catalogue=[]) {return Object.fromEntries(catalogue.map(m=>{const stored=role?.permissions?.find(x=>x.CodeModule===m.CodeModule),base=role?.baseline?.[m.CodeModule] || {};return [m.CodeModule,Object.fromEntries(RIGHTS.map(([key],index)=>[key,Boolean(base[key]&&(!stored || (stored.Actif&&stored[["PeutConsulter","PeutGerer","PeutExporter"][index]])))]))];}));}
function preferredEntity(rows,current,account) {return String([current,account].find(id=>id!=null&&id!==""&&rows.some(row=>String(row.IdEntite)===String(id))) ?? rows[0]?.IdEntite ?? "");}
function tabForKey(current,key) {const index=TABS.findIndex(([id])=>id===current);if(key==="Home")return TABS[0][0];if(key==="End")return TABS[TABS.length-1][0];if(key==="ArrowLeft"||key==="ArrowRight")return TABS[(index+(key==="ArrowRight"?1:-1)+TABS.length)%TABS.length][0];return null;}

export default function ApplicationLicences() {
  const {user,refreshUser}=useAuth();
  const navigate=useNavigate(),location=useLocation(),fieldId=useId();
  const platform=Boolean(user?.moduleAccess?.platformAdmin);
  const [organisations,setOrganisations]=useState([]);
  const [organisationsReady,setOrganisationsReady]=useState(false),[organisationsLoading,setOrganisationsLoading]=useState(true),[configurationLoading,setConfigurationLoading]=useState(false);
  const [entity,setEntity]=useState("");
  const [tab,setTab]=useState("licences");
  const [data,setData]=useState(null),[roleData,setRoleData]=useState(null);
  const [licenceId,setLicenceId]=useState(""),[roleId,setRoleId]=useState("");
  const [draft,setDraft]=useState({}),[permissions,setPermissions]=useState({});
  const [saving,setSaving]=useState(false),[error,setError]=useState(""),[message,setMessage]=useState("");
  const [revision,setRevision]=useState(0),[pendingTransition,setPendingTransition]=useState(null);
  const generation=useRef(0),mounted=useRef(true),saveLock=useRef(false),tabs=useRef({}),selections=useRef({entity:"",licenceId:"",roleId:""});
  const resetConfiguration=useCallback(()=>{setData(null);setRoleData(null);setDraft({});setPermissions({});setLicenceId("");setRoleId("");setConfigurationLoading(false);},[]);
  const dismissTransition=useCallback(()=>setPendingTransition(null),[]);
  useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;generation.current++;};},[]);
  useEffect(()=>{
    const controller=new AbortController();let active=true;
    generation.current++;setOrganisationsReady(false);setOrganisationsLoading(true);setError("");setMessage("");resetConfiguration();
    async function loadOrganisations(){
      try {
        const result=await requestJson("/api/workspace/organisations",{requiresAuth:true,signal:controller.signal});
        if(!active)return;
        if(!result?.success||!Array.isArray(result.data)){setError(result?.message || "Les organisations sont indisponibles.");return;}
        setOrganisations(result.data);
        setEntity(current=>preferredEntity(result.data,current,user?.IdEntiteFk));
        if(!result.data.length)selections.current={entity:"",licenceId:"",roleId:""};
        setOrganisationsReady(true);
      } catch {if(active)setError("Les organisations sont indisponibles. Réessayez.");}
      finally {if(active)setOrganisationsLoading(false);}
    }
    void loadOrganisations();
    return()=>{active=false;controller.abort();};
  },[user?.IdUser,user?.IdEntiteFk,revision,resetConfiguration]);
  useEffect(()=>{
    const id=++generation.current,controller=new AbortController();let active=true;
    resetConfiguration();
    if(organisationsReady&&entity&&organisations.some(row=>String(row.IdEntite)===entity)){
      setConfigurationLoading(true);setError("");setMessage("");
      async function load(){
        try {
          const results=await Promise.allSettled(["licences","roles"].map(kind=>requestJson("/api/workspace/"+kind+"?entite="+encodeURIComponent(entity),{requiresAuth:true,signal:controller.signal})));
          if(!active||!mounted.current||generation.current!==id)return;
          const [offer,roles]=results.map(result=>result.status==="fulfilled"?result.value:null);
          if(!offer?.success||!roles?.success){setError(offer?.message || roles?.message || "La configuration est indisponible.");return;}
          if(String(offer.data?.entityId)!==entity||String(roles.data?.entityId)!==entity||!Array.isArray(offer.data?.licences)||!Array.isArray(offer.data?.catalogue)||!Array.isArray(roles.data?.roles)||!Array.isArray(roles.data?.catalogue)){setError("Cette configuration n’est plus à jour. Rechargez-la.");return;}
          const previous=selections.current.entity===entity?selections.current:{};
          const licence=String(offer.data.licences.find(x=>String(x.IdLicence)===previous.licenceId)?.IdLicence || offer.data.licences.find(x=>x.statut_licence==="Active")?.IdLicence || offer.data.licences[0]?.IdLicence || "");
          const selectedRole=roles.data.roles.find(x=>String(x.IdRoleFk)===previous.roleId) || roles.data.roles[0];
          const role=String(selectedRole?.IdRoleFk || "");
          selections.current={entity,licenceId:licence,roleId:role};
          setData(offer.data);setRoleData(roles.data);setLicenceId(licence);setDraft(licenseDraft(offer.data,licence));setRoleId(role);setPermissions(roleDraft(selectedRole,roles.data.catalogue));
        } catch {if(active&&mounted.current&&generation.current===id)setError("La configuration est indisponible. Réessayez.");}
        finally {if(active&&mounted.current&&generation.current===id)setConfigurationLoading(false);}
      }
      void load();
    }
    return()=>{active=false;controller.abort();if(generation.current===id)generation.current++;};
  },[entity,organisationsReady,organisations,resetConfiguration]);
  const loading=organisationsLoading||configurationLoading;
  const scoped=Boolean(organisationsReady&&entity&&String(data?.entityId)===entity&&String(roleData?.entityId)===entity);
  const licence=data?.licences.find(x=>String(x.IdLicence)===licenceId);
  const role=roleData?.roles.find(x=>String(x.IdRoleFk)===roleId);
  const canManage=Boolean(platform&&scoped&&data?.canManage&&roleData?.canManage&&!loading&&!saving);
  const licenceChanged=Boolean(licence&&JSON.stringify(draft)!==JSON.stringify(licenseDraft(data,licenceId)));
  const rightsChanged=Boolean(role&&JSON.stringify(permissions)!==JSON.stringify(roleDraft(role,roleData.catalogue)));
  const dirty=licenceChanged||rightsChanged;
  useEffect(()=>{
    if(!dirty&&!saving)return;
    const preventLeave=event=>{event.preventDefault();event.returnValue="";};
    window.addEventListener("beforeunload",preventLeave);
    return()=>window.removeEventListener("beforeunload",preventLeave);
  },[dirty,saving]);
  function requestTransition(action,changed=dirty){
    if(saveLock.current)return;
    if(changed)setPendingTransition({run:action});else action();
  }
  function confirmTransition(){const action=pendingTransition?.run;setPendingTransition(null);if(!saveLock.current)action?.();}
  function chooseEntity(id){if(id===entity)return;requestTransition(()=>{setEntity(id);setError("");setMessage("");});}
  function chooseLicence(id){if(id===licenceId)return;requestTransition(()=>{selections.current={...selections.current,licenceId:id};setLicenceId(id);setDraft(licenseDraft(data,id));setError("");setMessage("");},licenceChanged);}
  function chooseRole(id){if(id===roleId)return;requestTransition(()=>{selections.current={...selections.current,roleId:id};setRoleId(id);setPermissions(roleDraft(roleData.roles.find(x=>String(x.IdRoleFk)===id),roleData.catalogue));setError("");setMessage("");},rightsChanged);}
  function reload(){requestTransition(()=>setRevision(value=>value+1));}
  function guardLink(event){
    if(event.defaultPrevented||event.button!==0||event.metaKey||event.ctrlKey||event.altKey||event.shiftKey)return;
    const anchor=event.target.closest?.("a[href]");
    if(!anchor||anchor.hasAttribute("download")||(anchor.target&&anchor.target!=="_self"))return;
    const target=new URL(anchor.href,window.location.href);
    if(target.origin!==window.location.origin)return;
    const destination=target.pathname+target.search+target.hash;
    if(destination===location.pathname+location.search+location.hash)return;
    if(!dirty&&!saveLock.current)return;
    event.preventDefault();event.stopPropagation();requestTransition(()=>navigate(destination));
  }
  function switchTab(id){if(saveLock.current)return;setTab(id);setError("");setMessage("");}
  function navigateTabs(event,id){const next=tabForKey(id,event.key);if(!next||saveLock.current)return;event.preventDefault();switchTab(next);tabs.current[next]?.focus();}
  function changeRight(code,key,checked){
    if(!canManage||saveLock.current)return;
    setPermissions(current=>{const next={...current[code],[key]:checked};if(key==="canRead"&&!checked){next.canManage=false;next.canExport=false;}return {...current,[code]:next};});
  }
  async function save(){
    const isOffer=tab==="licences",selected=isOffer?licence:role;
    if(saveLock.current||!canManage||!selected||!(isOffer?licenceChanged:rightsChanged))return;
    const id=generation.current;saveLock.current=true;setSaving(true);setError("");setMessage("");
    try {
      const codes=(isOffer?data:roleData).catalogue.filter(x=>!isOffer||!x.EstSocle).map(x=>x.CodeModule);
      const current=isOffer?licence.activations:role.permissions;
      const versions=Object.fromEntries(codes.map(code=>[code,current.find(x=>x.CodeModule===code)?.Version || 0]));
      const body=isOffer?{versions,enabled:codes.filter(code=>draft[code])}:{entityId:Number(entity),versions,permissions};
      const result=await requestJson("/api/workspace/"+(isOffer?"licences/"+licenceId+"/modules":"roles/"+roleId),{method:"PUT",requiresAuth:true,body:JSON.stringify(body)});
      if(!mounted.current||generation.current!==id)return;
      if(!result?.success){setError(result?.message || "L’enregistrement a échoué.");return;}
      if(String(result.data?.entityId)!==entity){setError("La configuration reçue ne correspond pas à l’organisation. Rechargez-la.");return;}
      if(isOffer){setData(result.data);setDraft(licenseDraft(result.data,licenceId));}
      else{setRoleData(result.data);setPermissions(roleDraft(result.data.roles.find(x=>String(x.IdRoleFk)===roleId),result.data.catalogue));}
      setMessage("Modifications enregistrées.");
      window.dispatchEvent(new Event("sauverndeko:applications-changed"));
      await refreshUser();
    } catch {if(mounted.current&&generation.current===id)setError("L’enregistrement a échoué. Vos modifications sont conservées.");}
    finally {saveLock.current=false;if(mounted.current)setSaving(false);}
  }
  const organisation=organisations.find(x=>String(x.IdEntite)===entity);
  return <div className="applications-page" onClickCapture={guardLink}><ModuleHeader title="Licences et applications" onRequestLogout={requestTransition}/><main className="applications-main">
    <div className="applications-heading"><div><Link to="/" className="application-back"><AppIcon name="chevron-left"/>Mes applications</Link><h1>Licences et applications</h1><p>Les applications de votre organisation, selon sa licence et les droits de ses utilisateurs.</p></div><span className="application-badge">{platform?"Administration de la plateforme":"Offre de votre organisation"}</span></div>
    <section className="application-organisation">
      <span className="application-entity-icon"><i className="bi bi-building" aria-hidden="true"/></span>
      <div>{platform?<><label className="application-label" htmlFor={fieldId+"-organisation"}>Organisation</label><SearchSelect id={fieldId+"-organisation"} label="Organisation" value={entity} disabled={saving||organisationsLoading||!organisationsReady||!organisations.length} onChange={chooseEntity} options={organisations.map(x=>({value:String(x.IdEntite),label:x.NomEntite+(x.ValideEntite?"":" · inactive")}))}/></>:<><span className="application-label">Organisation</span><strong>{organisation?.NomEntite || "—"}</strong></>}</div>
      <Link to="/applications" className="ui-action is-secondary"><AppIcon name="apps"/>Catalogue des applications</Link>
    </section>
    <div className="application-tabs" role="tablist" aria-label="Configuration des applications">{TABS.map(([id,label])=><button ref={element=>{tabs.current[id]=element;}} id={"tab-"+id} aria-controls={"panel-"+id} role="tab" aria-selected={tab===id} tabIndex={tab===id?0:-1} key={id} disabled={saving} onKeyDown={event=>navigateTabs(event,id)} onClick={()=>switchTab(id)}>{label}</button>)}</div>
    {loading?<p className="application-message" role="status">Chargement de la configuration…</p>:null}
    {error?<div className="application-message is-error" role="alert"><span>{error}</span><ActionButton icon="refresh" disabled={saving||loading} onClick={reload}>Recharger</ActionButton></div>:null}
    {message?<p className="application-message is-success" role="status"><AppIcon name="check-circle"/>{message}</p>:null}
    {!loading&&organisationsReady&&!entity&&!error?<p className="application-message">Aucune organisation disponible.</p>:null}
    {!loading&&scoped?<section className="application-settings" id={"panel-"+tab} role="tabpanel" aria-labelledby={"tab-"+tab} tabIndex={0}>
      {tab==="licences"?<>
        <div className="application-settings-head"><div><h2>Modules de la licence</h2><p>Le socle est inclus. Les modules activés suivent la période de la licence.</p></div>{data.licences.length?<label className="application-field" htmlFor={fieldId+"-licence"}><span>Licence</span><SearchSelect id={fieldId+"-licence"} label="Licence" value={licenceId} disabled={saving} onChange={chooseLicence} options={data.licences.map(x=>({value:String(x.IdLicence),label:"Licence #"+x.IdLicence+" · "+x.statut_licence}))}/></label>:null}</div>
        {licence?<div className="application-license-meta"><span><small>Début</small><strong>{date(licence.DateDebut)}</strong></span><span><small>Échéance</small><strong>{date(licence.DateFin)}</strong></span><span className={"application-badge "+(licence.statut_licence==="Active"?"is-enabled":"")}>{licence.statut_licence}</span></div>:<p className="application-message">Aucune licence enregistrée. Seul le socle est disponible.</p>}
        <div className="application-module-list">{data.catalogue.map(m=>{
          const inherited=Boolean(m.CodeIncluant&&draft[m.CodeIncluant]);
          const checked=m.EstSocle||inherited||draft[m.CodeModule]||false;
          return <label className={"application-module-row "+(checked?"is-checked":"")} key={m.CodeModule}>
            <input type="checkbox" checked={checked} disabled={!canManage||m.EstSocle||inherited||!licence||!m.Actif} onChange={event=>{if(!saveLock.current)setDraft(current=>({...current,[m.CodeModule]:event.target.checked}));}}/>
            <span><strong>{m.Nom}</strong><small>{m.EstSocle?"Socle inclus":inherited?"Inclus dans Catalogue":draft[m.CodeModule]?"Activé dans cette licence":"Non activé"}</small></span>
            {m.EstSocle?<AppIcon name="check-circle"/>:null}
          </label>;
        })}</div>
      </>:<>
        <div className="application-settings-head"><div><h2>Droits des rôles</h2><p>Les droits s’appliquent aux applications comprises dans l’offre.</p></div>{roleData.roles.length?<label className="application-field" htmlFor={fieldId+"-role"}><span>Rôle</span><SearchSelect id={fieldId+"-role"} label="Rôle" value={roleId} disabled={saving} onChange={chooseRole} options={roleData.roles.map(x=>({value:String(x.IdRoleFk),label:x.NomRole}))}/></label>:null}</div>
        {role?<div className="erp-results application-role-table"><div className="application-table-scroll"><table className="application-rights-table"><thead><tr><th>Application</th>{RIGHTS.map(([key,label])=><th key={key}>{label}</th>)}</tr></thead><tbody>{roleData.catalogue.map(m=><tr key={m.CodeModule}><th scope="row">{m.Nom}{m.EstSocle?<small>Socle</small>:null}</th>{RIGHTS.map(([key,label])=><td key={key}><input type="checkbox" aria-label={label+" · "+m.Nom} checked={permissions[m.CodeModule]?.[key]||false} disabled={!canManage||!role.baseline[m.CodeModule]?.[key]||(key!=="canRead"&&!permissions[m.CodeModule]?.canRead)} onChange={e=>changeRight(m.CodeModule,key,e.target.checked)}/></td>)}</tr>)}</tbody></table></div></div>:<p className="application-message">Aucun rôle d’entreprise à configurer.</p>}
        <p className="application-footnote">Ces réglages limitent les habilitations existantes. L’administration de la plateforme conserve son accès de maintenance.</p>
      </>}
      <footer className="application-save-bar"><span>{platform ? "Les accès seront mis à jour après l’enregistrement." : "Les activations sont gérées par l’administration de la plateforme."}</span>{platform?<div><ActionButton icon="reset" disabled={!canManage||!(tab==="licences"?licenceChanged:rightsChanged)} onClick={()=>requestTransition(()=>tab==="licences"?setDraft(licenseDraft(data,licenceId)):setPermissions(roleDraft(role,roleData.catalogue)),tab==="licences"?licenceChanged:rightsChanged)}>Annuler</ActionButton><ActionButton icon="check-circle" variant="primary" disabled={!canManage||!(tab==="licences"?licenceChanged&&licence:rightsChanged&&role)} onClick={save}>{saving?"Enregistrement…":"Enregistrer"}</ActionButton></div>:null}</footer>
    </section>:null}
  </main>{pendingTransition?<DrawerDialog title="Modifications non enregistrées" icon="alert" onClose={dismissTransition} defaultWidth={560} storageKey="sauverndeko.application-discard.width" footer={<footer className="application-save-bar"><span/><div><ActionButton onClick={dismissTransition}>Continuer la saisie</ActionButton><ActionButton variant="primary" onClick={confirmTransition}>Abandonner</ActionButton></div></footer>}><p>Continuer sans enregistrer les modifications ?</p></DrawerDialog>:null}</div>;
}
