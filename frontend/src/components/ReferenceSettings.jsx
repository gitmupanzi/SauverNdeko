import { useEffect, useId, useRef, useState } from "react";
import DrawerDialog from "./DrawerDialog";
import { Link } from "react-router-dom";
import AppIcon from "./AppIcon";
import ActionButton from "./ActionButton";
import "./ReferenceSettings.css";
const GROUPS = {
  "logistique.articleCategories":{title:"Catégories d’articles",icon:"tag"},
  "logistique.articleTypes":{title:"Types d’articles",icon:"box"},
  "logistique.articleUnits":{title:"Unités de mesure",icon:"list"},
  "logistique.commandeTypes":{title:"Types de bons",icon:"receipt"},
  "logistique.commandeStatuses":{title:"Statuts des bons",icon:"check-circle"},
  "logistique.commandeConditionPaiements":{title:"Conditions de paiement",icon:"calendar"},
  "logistique.commandeModesPaiement":{title:"Modes de paiement",icon:"wallet"},
  "logistique.reglementModes":{title:"Modes de règlement",icon:"wallet"},
};
const normalize=value=>String(value || "").normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLowerCase();
function CategoryEditor({ item, categories, disabled, onChange }) {
  const [search,setSearch]=useState("");
  const selected=item.parsedInput || [];
  const choices=categories.map(row=>({id:String(row.ID_CategorieGenerique ?? row.id),label:row.NomCategorieGenerique || row.label || "Catégorie sans nom"}));
  selected.forEach(id=>{ if(!choices.some(row=>row.id===String(id))) choices.push({id:String(id),label:"Catégorie indisponible · "+id}); });
  const filtered=choices.filter(row=>normalize(row.label).includes(normalize(search)));
  return <fieldset className="reference-category-editor" disabled={disabled}><legend>Catégories utilisées</legend>
    <label className="reference-value-search"><AppIcon name="search"/><input type="search" aria-label="Rechercher une catégorie" placeholder="Rechercher une catégorie…" value={search} onChange={event=>setSearch(event.target.value)}/></label>
    <div>{filtered.map(row=><label key={row.id}><input type="checkbox" checked={selected.map(String).includes(row.id)} onChange={event=>onChange(event.target.checked ? [...selected,row.id].join(", ") : selected.filter(id=>String(id)!==row.id).join(", "))}/><span>{row.label}</span></label>)}{!filtered.length?<p>Aucune catégorie correspondante.</p>:null}</div>
  </fieldset>;
}
function ReferenceGroup({ item, values, categories, canEdit, saving, expanded, onToggle, onChange, onApply, onReset }) {
  const [search,setSearch]=useState("");
  const searchRef=useRef(null);
  const region=useId();
  const presentation=GROUPS[item.sourceKey] || {title:item.labels.join(", "),icon:"list"};
  const available=Array.isArray(values);
  const filtered=available ? values.filter(row=>normalize([row.label,row.abbr].filter(Boolean).join(" ")).includes(normalize(search))) : [];
  useEffect(()=>{ if(!expanded) {setSearch("");return;} const frame=requestAnimationFrame(()=>searchRef.current?.focus({preventScroll:true}));return()=>cancelAnimationFrame(frame); },[expanded]);
  return <article className={"reference-group"+(expanded?" is-expanded":"")}>
    <div className="reference-group-heading"><span className="reference-group-icon"><AppIcon name={presentation.icon} size={20}/></span><div><h3>{presentation.title}</h3><p>{item.effectiveCategoryLabels || "Catégorie non renseignée"}</p></div><span className="reference-value-count">{available?values.length:"—"}<small>{available && values.length===1?"valeur":"valeurs"}</small></span></div>
    <div className="reference-group-bottom"><span className="reference-standard"><AppIcon name={item.isLocked?"check-circle":"settings"} size={13}/>{item.isLocked?"Configuration standard":item.isDirty?"Modification à enregistrer":"Configuration personnalisée"}</span><button type="button" aria-expanded={expanded} aria-controls={region} onClick={onToggle}>Voir les valeurs<AppIcon name={expanded?"chevron-up":"chevron-down"} size={14}/></button></div>
    {expanded?<div id={region} className="reference-values"><label className="reference-value-search"><AppIcon name="search"/><input ref={searchRef} type="search" aria-label={"Rechercher dans "+presentation.title} placeholder="Rechercher une valeur…" value={search} onChange={event=>setSearch(event.target.value)} /></label>
      {!available ? <p className="reference-empty" role="status">Cette liste n’est pas disponible.</p> : <><ul>{filtered.map((row,index)=><li key={row.id ?? row.code ?? index}><span>{row.label || row.code || "Valeur sans nom"}</span>{row.abbr?<small>{row.abbr}</small>:null}</li>)}</ul>{!filtered.length?<p className="reference-empty" role="status">{values.length ? "Aucune valeur correspondante." : "Aucune valeur disponible."}</p>:null}<p className="reference-results" role="status">{filtered.length} sur {values.length} {values.length===1?"valeur":"valeurs"}</p></>}
    </div>:null}
    {!item.isLocked && canEdit ? <div className="reference-group-editor"><CategoryEditor item={item} categories={categories} disabled={saving} onChange={onChange}/>{!item.isValid?<p className="reference-error" role="alert">Sélectionnez au moins une catégorie.</p>:null}<div><ActionButton icon="reset" onClick={onReset} disabled={saving || (!item.isCustom && !item.isDirty)}>Rétablir</ActionButton><ActionButton variant="primary" icon="check-circle" onClick={onApply} disabled={saving || !item.isValid || !item.isDirty}>Enregistrer</ActionButton></div></div>:null}
  </article>;
}
function DirectReference({ mapping }) {
  const user=/User/i.test(mapping.field);
  return <div className="reference-direct"><span><AppIcon name={user?"user":"document"}/></span><div><strong>{user?"Responsable":mapping.label}</strong><p>{user?"Compte associé à l’enregistrement.":"Donnée liée à l’enregistrement."}</p></div><span className="reference-direct-label">Association directe</span></div>;
}
export default function ReferenceSettings({ title, mappings, directMappings, references, categories, loading, saving, error, supportError, meta, auditRows, auditLoading, auditError, canEdit, formatDateTime, onClose, onChange, onApply, onReset, onApplyAll, onResetAll, onRetry }) {
  const [section,setSection]=useState("references");
  const [expanded,setExpanded]=useState("");
  const editable=mappings.filter(item=>!item.isLocked);
  const dirty=editable.some(item=>item.isDirty),invalid=editable.some(item=>!item.isValid),custom=editable.some(item=>item.isCustom);
  const synced=Boolean(meta.updatedAt);
  return <DrawerDialog title="Réglages des références" subtitle={title} icon="settings" className="reference-settings" headerClassName="reference-settings-header" bodyClassName="reference-settings-content" closeClassName="reference-close" closeLabel="Fermer les réglages" storageKey="sauverndeko.references.width" defaultWidth={760} busy={saving} onClose={onClose} top={<nav className="reference-settings-tabs" aria-label="Rubriques des réglages">{[["references","Références","list"],["history","Historique","clock"]].map(([key,label,icon])=><button key={key} type="button" aria-current={section===key?"page":undefined} onClick={()=>setSection(key)}><AppIcon name={icon}/>{label}</button>)}</nav>} footer={<footer className="reference-settings-footer"><Link to="/referentiels" className="reference-catalogue-link" aria-disabled={saving} onClick={event=>{if(saving){event.preventDefault();return;}onClose();}}><AppIcon name="tag"/>Ouvrir les référentiels<AppIcon name="arrow-up-right" size={14}/></Link>{section==="references" && canEdit && editable.length ? <div><ActionButton icon="reset" onClick={onResetAll} disabled={loading || saving || (!custom && !dirty)}>Rétablir les valeurs</ActionButton><ActionButton variant="primary" icon="check-circle" onClick={onApplyAll} disabled={loading || saving || invalid || !dirty}>{saving?"Enregistrement…":"Tout enregistrer"}</ActionButton></div>:<ActionButton onClick={onClose} disabled={saving}>Fermer</ActionButton>}</footer>}>

      {section==="references"?<>
        <div className={"reference-sync is-"+(error?"error":loading || saving?"pending":synced?"success":"neutral")} role={error?"alert":"status"}><AppIcon name={error?"alert":loading || saving?"refresh":synced?"check-circle":"settings"}/><div><strong>{error?"Chargement indisponible":loading?"Chargement des réglages…":saving?"Enregistrement en cours…":synced?"Réglages synchronisés":"Réglages locaux"}</strong><p>{error || (loading || saving ? "Veuillez patienter." : synced ? [meta.updatedAt?"Mis à jour le "+formatDateTime(meta.updatedAt):"",meta.updatedByName?"par "+meta.updatedByName:""].filter(Boolean).join(" ") : "Aucun réglage partagé enregistré.")}</p></div>{error?<ActionButton icon="refresh" onClick={onRetry} disabled={loading}>Réessayer</ActionButton>:null}</div>
        {supportError?<p className="reference-warning" role="alert">Certaines listes de référence n’ont pas pu être chargées.</p>:null}
        <div className="reference-groups">{mappings.map(item=><ReferenceGroup key={item.sourceKey} item={item} values={references?.[item.config.referenceKey]} categories={categories} canEdit={canEdit} saving={saving || loading} expanded={expanded===item.sourceKey} onToggle={()=>setExpanded(current=>current===item.sourceKey?"":item.sourceKey)} onChange={value=>onChange(item.sourceKey,value)} onApply={()=>onApply(item.sourceKey)} onReset={()=>onReset(item.sourceKey)}/>)}</div>
        {directMappings.length?<section className="reference-direct-section"><h3>Informations associées</h3>{directMappings.map(mapping=><DirectReference key={mapping.field+mapping.label} mapping={mapping}/>)}</section>:null}
      </>:<section className="reference-history"><h3>Modifications récentes</h3>{auditLoading?<p role="status">Chargement de l’historique…</p>:auditError?<p className="reference-error" role="alert">L’historique n’a pas pu être chargé.</p>:auditRows.length?<ol>{auditRows.map((row,index)=><li key={row.IdLog ?? index}><span><AppIcon name="clock"/></span><div><strong>{/CREATE|INSERT/.test(row.Operation)?"Création des réglages":row.Operation==="DELETE"?"Suppression des réglages":"Mise à jour des réglages"}</strong><p>{formatDateTime(row.ChangedAt || row.UpdatedSettingAt) || "Date non renseignée"}</p>{row.UpdatedByName?<small>{row.UpdatedByName}</small>:null}</div></li>)}</ol>:<div className="reference-history-empty"><AppIcon name="clock" size={26}/><p>Aucune modification dans l’historique récent.</p></div>}</section>}
  </DrawerDialog>;
}
