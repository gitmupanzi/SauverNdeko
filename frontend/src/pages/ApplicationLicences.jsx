import {useEffect,useRef,useState} from "react";
import {Link} from "react-router-dom";
import {useAuth} from "../contexts/AuthContext";
import {requestJson} from "../services/api";
import ModuleHeader from "../components/ModuleHeader";
import ActionButton from "../components/ActionButton";
import AppIcon from "../components/AppIcon";
import "../components/DataTable.css";
import "./Applications.css";

const RIGHTS=[["canRead","Consulter"],["canManage","Gérer"],["canExport","Exporter"]];
function date(value) {return value ? new Intl.DateTimeFormat("fr-FR",{dateStyle:"medium"}).format(new Date(value)):"—";}
function licenseDraft(data,id) {const licence=data?.licences?.find(x=>String(x.IdLicence)===String(id));return Object.fromEntries((data?.catalogue || []).map(m=>[m.CodeModule,Boolean(licence?.activations?.find(x=>x.CodeModule===m.CodeModule)?.Actif)]));}
function roleDraft(role,catalogue) {return Object.fromEntries(catalogue.map(m=>{const stored=role?.permissions?.find(x=>x.CodeModule===m.CodeModule),base=role?.baseline?.[m.CodeModule] || {};return [m.CodeModule,Object.fromEntries(RIGHTS.map(([key],index)=>[key,Boolean(base[key]&&(!stored || (stored.Actif&&stored[["PeutConsulter","PeutGerer","PeutExporter"][index]])))]))];}));}

export default function ApplicationLicences() {
  const {user,refreshUser}=useAuth();
  const platform=Boolean(user?.moduleAccess?.platformAdmin);
  const [organisations,setOrganisations]=useState([]);
  const [entity,setEntity]=useState("");
  const [tab,setTab]=useState("licences");
  const [data,setData]=useState(null),[roleData,setRoleData]=useState(null);
  const [licenceId,setLicenceId]=useState(""),[roleId,setRoleId]=useState("");
  const [draft,setDraft]=useState({}),[permissions,setPermissions]=useState({});
  const [loading,setLoading]=useState(true),[saving,setSaving]=useState(false);
  const [error,setError]=useState(""),[message,setMessage]=useState("");
  const [revision,setRevision]=useState(0);
  const generation=useRef(0),mounted=useRef(true);
  useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;generation.current++;};},[]);
  useEffect(()=>{
    let active=true;setError("");setLoading(true);
    requestJson("/api/workspace/organisations",{requiresAuth:true}).then(result=>{
      if(!active)return;
      if(!result?.success){setError(result?.message || "Les organisations sont indisponibles.");setLoading(false);return;}
      setOrganisations(result.data);
      setEntity(String(result.data.find(x=>x.IdEntite===user?.IdEntiteFk)?.IdEntite || result.data[0]?.IdEntite || ""));
      if(!result.data.length)setLoading(false);
    });
    return()=>{active=false;};
  },[user?.IdUser,user?.IdEntiteFk,revision]);
  useEffect(()=>{
    if(!entity)return;
    const id=++generation.current;
    setLoading(true);setError("");setMessage("");setData(null);setRoleData(null);setDraft({});setPermissions({});
    async function load(){
      const results=await Promise.allSettled(["licences","roles"].map(kind=>requestJson("/api/workspace/"+kind+"?entite="+encodeURIComponent(entity),{requiresAuth:true})));
      if(!mounted.current||generation.current!==id)return;
      const [offer,roles]=results.map(r=>r.status==="fulfilled"?r.value:null);
      if(!offer?.success||!roles?.success){setError(offer?.message || roles?.message || "La configuration est indisponible.");setLoading(false);return;}
      setData(offer.data);setRoleData(roles.data);
      const licence=String(offer.data.licences.find(x=>x.statut_licence==="Active")?.IdLicence || offer.data.licences[0]?.IdLicence || "");
      const role=String(roles.data.roles[0]?.IdRoleFk || "");
      setLicenceId(licence);setDraft(licenseDraft(offer.data,licence));
      setRoleId(role);setPermissions(roleDraft(roles.data.roles[0],roles.data.catalogue));
      setLoading(false);
    }
    void load();
  },[entity,revision]);
  const licence=data?.licences.find(x=>String(x.IdLicence)===licenceId);
  const role=roleData?.roles.find(x=>String(x.IdRoleFk)===roleId);
  const canManage=Boolean(platform&&data?.canManage&&roleData?.canManage&&!loading&&!saving);
  const licenceChanged=JSON.stringify(draft)!==JSON.stringify(licenseDraft(data,licenceId));
  const rightsChanged=role ? JSON.stringify(permissions)!==JSON.stringify(roleDraft(role,roleData.catalogue)):false;
  function chooseLicence(id){setLicenceId(id);setDraft(licenseDraft(data,id));setError("");setMessage("");}
  function chooseRole(id){setRoleId(id);setPermissions(roleDraft(roleData.roles.find(x=>String(x.IdRoleFk)===id),roleData.catalogue));setError("");setMessage("");}
  function changeRight(code,key,checked){
    setPermissions(current=>{
      const next={...current[code],[key]:checked};
      if(key==="canRead"&&!checked){next.canManage=false;next.canExport=false;}
      return {...current,[code]:next};
    });
  }
  async function save(){
    if(!canManage)return;
    const id=generation.current;setSaving(true);setError("");setMessage("");
    const isOffer=tab==="licences", codes=(isOffer?data:roleData).catalogue.filter(x=>!isOffer||!x.EstSocle).map(x=>x.CodeModule);
    const current=isOffer?licence.activations:role.permissions;
    const versions=Object.fromEntries(codes.map(code=>[code,current.find(x=>x.CodeModule===code)?.Version || 0]));
    const body=isOffer?{versions,enabled:codes.filter(code=>draft[code])}:{entityId:Number(entity),versions,permissions};
    try{
      const result=await requestJson("/api/workspace/"+(isOffer?"licences/"+licenceId+"/modules":"roles/"+roleId),{method:"PUT",requiresAuth:true,body:JSON.stringify(body)});
      if(!mounted.current||generation.current!==id)return;
      if(!result?.success){setError(result?.message || "L’enregistrement a échoué.");return;}
      if(isOffer){setData(result.data);setDraft(licenseDraft(result.data,licenceId));}
      else{setRoleData(result.data);setPermissions(roleDraft(result.data.roles.find(x=>String(x.IdRoleFk)===roleId),result.data.catalogue));}
      setMessage("Modifications enregistrées.");
      window.dispatchEvent(new Event("sauverndeko:applications-changed"));
      await refreshUser();
    }finally{if(mounted.current&&generation.current===id)setSaving(false);}
  }
  const organisation=organisations.find(x=>String(x.IdEntite)===entity);
  return <div className="applications-page"><ModuleHeader title="Licences et applications"/><main className="applications-main">
    <div className="applications-heading"><div><Link to="/" className="application-back"><AppIcon name="chevron-left"/>Mes applications</Link><h1>Licences et applications</h1><p>Les applications de votre organisation, selon sa licence et les droits de ses utilisateurs.</p></div><span className="application-badge">{platform?"Administration de la plateforme":"Offre de votre organisation"}</span></div>
    <section className="application-organisation">
      <span className="application-entity-icon"><i className="bi bi-building" aria-hidden="true"/></span>
      <div><span className="application-label">Organisation</span>{platform?<select aria-label="Organisation" value={entity} disabled={saving||!organisations.length} onChange={e=>setEntity(e.target.value)}>{organisations.map(x=><option key={x.IdEntite} value={x.IdEntite}>{x.NomEntite}{x.ValideEntite?"":" · inactive"}</option>)}</select>:<strong>{organisation?.NomEntite || "—"}</strong>}</div>
      <Link to="/applications" className="ui-action is-secondary"><AppIcon name="apps"/>Catalogue des applications</Link>
    </section>
    <div className="application-tabs" role="tablist" aria-label="Configuration des applications">{[["licences","Modules de la licence"],["roles","Droits des rôles"]].map(([id,label])=><button id={"tab-"+id} aria-controls={"panel-"+id} role="tab" aria-selected={tab===id} key={id} disabled={saving} onClick={()=>{setTab(id);setError("");setMessage("");}}>{label}</button>)}</div>
    {loading?<p className="application-message" role="status">Chargement de la configuration…</p>:null}
    {error?<div className="application-message is-error" role="alert"><span>{error}</span><ActionButton icon="refresh" disabled={saving} onClick={()=>setRevision(x=>x+1)}>Recharger</ActionButton></div>:null}
    {message?<p className="application-message is-success" role="status"><AppIcon name="check-circle"/>{message}</p>:null}
    {!loading&&!entity&&!error?<p className="application-message">Aucune organisation disponible.</p>:null}
    {!loading&&data&&roleData?<section className="application-settings" id={"panel-"+tab} role="tabpanel" aria-labelledby={"tab-"+tab}>
      {tab==="licences"?<>
        <div className="application-settings-head"><div><h2>Modules de la licence</h2><p>Le socle est inclus. Les modules activés suivent la période de la licence.</p></div>{data.licences.length?<label className="application-field">Licence<select aria-label="Licence" value={licenceId} disabled={saving} onChange={e=>chooseLicence(e.target.value)}>{data.licences.map(x=><option key={x.IdLicence} value={x.IdLicence}>Licence #{x.IdLicence} · {x.statut_licence}</option>)}</select></label>:null}</div>
        {licence?<div className="application-license-meta"><span><small>Début</small><strong>{date(licence.DateDebut)}</strong></span><span><small>Échéance</small><strong>{date(licence.DateFin)}</strong></span><span className={"application-badge "+(licence.statut_licence==="Active"?"is-enabled":"")}>{licence.statut_licence}</span></div>:<p className="application-message">Aucune licence enregistrée. Seul le socle est disponible.</p>}
        <div className="application-module-list">{data.catalogue.map(m=>{
          const inherited=Boolean(m.CodeIncluant&&draft[m.CodeIncluant]);
          const checked=m.EstSocle||inherited||draft[m.CodeModule]||false;
          return <label className={"application-module-row "+(checked?"is-checked":"")} key={m.CodeModule}>
            <input type="checkbox" checked={checked} disabled={!canManage||m.EstSocle||inherited||!licence||!m.Actif} onChange={e=>setDraft(current=>({...current,[m.CodeModule]:e.target.checked}))}/>
            <span><strong>{m.Nom}</strong><small>{m.EstSocle?"Socle inclus":inherited?"Inclus dans Catalogue":draft[m.CodeModule]?"Activé dans cette licence":"Non activé"}</small></span>
            {m.EstSocle?<AppIcon name="check-circle"/>:null}
          </label>;
        })}</div>
      </>:<>
        <div className="application-settings-head"><div><h2>Droits des rôles</h2><p>Les droits s’appliquent aux applications comprises dans l’offre.</p></div>{roleData.roles.length?<label className="application-field">Rôle<select aria-label="Rôle" value={roleId} disabled={saving} onChange={e=>chooseRole(e.target.value)}>{roleData.roles.map(x=><option key={x.IdRoleFk} value={x.IdRoleFk}>{x.NomRole}</option>)}</select></label>:null}</div>
        {role?<div className="erp-results application-role-table"><div className="application-table-scroll"><table className="application-rights-table"><thead><tr><th>Application</th>{RIGHTS.map(([key,label])=><th key={key}>{label}</th>)}</tr></thead><tbody>{roleData.catalogue.map(m=><tr key={m.CodeModule}><th scope="row">{m.Nom}{m.EstSocle?<small>Socle</small>:null}</th>{RIGHTS.map(([key,label])=><td key={key}><input type="checkbox" aria-label={label+" · "+m.Nom} checked={permissions[m.CodeModule]?.[key]||false} disabled={!canManage||!role.baseline[m.CodeModule]?.[key]||(key!=="canRead"&&!permissions[m.CodeModule]?.canRead)} onChange={e=>changeRight(m.CodeModule,key,e.target.checked)}/></td>)}</tr>)}</tbody></table></div></div>:<p className="application-message">Aucun rôle d’entreprise à configurer.</p>}
        <p className="application-footnote">Ces réglages limitent les habilitations existantes. L’administration de la plateforme conserve son accès de maintenance.</p>
      </>}
      <footer className="application-save-bar"><span>{platform ? "Les changements s’appliquent aux prochaines requêtes." : "Les activations sont gérées par l’administration de la plateforme."}</span>{platform?<div><ActionButton icon="reset" disabled={!canManage||!(tab==="licences"?licenceChanged:rightsChanged)} onClick={()=>tab==="licences"?setDraft(licenseDraft(data,licenceId)):setPermissions(roleDraft(role,roleData.catalogue))}>Annuler</ActionButton><ActionButton icon="check-circle" variant="primary" disabled={!canManage||!(tab==="licences"?licenceChanged&&licence:rightsChanged&&role)} onClick={save}>{saving?"Enregistrement…":"Enregistrer"}</ActionButton></div>:null}</footer>
    </section>:null}
  </main></div>;
}
