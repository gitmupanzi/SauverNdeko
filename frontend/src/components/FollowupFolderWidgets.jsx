import { useEffect, useId, useRef, useState } from "react";
import AppIcon from "./AppIcon";
import ActionButton from "./ActionButton";
import SearchSelect from "./SearchSelect";
import DrawerDialog from "./DrawerDialog";
import RecordEditorFrame from "./RecordEditorFrame";
import { useAuth } from "../contexts/AuthContext";
import { moduleRights } from "../services/moduleAccess";
import { folderRequest as requestJson } from "../services/followupFolders";
import { useFollowupFolders } from "../contexts/FollowupFoldersContext";
import "./FollowupFolders.css";
export const FOLDER_COLOURS=[["vert","Vert"],["rouge","Rouge"],["orange","Orange"],["bleu","Bleu"],["violet","Violet"],["ardoise","Ardoise"]];
export function FolderBadge({folder,onClick}) {
  return <button type="button" className={"article-folder-badge tone-"+folder.colour} onClick={onClick}><AppIcon name="folder"/><span><strong>{folder.name}</strong><small>{folder.category}</small></span><AppIcon name="chevron-right" size={14}/></button>;
}
export function RecordFolderLinks({data,recordId,objectType="article",hasInvoice=false,onOpen}) {
  const {assign}=useFollowupFolders();
  const {user}=useAuth();
  const canWrite=Boolean(data?.canWrite && user?.permissions?.canWriteData && moduleRights(user,"logistique").canManage);
  return <section className="product-folder-links"><header><h4><AppIcon name="folder"/>Dossiers de suivi{data?<span>{data.items.length}</span>:null}</h4>{canWrite?<div className="folder-classify-actions"><ActionButton icon="plus" onClick={()=>assign([Number(recordId)],objectType)}>{objectType==="article"?"Classer":"Classer le bon"}</ActionButton>{hasInvoice?<ActionButton icon="plus" onClick={()=>assign([Number(recordId)],"facture")}>Classer la facture</ActionButton>:null}</div>:null}</header>
    {!data?<p>Classement indisponible.</p>:data.items.length?<div>{data.items.map(folder=><FolderBadge key={folder.key} folder={folder} onClick={()=>onOpen(folder.key)}/>)}</div>:<p>Aucun dossier associé.</p>}
    {data?.requiresOwner?<p className="product-folder-availability">Renseignez le responsable pour classer cet enregistrement.</p>:null}
    {data && !data.customAvailable?<p className="product-folder-availability">Les dossiers personnalisés ne sont pas encore activés.</p>:null}
  </section>;
}
export function ColourPicker({value,onChange,label="Couleur du dossier"}) {
  return <fieldset className="article-folder-colours"><legend>{label}</legend><div>{FOLDER_COLOURS.map(([key,name])=><button key={key} type="button" className={"tone-"+key} aria-label={name} aria-pressed={value===key} title={name} onClick={()=>onChange(key)}><span/>{value===key?<AppIcon name="check-circle"/>:null}</button>)}</div></fieldset>;
}
const EMPTY={name:"",description:"",colour:"bleu",categoryId:"",mode:"manuel",objectType:"article",rules:{}};
export function FolderEditor({folder,categories,references,onClose,onSaved,canWrite=false,defaultObjectType="article"}) {
  const selectPrefix=useId();
  const initial=useRef(folder?{...folder,categoryId:folder.categoryId ?? ""}:{...EMPTY,objectType:defaultObjectType});
  const [draft,setDraft]=useState(()=>initial.current);
  const [localCategories,setCategories]=useState(categories),[addingCategory,setAddingCategory]=useState(false),[categoryName,setCategoryName]=useState(""),[categoryColour,setCategoryColour]=useState("bleu");
  const [saving,setSaving]=useState(false),[error,setError]=useState(""),[preview,setPreview]=useState(null),[previewLoading,setPreviewLoading]=useState(false);
  const {refresh}=useFollowupFolders();
  const previewRequest=useRef(null),mutation=useRef(false);
  const dirty=JSON.stringify(draft)!==JSON.stringify(initial.current) || categoryName!=="" || categoryColour!=="bleu";
  useEffect(()=>()=>previewRequest.current?.abort(),[]);
  const patch=(key,value)=>setDraft(current=>({...current,[key]:value}));
  const changeRule=(key,value)=>{previewRequest.current?.abort();setPreviewLoading(false);setDraft(current=>({...current,rules:{...current.rules,[key]:value}}));setPreview(null);};
  async function createCategory(){
    if(mutation.current || !canWrite || !categoryName.trim())return;
    mutation.current=true;setSaving(true);setError("");
    try {
      const response=await requestJson("/api/logistique/dossiers-suivi/categories",{method:"POST",body:{name:categoryName.trim(),colour:categoryColour}});
      if(!response.success){setError(response.message || "La catégorie n’a pas été créée.");return;}
      setCategories(current=>[...current,response.data]);patch("categoryId",response.data.ID_CategorieDossierSuivi);setAddingCategory(false);setCategoryName("");setCategoryColour("bleu");refresh();
    } catch {setError("La catégorie n’a pas été créée. Réessayez.");}
    finally {mutation.current=false;setSaving(false);}
  }
  async function showPreview(){if(mutation.current || !canWrite)return;const controller=new AbortController();previewRequest.current?.abort();previewRequest.current=controller;setPreviewLoading(true);setError("");const response=await requestJson("/api/logistique/dossiers-suivi/apercu",{method:"POST",body:{rules:draft.rules,objectType:draft.objectType},signal:controller.signal});if(controller.signal.aborted)return;setPreviewLoading(false);if(!response.success){setError(response.message || "L’aperçu n’est pas disponible.");return;}setPreview(response.data);}
  async function submit(){
    if(mutation.current || !canWrite || !draft.name.trim())return;
    mutation.current=true;setSaving(true);setError("");previewRequest.current?.abort();setPreviewLoading(false);
    const body={name:draft.name.trim(),description:draft.description,colour:draft.colour,categoryId:draft.categoryId || null,mode:draft.mode,objectType:draft.objectType,rules:draft.mode==="automatique"?draft.rules:{},...(folder?{version:folder.version}:{})};
    try {
      const response=await requestJson("/api/logistique/dossiers-suivi"+(folder?"/"+folder.key:""),{method:folder?"PUT":"POST",body});
      if(!response.success){setError(response.message || "Le dossier n’a pas été enregistré.");return;}
      refresh();onSaved(response.data);
    } catch {setError("Le dossier n’a pas été enregistré. Réessayez.");}
    finally {mutation.current=false;setSaving(false);}
  }
  const articleRuleFields=[{key:"categorieId",label:"Catégorie d’article",options:references?.articleCategories || []},{key:"typeId",label:"Type d’article",options:references?.articleTypes || []},{key:"uniteId",label:"Unité",options:references?.articleUnits || []},{key:"stockState",label:"Stock",options:[{id:"rupture",label:"Rupture"},{id:"faible",label:"Stock faible"},{id:"disponible",label:"Disponible"}]},{key:"peremption",label:"Péremption",options:[{id:"alerte",label:"Péremption proche"},{id:"perime",label:"Périmé"},{id:"valide",label:"Valide"},{id:"non-renseignee",label:"Non renseignée"}]},{key:"statut",label:"État de l’article",options:[{id:"true",label:"Actif"},{id:"false",label:"Inactif"}]}];
  const ruleFields=draft.objectType==="article"?articleRuleFields:draft.objectType==="bon"?[
    {key:"etatBon",label:"État du bon",options:[{id:"attente",label:"En attente"},{id:"en-cours",label:"En cours"},{id:"entree",label:"Entrée"},{id:"sortie",label:"Sortie"},{id:"non-facture",label:"Non facturé"},{id:"sans-lignes",label:"Sans lignes"}]},
    {key:"typeId",label:"Type de bon",options:references?.commandeTypes || []},{key:"statutId",label:"Statut du bon",options:references?.commandeStatuses || []}
  ]:[{key:"etatFacture",label:"État de la facture",options:[{id:"a-regler",label:"À régler"},{id:"retard",label:"En retard"},{id:"partielle",label:"Partiellement réglée"},{id:"soldee",label:"Soldée"}]}];
  return <RecordEditorFrame title={folder?"Modifier le dossier":"Nouveau dossier de suivi"} icon="folder" onClose={onClose} onSubmit={submit} busy={saving} dirty={dirty} canSubmit={canWrite && Boolean(draft.name.trim())} error={error} storageKey="sauverndeko.folder-editor.width">
    <fieldset className="article-folder-form article-folder-fieldset" disabled={saving || !canWrite}><label><span>Nom du dossier</span><input autoFocus required maxLength={120} value={draft.name} onChange={event=>patch("name",event.target.value)} placeholder="Ex. : Matériel à renouveler"/></label><label><span>Description</span><textarea maxLength={1000} value={draft.description} onChange={event=>patch("description",event.target.value)} rows={2}/></label>
      <label htmlFor={selectPrefix+"-object-type"}><span>Type de données</span><SearchSelect id={selectPrefix+"-object-type"} label="Type de données" value={draft.objectType} options={[{value:"article",label:"Articles"},{value:"bon",label:"Bons de stock"},{value:"facture",label:"Factures"}]} disabled={saving || !canWrite || Boolean(folder)} onChange={value=>{previewRequest.current?.abort();setPreviewLoading(false);setPreview(null);setDraft(current=>({...current,objectType:value,rules:{}}));}}/></label>
      <div className="article-folder-form-grid"><label htmlFor={selectPrefix+"-category"}><span>Catégorie du dossier</span><SearchSelect id={selectPrefix+"-category"} label="Catégorie du dossier" value={String(draft.categoryId ?? "")} options={[{value:"",label:"Sans catégorie"},...localCategories.map(category=>({value:String(category.ID_CategorieDossierSuivi),label:category.Nom}))]} disabled={saving || !canWrite} onChange={value=>patch("categoryId",value)}/></label><label htmlFor={selectPrefix+"-mode"}><span>Alimentation</span><SearchSelect id={selectPrefix+"-mode"} label="Alimentation" value={draft.mode} options={[{value:"manuel",label:"Manuelle"},{value:"automatique",label:"Automatique"}]} disabled={saving || !canWrite || Boolean(folder)} onChange={value=>{previewRequest.current?.abort();setPreviewLoading(false);patch("mode",value);setPreview(null);}}/></label></div>
      <button type="button" className="article-folder-inline-action" onClick={()=>setAddingCategory(value=>!value)}><AppIcon name="plus"/>Nouvelle catégorie</button>
      {addingCategory?<section className="article-folder-new-category"><label><span>Nom de la catégorie</span><input maxLength={80} value={categoryName} onChange={event=>setCategoryName(event.target.value)}/></label><ColourPicker label="Couleur de la catégorie" value={categoryColour} onChange={setCategoryColour}/><ActionButton icon="plus" onClick={createCategory} disabled={saving || !categoryName.trim()}>Créer la catégorie</ActionButton></section>:null}
      <ColourPicker value={draft.colour} onChange={value=>patch("colour",value)}/>
      {draft.mode==="automatique"?<section className="article-folder-rules"><h3>Critères de classement</h3><label><span>Recherche</span><input value={draft.rules.q || ""} maxLength={300} onChange={event=>changeRule("q",event.target.value)}/></label><div className="article-folder-form-grid">{ruleFields.map(field=><label key={field.key} htmlFor={selectPrefix+"-rule-"+field.key}><span>{field.label}</span><SearchSelect id={selectPrefix+"-rule-"+field.key} label={field.label} value={String(draft.rules[field.key] || "")} options={[{value:"",label:"Tous"},...field.options.map(option=>({value:String(option.id),label:option.label}))]} disabled={saving || !canWrite} onChange={value=>changeRule(field.key,value)}/></label>)}</div><ActionButton icon="eye" onClick={showPreview} disabled={previewLoading}>{previewLoading?"Calcul…":"Voir l’aperçu"}</ActionButton>{preview?<div className="article-folder-preview" role="status"><strong>{preview.count} élément{preview.count>1?"s":""} correspondant{preview.count>1?"s":""}</strong><ul>{preview.records.map(record=><li key={record.id}>{record.label || "—"}</li>)}</ul></div>:null}</section>:<p className="article-folder-note">Les éléments seront ajoutés depuis leur fiche 360 ou une sélection dans le registre.</p>}
    </fieldset>
  </RecordEditorFrame>;
}

export function FolderCategories({categories,available,canWrite,onClose}) {
  const [items,setItems]=useState(categories),[name,setName]=useState(""),[colour,setColour]=useState("bleu"),[saving,setSaving]=useState(false),[error,setError]=useState("");
  const {refresh}=useFollowupFolders();
  const mutation=useRef(false),editing=useRef(Boolean(canWrite && available));
  if(canWrite && available)editing.current=true;
  const dirty=name!=="" || colour!=="bleu";
  async function submit(){
    if(mutation.current || !name.trim() || !canWrite || !available)return;
    mutation.current=true;setSaving(true);setError("");
    try {
      const result=await requestJson("/api/logistique/dossiers-suivi/categories",{method:"POST",body:{name:name.trim(),colour}});
      if(!result.success){setError(result.message || "La catégorie n’a pas été créée.");return;}
      setItems(current=>[...current,result.data]);setName("");setColour("bleu");refresh();
    } catch {setError("La catégorie n’a pas été créée. Réessayez.");}
    finally {mutation.current=false;setSaving(false);}
  }
  const content=!available?<p className="article-folder-note">Les catégories personnalisées ne sont pas encore activées.</p>:<><ul className="article-folder-category-list">{items.map(item=><li key={item.ID_CategorieDossierSuivi} className={"tone-"+item.Couleur}><span/><strong>{item.Nom}</strong></li>)}</ul>{!items.length?<p className="article-folder-note">Aucune catégorie personnalisée.</p>:null}{editing.current?<fieldset className="article-folder-form article-folder-new-category article-folder-fieldset" disabled={saving || !canWrite}><h3>Nouvelle catégorie</h3><label><span>Nom</span><input maxLength={80} required value={name} onChange={event=>setName(event.target.value)} placeholder="Ex. : Approvisionnement"/></label><ColourPicker label="Couleur de la catégorie" value={colour} onChange={setColour}/></fieldset>:null}</>;
  if(!editing.current)return <DrawerDialog title="Catégories de dossiers" icon="tag" onClose={onClose} storageKey="sauverndeko.folder-categories.width" defaultWidth={680} closeLabel="Fermer les catégories" footer={<footer className="article-folder-form-footer"><ActionButton onClick={onClose}>Fermer</ActionButton></footer>}>{content}</DrawerDialog>;
  return <RecordEditorFrame title="Catégories de dossiers" icon="tag" onClose={onClose} onSubmit={submit} busy={saving} dirty={dirty} canSubmit={canWrite && available && Boolean(name.trim())} error={error} storageKey="sauverndeko.folder-categories.width">{content}</RecordEditorFrame>;
}
