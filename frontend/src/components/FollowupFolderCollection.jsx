import "./DataTable.css";
import AppIcon from "./AppIcon";
import RowActionsMenu from "./RowActionsMenu";
import {SimpleTable,formatNumber} from "../pages/logistique/logistiqueShared";
import {FOLDER_OBJECT_LABELS,FOLDER_UNITS} from "../services/followupFolders";
export function FolderActions({folder,canWrite,onEdit,onArchive}){
  if(folder.system)return <span className="followup-folder-actions-gap"/>;
  return <RowActionsMenu label={folder.name} items={[{label:"Modifier",icon:"edit",disabled:!canWrite || !folder.active,onSelect:()=>onEdit(folder)},{label:folder.active?"Archiver":"Restaurer",icon:"folder",disabled:!canWrite,onSelect:()=>onArchive(folder)}]}/>;
}
function FolderCount({folder,onSelect}){return <button type="button" className="followup-folder-count" aria-label={"Voir le dossier "+folder.name+" : "+formatNumber(folder.count)+" "+FOLDER_UNITS[folder.objectType]+(folder.count>1?"s":"")} disabled={!folder.active} onClick={()=>onSelect(folder.key)}><span><strong>{formatNumber(folder.count)}</strong><small>{FOLDER_UNITS[folder.objectType]}{folder.count>1?"s":""}</small></span><AppIcon name="chevron-right" size={15}/></button>;}
export default function FollowupFolderCollection({folders,view,onSelect,canWrite,onEdit,onArchive}){
 const actions=folder=><FolderActions folder={folder} canWrite={canWrite} onEdit={onEdit} onArchive={onArchive}/>;
 const name=folder=><button type="button" className="followup-folder-name" disabled={!folder.active} onClick={()=>onSelect(folder.key)}>{folder.name}</button>;
 if(view==="table"){
  const columns=[
   {key:"name",label:"Dossier",width:310,render:folder=><div className={"followup-folder-table-name tone-"+folder.colour}><AppIcon name="folder"/>{name(folder)}</div>},
   {key:"objectType",label:"Données",width:150,sortValue:folder=>FOLDER_OBJECT_LABELS[folder.objectType],render:folder=>FOLDER_OBJECT_LABELS[folder.objectType]},
   {key:"category",label:"Catégorie",width:170},
   {key:"mode",label:"Alimentation",width:145,render:folder=><span className={"erp-status "+(folder.mode==="automatique"?"is-info":"is-neutral")}>{folder.mode==="automatique"?"Automatique":"Manuelle"}</span>},
   {key:"count",label:"Éléments",width:135,align:"right",render:folder=><FolderCount folder={folder} onSelect={onSelect}/>},
   {key:"actions",label:"Actions",width:75,sortable:false,render:actions}
  ];
  return <section className="followup-folders-table erp-results"><SimpleTable columns={columns} rows={folders} getRowId={folder=>folder.key} defaultPinnedColumns={[]} enableSelection={false} defaultRowsPerPage={250} showControls={false} showSearch={false} toolbar={<></>} emptyMessage="Aucun dossier pour ces critères."/></section>;
 }
 if(view==="cards")return <div className="article-folders-grid">{folders.map(folder=><article key={folder.key} className={"article-folder-card tone-"+folder.colour}><header><span className="article-folder-card-icon"><AppIcon name="folder" size={23}/></span><span className="article-folder-mode">{folder.mode==="automatique"?"Automatique":"Manuel"}</span>{actions(folder)}</header><h2>{name(folder)}</h2><p className="article-folder-category">{FOLDER_OBJECT_LABELS[folder.objectType]} · {folder.category}</p><p className="article-folder-description">{folder.description || (folder.mode==="manuel"?"Éléments classés manuellement.":"Éléments correspondant aux critères définis.")}</p><FolderCount folder={folder} onSelect={onSelect}/></article>)}</div>;
 return <ul className={"followup-folder-list"+(view==="compact"?" is-compact":"")} aria-label="Dossiers">{folders.map(folder=><li key={folder.key} className={"tone-"+folder.colour}><span className="followup-folder-list-icon"><AppIcon name="folder" size={21}/></span><div className="followup-folder-list-identity"><h2>{name(folder)}</h2><p className="followup-folder-list-meta"><span>{FOLDER_OBJECT_LABELS[folder.objectType]}</span><span>{folder.category}</span><span className="article-folder-mode">{folder.mode==="automatique"?"Automatique":"Manuel"}</span></p>{view==="list" && folder.description?<p className="followup-folder-list-description">{folder.description}</p>:null}</div><FolderCount folder={folder} onSelect={onSelect}/>{actions(folder)}</li>)}</ul>;
}
