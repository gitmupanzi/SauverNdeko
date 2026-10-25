import RegisterCategoryFilter from "../../components/RegisterCategoryFilter";
import { useCallback, useId, useRef, useState } from "react";
import AppIcon from "../../components/AppIcon";
import ActionButton from "../../components/ActionButton";
import SearchSelect from "../../components/SearchSelect";
import RowActionsMenu from "../../components/RowActionsMenu";
import { FolderEditor, FolderCategories } from "../../components/FollowupFolderWidgets";
import { useConsultations, useRead, ResultTable } from "../../components/ConsultationProvider";
import { useFollowupFolders } from "../../contexts/FollowupFoldersContext";
import FollowupFolderCollection from "../../components/FollowupFolderCollection";
import { folderRequest, FOLDER_VIEWS, FOLDER_OBJECT_LABELS as OBJECT_LABELS } from "../../services/followupFolders";
import { useAuth } from "../../contexts/AuthContext";
import { moduleRights } from "../../services/moduleAccess";
import "../../components/FollowupFolders.css";
const BASE="/api/logistique/dossiers-suivi";
const ARTICLE_FIELDS=["CodeArticleInterne","NomArticle","CategorieArticle","QteArticle","QteMinArticle","EtatStock","DatePeremptionArticle","EtatPeremption"];
const BON_FIELDS=["CodeCmd","DateCmd","TypeCmd","StatutCmd","NomClientSaisi","NbLignes","MontantTTC","EtatPaiement"];
const INVOICE_FIELDS=["CodeFacture","CodeCmd","DateFacture","DateEcheancePaiement","NomClientSaisi","MontantTTC","MontantRegleFacture","MontantResteFacture"];
function normalizeSearch(value){return String(value ?? "").normalize("NFD").replace(/\p{M}/gu,"").toLocaleLowerCase("fr").trim();}
export default function DossiersSuivi({references,folderKey,onSelect,onNavigateRecords}) {
  const selectPrefix=useId();
  const {version,refresh}=useFollowupFolders();
  const {user}=useAuth();
  const mayWrite=Boolean(user?.permissions?.canWriteData && moduleRights(user,"logistique").canManage);
  const onSelectRef=useRef(onSelect);
  onSelectRef.current=onSelect;
  const closeEditor=useCallback(()=>setEditor(null),[]);
  const closeCategories=useCallback(()=>setCategoryEditor(false),[]);
  const savedFolder=useCallback(folder=>{setEditor(null);setArchived(false);onSelectRef.current(folder.key);},[]);
  const [view,setView]=useState(()=>{try{const saved=localStorage.getItem("sauverndeko.followupFolders.view");return FOLDER_VIEWS.some(item=>item.key===saved)?saved:"table";}catch{return "table";}});
  const activeView=FOLDER_VIEWS.find(item=>item.key===view);
  const changeView=key=>{setView(key);try{localStorage.setItem("sauverndeko.followupFolders.view",key);}catch{/* Préférence de session si le stockage est indisponible. */}};
  const [archived,setArchived]=useState(false),[search,setSearch]=useState(""),[mode,setMode]=useState("all"),[category,setCategory]=useState(""),[objectType,setObjectType]=useState("all");
  const [editor,setEditor]=useState(null),[categoryEditor,setCategoryEditor]=useState(false),[error,setError]=useState("");
  const remote=useRead(BASE+(archived?"?archived=true":""),version);
  const data=remote.payload?.success && remote.payload.data.archived===archived?remote.payload.data:null;
  const canWrite=Boolean(data?.canWrite && mayWrite);
  const folders=data?.folders || [];
  const searchText=normalizeSearch(search);
  const visible=folders.filter(folder=>(objectType==="all" || folder.objectType===objectType) && (!searchText || normalizeSearch(folder.name+" "+folder.category).includes(searchText)) && (mode==="all" || (mode==="standard"?folder.system:!folder.system)) && (!category || folder.category===category));
  const categories=[...new Set(folders.map(folder=>folder.category))];
  async function toggleArchive(folder){if(!canWrite)return;setError("");const response=await folderRequest(BASE+"/"+folder.key,{method:"PATCH",body:{version:folder.version,active:!folder.active}});if(!response.success){setError(response.message || "Le dossier n’a pas été mis à jour.");return;}refresh();}
  const title=folderKey?"Dossier de suivi":"Dossiers de suivi";
  return <div className="article-folders-screen"><header className="article-folders-title"><div><h1>{title}</h1>{!folderKey?<p>Articles, bons de stock et factures à suivre.</p>:null}</div>{!folderKey?<div><ActionButton icon="tag" disabled={remote.loading || !data} onClick={()=>setCategoryEditor(true)}>Catégories</ActionButton><ActionButton icon="plus" variant="primary" disabled={!canWrite} title={!data?.customAvailable?"Les dossiers personnalisés ne sont pas encore activés.":!canWrite?"Accès en consultation":"Nouveau dossier"} onClick={()=>setEditor({})}>Nouveau dossier</ActionButton></div>:null}</header>
    {error?<p className="article-folder-error" role="alert">{error}</p>:null}
    {folderKey?<FolderDetail key={folderKey} folderKey={folderKey} folder={folders.find(folder=>folder.key===folderKey)} canWrite={canWrite} onBack={()=>onSelect("")} onNavigateRecords={onNavigateRecords}/>:<>
      <RegisterCategoryFilter className="is-standalone" label="Données" value={objectType} options={[["all","Tous les dossiers"],...Object.entries(OBJECT_LABELS)].map(([value,label])=>({value,label:label+(data?" ("+folders.filter(folder=>value==="all"||folder.objectType===value).length+")":"")}))} onChange={setObjectType}/>
      <section className="article-folders-toolbar"><label><AppIcon name="search"/><input aria-label="Rechercher un dossier" type="search" placeholder="Rechercher un dossier…" value={search} onChange={event=>setSearch(event.target.value)}/></label><div className="article-folders-filter"><SearchSelect id={selectPrefix+"-mode"} label="Type de dossier" value={mode} options={[{value:"all",label:"Tous les dossiers"},{value:"standard",label:"Standards"},{value:"custom",label:"Personnalisés"}]} onChange={setMode}/></div><div className="article-folders-filter"><SearchSelect id={selectPrefix+"-category"} label="Catégorie de dossiers" value={category} options={[{value:"",label:"Toutes les catégories"},...categories.map(name=>({value:String(name),label:name}))]} onChange={setCategory}/></div><ActionButton icon="reset" disabled={!search && mode==="all" && !category && objectType==="all"} onClick={()=>{setSearch("");setMode("all");setCategory("");setObjectType("all");}}>Réinitialiser</ActionButton><RowActionsMenu label="Affichage des dossiers" triggerText={activeView.label} triggerIcon={activeView.icon} selectedValue={view} items={FOLDER_VIEWS.map(item=>({label:item.label,icon:item.icon,value:item.key,onSelect:()=>changeView(item.key)}))}/><button className={"article-folders-archive"+(archived?" is-active":"")} aria-pressed={archived} onClick={()=>{setArchived(value=>!value);setCategory("");}}>Archives</button></section>
      {remote.loading?<p className="article-folder-note" role="status">Chargement des dossiers…</p>:null}
      {remote.payload && !remote.payload.success?<div className="article-folder-error" role="alert">{remote.payload.message || "Les dossiers ne sont pas disponibles."}<ActionButton icon="refresh" onClick={remote.retry}>Réessayer</ActionButton></div>:null}
      {data && !data.customAvailable?<p className="article-folder-note article-folder-install-note">Les dossiers automatiques sont disponibles. Les dossiers personnalisés ne sont pas encore activés.</p>:null}
      {data && visible.length?<FollowupFolderCollection folders={visible} view={view} onSelect={onSelect} canWrite={canWrite} onEdit={setEditor} onArchive={toggleArchive}/>:null}
      {data && !visible.length?<p className="article-folder-empty">{archived?"Aucun dossier archivé.":"Aucun dossier pour ces critères."}</p>:null}
    </>}
    {editor?<FolderEditor folder={editor.key?editor:null} defaultObjectType={objectType==="all"?"article":objectType} categories={data?.categories || []} references={references} canWrite={canWrite} onClose={closeEditor} onSaved={savedFolder}/>:null}
    {categoryEditor?<FolderCategories categories={data?.categories || []} available={Boolean(data?.customAvailable)} canWrite={canWrite} onClose={closeCategories}/>:null}
  </div>;
}
function FolderDetail({folderKey,folder,canWrite,onBack,onNavigateRecords}) {
  const {version,refresh}=useFollowupFolders();
  const {openProduct,openOrder}=useConsultations();
  const [query,setQuery]=useState({take:25,skip:0}),[selection,setSelection]=useState([]),[reset,setReset]=useState(0),[busy,setBusy]=useState(false),[error,setError]=useState("");
  const remote=useRead(BASE+"/"+folderKey+"?"+new URLSearchParams(query),version);
  const selectedFolder=remote.payload?.meta?.folder || folder;
  async function remove(){if(!selection.length || !canWrite || !window.confirm("Retirer "+selection.length+" élément(s) de ce dossier ?"))return;setBusy(true);setError("");const result=await folderRequest(BASE+"/"+folderKey+"/membres",{method:"PUT",body:{objectType:selectedFolder.objectType,recordIds:selection.map(row=>selectedFolder.objectType==="article"?row.ID_Article:row.ID_Commande),operation:"retirer"}});setBusy(false);if(!result.success){setError(result.message || "Le retrait a échoué.");return;}setReset(value=>value+1);setSelection([]);refresh();}
  return <><div className="article-folder-detail-heading"><ActionButton icon="chevron-left" onClick={onBack}>Tous les dossiers</ActionButton>{selectedFolder?<div className={"article-folder-detail-name tone-"+selectedFolder.colour}><AppIcon name="folder" size={23}/><div><h2>{selectedFolder.name}</h2><p>{OBJECT_LABELS[selectedFolder.objectType]} · {selectedFolder.category} · {selectedFolder.mode==="automatique"?"Automatique":"Manuel"}</p></div></div>:null}{selectedFolder?.mode==="manuel" && canWrite?<ActionButton icon="plus" onClick={()=>onNavigateRecords(selectedFolder.objectType)}>Sélectionner des éléments</ActionButton>:null}</div>
    {selectedFolder?.description?<p className="article-folder-note">{selectedFolder.description}</p>:null}
    {selection.length?<div className="erp-register-selection"><strong>{selection.length} élément(s) sélectionné(s)</strong><ActionButton icon="close" onClick={remove} disabled={busy}>Retirer du dossier</ActionButton></div>:null}
    {error?<p className="article-folder-error" role="alert">{error}</p>:null}
    <section className="article-folder-detail-table"><ResultTable remote={remote} query={query} onQueryChange={patch=>setQuery(current=>({...current,...patch}))} fields={selectedFolder?.objectType==="article"?ARTICLE_FIELDS:selectedFolder?.objectType==="facture"?INVOICE_FIELDS:BON_FIELDS} kind={selectedFolder?.objectType==="article"?"produit":"commande"} open={(kind,id,label)=>kind==="produit"?openProduct({ID_Article:id,NomArticle:label}):openOrder({ID_Commande:id,CodeCmd:label})} exportPath={BASE+"/"+folderKey+"/export.xlsx"} onSelectionChange={selectedFolder?.mode==="manuel" && canWrite?setSelection:undefined} selectionResetKey={reset}/></section>
  </>;
}
