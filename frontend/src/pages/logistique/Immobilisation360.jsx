import {useEffect,useId,useRef,useState} from "react";
import {useAuth} from "../../contexts/AuthContext";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import {tabRights} from "../../services/moduleAccess";
import {downloadApiFile} from "../../services/api";
import {immobilisationsRequest,immobilisationRecord,immobilisationPdf} from "../../services/immobilisations";
import DrawerDialog from "../../components/DrawerDialog";
import ConsultationTabs from "../../components/ConsultationTabs";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import ImmobilisationEditor from "./ImmobilisationEditor";
import ImmobilisationCycle, {ASSET_EVENT_LABELS} from "./ImmobilisationCycle";
import ImmobilisationValuation from "./ImmobilisationValuation";
import {assetCycleLabel,immobilisationLocation} from "./immobilisationForm";
import {immobilisationAuditImage,immobilisationChanges} from "./immobilisationHistory";
import {SimpleTable,formatDate,formatNumber,formatCurrency} from "./logistiqueShared";
import "./Immobilisations.css";

const TABS=[{key:"synthese",label:"Synthèse",icon:"building"},{key:"affectation",label:"Affectation",icon:"user"},{key:"acquisition",label:"Acquisition",icon:"cash"},{key:"cycle",label:"Cycle de vie",icon:"list"},{key:"valorisation",label:"Valorisation",icon:"chart"},{key:"historique",label:"Historique",icon:"clock"}];
const operationLabel=value=>({CREATE:"Création",UPDATE:"Modification",ARCHIVE:"Archivage",RESTORE:"Réactivation",INSERT:"Création"})[value]||"Modification";
const auditData=row=>immobilisationAuditImage(row?.NewData);
export function ImmobilisationHistoryChanges({row}){
 const changes=immobilisationChanges(row);
 return changes.length?<ul className="immobilisation-history-changes">{changes.map(change=><li key={change.key}><strong>{change.label} : </strong><span>{change.creation?change.after:<>{change.before}<span className="immobilisation-history-arrow" aria-label="devient"> → </span>{change.after}</>}</span></li>)}</ul>:"—";
}
export default function Immobilisation360({recordId,onClose,onChanged,references}){
 const {user}=useAuth(),scope=useEntityScope(),prefix=useId(),identity=String(user?.IdUser??"")+":"+scope.scopeKey+":"+recordId,current=useRef(identity),download=useRef(null);current.current=identity;
 const [snapshot,setSnapshot]=useState(null),[loading,setLoading]=useState(true),[error,setError]=useState(""),[revision,setRevision]=useState(0),[active,setActive]=useState("synthese"),[editor,setEditor]=useState(null);
 const [history,setHistory]=useState(null),[historyLoading,setHistoryLoading]=useState(false),[historyError,setHistoryError]=useState(""),[grid,setGrid]=useState({take:25,skip:0}),[exporting,setExporting]=useState(false),[exportError,setExportError]=useState("");
 const ready=snapshot?.identity===identity,record=ready?snapshot.record:null,meta=ready?snapshot.meta:null,historyRows=history?.identity===identity?history.rows:[],historyMeta=history?.identity===identity?history.meta:null;
 const canExport=user?.permissions?.canExportData!==false&&tabRights(user,"logistique","immobilisations").canExport===true&&meta?.canExport!==false;
 const writable=scope.canWrite&&meta?.canWrite===true&&!loading&&!error;
 const canEdit=writable&&meta?.canEdit===true;
 useEffect(()=>{setEditor(null);setHistory(null);setActive("synthese");setGrid({take:25,skip:0});},[identity]);
 useEffect(()=>{const controller=new AbortController(),key=identity;setLoading(true);setError("");immobilisationsRequest("/"+recordId,{signal:controller.signal}).then(response=>{if(controller.signal.aborted||current.current!==key)return;setLoading(false);const row=immobilisationRecord(response);if(!response?.success||String(row?.ID_Immobilisation)!==String(recordId)){setError(response?.message||"La fiche n’a pas pu être chargée.");return;}setSnapshot({identity:key,record:row,meta:response.meta||{}});});return()=>controller.abort();},[identity,revision]);
 useEffect(()=>{const controller=new AbortController(),key=identity;setHistoryError("");if(active!=="historique"||!ready)return()=>controller.abort();setHistoryLoading(true);immobilisationsRequest("/"+recordId+"/historique?"+new URLSearchParams(grid),{signal:controller.signal}).then(response=>{if(controller.signal.aborted||current.current!==key)return;setHistoryLoading(false);if(!response?.success){setHistory(null);setHistoryError(response?.message||"L’historique n’a pas pu être chargé.");return;}setHistory({identity:key,rows:Array.isArray(response.data)?response.data:[],meta:{...response.meta,filteredCount:response.meta?.filteredCount??response.meta?.count??0}});});return()=>controller.abort();},[identity,ready,active,grid,revision]);
 useEffect(()=>{download.current?.abort();download.current=null;setExporting(false);setExportError("");return()=>download.current?.abort();},[identity]);
 async function exportPdf(){if(!record||loading||!canExport||download.current)return;const controller=new AbortController();download.current=controller;setExporting(true);setExportError("");try{await downloadApiFile(immobilisationPdf(recordId).url,{signal:controller.signal});}catch(failure){if(!controller.signal.aborted)setExportError(failure.message||"La fiche PDF n’a pas pu être préparée.");}finally{if(download.current===controller){download.current=null;setExporting(false);}}}
 function changed(){setRevision(value=>value+1);onChanged?.();}
 function saved(){setEditor(null);changed();}
 function edit(initialTab="identification"){setEditor({operation:"edit",initialTab});}
 const items=active==="affectation"?[["Responsable",record?.Responsable],["Service",record?.Service],["Localisation",immobilisationLocation(record)],["Entreprise propriétaire",record?.NomEntite]]:active==="acquisition"?[["Date et heure d’entrée",formatDate(record?.DateEntree)],["Date d’acquisition",formatDate(record?.DateAcquisition,{withTime:false})],["Date de mise en service",formatDate(record?.DateMiseEnService,{withTime:false})],["Prix unitaire",formatCurrency(record?.PrixUnitaire,record?.DeviseCode)],["Valeur d’acquisition",formatCurrency(record?.ValeurAcquisition,record?.DeviseCode)]]:[["Type de matériel",record?.CategorieMateriel],["État du matériel",record?.EtatMateriel],["Référence",record?.Reference],["N° de série",record?.NumeroSerie],["Mode de suivi",record?.SuiviIndividuel?"Bien individuel":"Lot homogène"],["Quantité",formatNumber(record?.Quantite)],["Caractéristiques",record?.Caracteristiques],["Observations",record?.Observations]];
 const columns=[{key:"ChangedAt",label:"Date et heure",width:180,render:row=>formatDate(row.ChangedAt)},{key:"Auteur",label:"Auteur",width:190},{key:"Operation",label:"Action",width:150,render:row=>operationLabel(auditData(row).operation||row.Operation)},{key:"changes",label:"Changements",width:360,sortable:false,filterable:false,render:row=><ImmobilisationHistoryChanges row={row}/>},{key:"motif",label:"Motif",width:300,render:row=>auditData(row)._motif||auditData(row).motif||auditData(row).Motif||"—"}];
 return <><DrawerDialog title="Immobilisation 360" subtitle={record?.CodeImmobilisation||"Fiche du bien"} icon="building" onClose={onClose} defaultWidth={1100} storageKey="sauverndeko.immobilisation.360.width" bodyClassName="immobilisation-360-body">
  {loading?<p role="status">Chargement de la fiche…</p>:null}{error?<div className="record-editor-error" role="alert">{error}<ActionButton icon="refresh" onClick={()=>setRevision(value=>value+1)}>Réessayer</ActionButton></div>:null}
  {record?<><div className="immobilisation-identity"><span className="erp-product-avatar"><AppIcon name="building" size={26}/></span><div><p>{record.CategorieMateriel||"Type non renseigné"}</p><h3>{record.NomImmobilisation}</h3><p>{record.CodeImmobilisation}{record.Reference?" · "+record.Reference:""}</p><span className={"erp-status is-"+(record.Actif===false?"neutral":"success")}>{record.Actif===false?"Archivé":"Actif"}</span>{record.StatutCycle?<span className={"erp-status is-"+(record.StatutCycle==="EN_SERVICE"?"success":"neutral")}>{assetCycleLabel(record)}</span>:null}</div><div className="immobilisation-identity-actions">{canEdit?<ActionButton icon="edit" onClick={()=>edit(active==="affectation"?"affectation":active==="acquisition"?"acquisition":"identification")}>Modifier</ActionButton>:null}{canExport?<ActionButton icon="download" disabled={exporting} onClick={exportPdf}>{exporting?"Préparation…":"Fiche PDF"}</ActionButton>:null}{writable&&meta?.[record.Actif===false?"canRestore":"canArchive"]===true?<ActionButton icon={record.Actif===false?"reset":"folder"} onClick={()=>setEditor({operation:record.Actif===false?"restore":"archive"})}>{record.Actif===false?"Réactiver":"Archiver"}</ActionButton>:null}</div></div>
   {record.DateSortie?<p className="record-editor-note">{ASSET_EVENT_LABELS[record.TypeSortie]||"Sortie"} du {formatDate(record.DateSortie,{withTime:false})}.</p>:null}
   {exportError?<p className="erp-table-error" role="alert">{exportError}</p>:null}
   <ConsultationTabs tabs={TABS} value={active} onChange={setActive} label="Rubriques de l’immobilisation" idPrefix={prefix}/>
   <section role="tabpanel" id={prefix+"-panel-"+active} aria-labelledby={prefix+"-tab-"+active}>
    {active==="cycle"?<ImmobilisationCycle key={identity} record={record} writable={writable} onChanged={changed} onAffect={canEdit?()=>edit("affectation"):undefined}/>:active==="valorisation"?<ImmobilisationValuation key={identity} record={record} writable={writable} references={references} onChanged={changed}/>:active==="historique"?<div className="immobilisation-panel"><h3>Historique du bien</h3>{historyError?<p className="erp-table-error" role="alert">{historyError}<ActionButton icon="refresh" onClick={()=>setGrid(previous=>({...previous}))}>Réessayer</ActionButton></p>:null}<SimpleTable rows={historyRows} columns={columns} getRowId={row=>row.IdLog} loading={historyLoading} showSearch={false} showControls={false} defaultPinnedColumns={[]} serverMeta={historyMeta} serverState={grid} onServerChange={patch=>setGrid(previous=>({...previous,...patch}))} emptyMessage="Aucun événement disponible pour ce bien."/></div>:<dl className="immobilisation-overview">{items.map(([label,value])=><div key={label} className={["Caractéristiques","Observations"].includes(label)?"is-wide":""}><dt>{label}</dt><dd>{value??"—"}{value===""?"—":null}</dd></div>)}</dl>}
   </section>
  </>:null}
 </DrawerDialog>{record&&editor?<ImmobilisationEditor recordId={recordId} operation={editor.operation} initialTab={editor.initialTab} onClose={()=>setEditor(null)} onSaved={saved}/>:null}</>;
}
