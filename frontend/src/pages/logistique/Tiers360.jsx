import {useEffect,useId,useRef,useState} from "react";
import {useAuth} from "../../contexts/AuthContext";
import {tabRights} from "../../services/moduleAccess";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import {useConsultations} from "../../components/ConsultationProvider";
import DrawerDialog from "../../components/DrawerDialog";
import ConsultationTabs from "../../components/ConsultationTabs";
import DataTableToolbar from "../../components/DataTableToolbar";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import {requestJson} from "../../services/api";
import {tiersRequest,tiersRecord,tiersRows,natureLabel} from "../../services/tiers";
import {SimpleTable,formatDate,formatCurrency} from "./logistiqueShared";
import TiersEditor from "./TiersEditor";
import ReglementEditor from "./ReglementEditor";
import "./Tiers.css";
const SECTIONS=[{key:"identite",label:"Identité",icon:"user"},{key:"bons",label:"Bons de stock",icon:"receipt"},{key:"factures",label:"Factures",icon:"document"},{key:"reglements",label:"Règlements",icon:"wallet"}];
export default function Tiers360({tiersId,onClose,onChanged}){
  const {user}=useAuth(),scope=useEntityScope(),consult=useConsultations(),prefix=useId(),columnsRef=useRef(null);
  const sections=SECTIONS.filter(item=>item.key==="identite"||tabRights(user,"logistique",item.key==="bons"?"commandes":item.key).canRead);
  const [record,setRecord]=useState(null),[recordMeta,setRecordMeta]=useState(null),[active,setActive]=useState("identite"),[revision,setRevision]=useState(0),[editor,setEditor]=useState(false),[payment,setPayment]=useState(null);
  const [headerLoading,setHeaderLoading]=useState(true),[headerError,setHeaderError]=useState(""),[rows,setRows]=useState([]),[meta,setMeta]=useState(null),[loading,setLoading]=useState(false),[error,setError]=useState("");
  const [search,setSearch]=useState(""),[query,setQuery]=useState(""),[grid,setGrid]=useState({take:25,skip:0}),[density,setDensity]=useState("compact"),[columnsOpen,setColumnsOpen]=useState(false);
  useEffect(()=>{let live=true;setHeaderLoading(true);setHeaderError("");tiersRequest("/"+tiersId).then(response=>{if(!live)return;setHeaderLoading(false);if(!response?.success){setRecord(null);setHeaderError(response?.message||"La fiche n’est pas disponible.");return;}setRecord(tiersRecord(response));setRecordMeta(response.meta||{});});return()=>{live=false;};},[tiersId,revision,scope.scopeKey]);
  useEffect(()=>{let live=true;setRows([]);setMeta(null);setError("");if(active==="identite"||!record)return()=>{live=false;};setLoading(true);const params=new URLSearchParams({...grid,q:query});requestJson("/api/logistique/consultations/tiers/"+tiersId+"/"+active+"?"+params,{requiresAuth:true}).then(response=>{if(!live)return;setLoading(false);if(!response?.success){setError(response?.message||"Les données ne sont pas disponibles.");return;}setRows(tiersRows(response));setMeta({...response.meta,filteredCount:response.meta?.filteredCount??response.meta?.totalCount??0});});return()=>{live=false;};},[tiersId,active,record?.ID_Client,query,grid,revision,scope.scopeKey]);
  function choose(key){setRows([]);setMeta(null);setError("");setLoading(key!=="identite");setActive(key);setSearch("");setQuery("");setGrid({take:25,skip:0});setColumnsOpen(false);}
  function changed(){setEditor(false);setRevision(x=>x+1);onChanged?.();}
  function openRelated(row){if(active==="reglements")setPayment(row.ID_Reglement);else if(active==="factures")consult.openOrderInvoice(row);else consult.openOrder(row);}
  const columns=active==="reglements"?[
    {key:"DateReglement",label:"Date et heure",width:180,render:row=>formatDate(row.DateReglement)},
    {key:"CodeFactureFk",label:"Facture",width:160},
    {key:"ModeReglement",label:"Mode de règlement",width:170,render:row=>row.ModeReglement||row.NomModeReglement||"—"},
    {key:"MontantRegle",label:"Montant",width:160,align:"right",render:row=>formatCurrency(row.MontantRegle,row.DeviseCode)},
  ]:active==="factures"?[
    {key:"CodeFacture",label:"Facture",width:170},{key:"DateFacture",label:"Date et heure",width:180,render:row=>formatDate(row.DateFacture)},
    {key:"MontantFacture",label:"Facturé",width:170,align:"right",render:row=>formatCurrency(row.MontantFacture??row.MontantTTC,row.DeviseCode)},
    {key:"Reste",label:"Solde à régler",width:170,align:"right",render:row=>formatCurrency(row.Reste??row.MontantResteFacture,row.DeviseCode)},
  ]:[{key:"CodeCmd",label:"Bon de stock",width:170},{key:"DateCmd",label:"Date et heure",width:180,render:row=>formatDate(row.DateCmd)},{key:"TypeCmd",label:"Type",width:140},{key:"StatutCmd",label:"Statut",width:150},{key:"MontantTTC",label:"Montant TTC",width:170,align:"right",render:row=>formatCurrency(row.MontantTTC,row.DeviseCode)}];
  columns.push({key:"actions",label:"Actions",width:95,sortable:false,render:row=><ActionButton icon="eye" className="is-icon" aria-label="Consulter" onClick={()=>openRelated(row)}/>});
  return <><DrawerDialog title="Tiers 360" subtitle={record?.Nom||"Client ou fournisseur"} icon="user" onClose={onClose} defaultWidth={1100} storageKey="sauverndeko.tiers.360.width" bodyClassName="tiers-360-body">
    {headerLoading?<p role="status">Chargement de la fiche…</p>:null}{headerError?<p className="record-editor-error" role="alert">{headerError}<ActionButton onClick={()=>setRevision(x=>x+1)}>Réessayer</ActionButton></p>:null}
    {record?<><div className="tiers-identity"><span><AppIcon name={record.Nature==="entreprise"?"apps":"user"} size={27}/></span><div><h3>{record.Nom}</h3><p>{natureLabel(record.Nature)} · {record.TypeClient||"Type non renseigné"}</p><span className={"erp-status is-"+(record.Actif===false?"neutral":"success")}>{record.Actif===false?"Archivé":"Actif"}</span></div>{scope.canWrite&&tabRights(user,"logistique","tiers").canManage&&recordMeta?.canEdit!==false?<ActionButton icon="edit" onClick={()=>setEditor(true)}>Modifier</ActionButton>:null}</div>
      <ConsultationTabs tabs={sections} value={active} onChange={choose} idPrefix={prefix} label="Rubriques du tiers"/>
      <section role="tabpanel" id={prefix+"-panel-"+active} aria-labelledby={prefix+"-tab-"+active} className="tiers-360-related">
      {active==="identite"?<dl className="tiers-overview">{[["Email","Adresse e-mail"],["Telephone","Téléphone"],["Adresse","Adresse"],["TypeClient","Type de tiers"],["NomEntite","Entreprise propriétaire"],["NomEntiteRepresentee","Entreprise représentée"],["NomUtilisateur","Compte utilisateur"],["NomProfessionnel","Professionnel"],["DateCreation","Créé le"],["DateModification","Modifié le"],["ObsClient","Informations complémentaires"]].map(([key,label])=><div key={key} className={key==="ObsClient"?"is-wide":""}><dt>{label}</dt><dd>{key.startsWith("Date")?formatDate(record[key]):record[key]||"—"}</dd></div>)}</dl>:<div className="erp-register-table erp-results" data-density={density} aria-busy={loading}>
        {error?<p className="erp-table-error" role="alert">{error}</p>:null}<SimpleTable key={active} rows={rows} columns={columns} getRowId={row=>active==="reglements"?row.ID_Reglement:row.ID_Commande} serverMeta={meta} serverState={grid} onServerChange={patch=>setGrid(current=>({...current,...patch}))} loading={loading} showSearch={false} defaultPinnedColumns={[]} onRowConsult={openRelated} consultColumns={[active==="bons"?"CodeCmd":active==="factures"?"CodeFacture":"DateReglement"]} columnsPanelOpen={columnsOpen} columnsAnchorRef={columnsRef} onColumnsPanelClose={()=>setColumnsOpen(false)} emptyMessage="Aucune donnée liée à ce tiers." toolbar={<DataTableToolbar showFilters={false} search={search} setSearch={setSearch} onApply={()=>{setQuery(search.trim());setGrid(current=>({...current,skip:0}));}} onReset={()=>{setSearch("");setQuery("");setGrid(current=>({...current,skip:0}));}} pending={search.trim()!==query} take={grid.take} onTake={take=>setGrid(current=>({...current,take,skip:0}))} filtersOpen={false} toggleFilters={()=>document.getElementById(prefix+"-linked-search")?.focus()} activeFilters={Number(Boolean(query))} density={density} toggleDensity={()=>setDensity(current=>current==="compact"?"airy":"compact")} columnsOpen={columnsOpen} columnsButtonRef={columnsRef} toggleColumns={()=>setColumnsOpen(current=>!current)} loading={loading} placeholder="Rechercher dans les données du tiers…"/>}/>
      </div>}
      </section></>:null}
  </DrawerDialog>{editor?<TiersEditor tiersId={tiersId} onClose={()=>setEditor(false)} onSaved={changed}/>:null}{payment!=null?<ReglementEditor reglementId={payment} readOnly onClose={()=>setPayment(null)} onSaved={()=>setPayment(null)}/>:null}</>;
}
