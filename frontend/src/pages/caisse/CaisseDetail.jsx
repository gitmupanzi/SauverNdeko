import {useEffect,useState} from "react";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import {requestJson} from "../../services/api";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import AppIcon from "../../components/AppIcon";
import ActionButton from "../../components/ActionButton";
import {formatDate} from "../logistique/logistiqueShared";
import {formatCurrency} from "../../utils/money";
import {CAISSE_ROOT,CAISSE_REGISTERS} from "./caisseModel";
import {CaisseStatus} from "./CaisseRegister";

export default function CaisseDetail({kind,id,context,onClose,onOpen,onNavigate}){
 const scope=useEntityScope(),[retry,setRetry]=useState(0),[state,setState]=useState({key:"",data:null,loading:true,error:""}),key=scope.scopeKey+":"+kind+":"+id+":"+retry,current=state.key===key?state:{data:null,loading:true,error:""},data=current.data,record=data?.record;
 useEffect(()=>{const controller=new AbortController();setState({key,data:null,loading:true,error:""});requestJson(CAISSE_ROOT+"/"+kind+"/"+encodeURIComponent(id),{requiresAuth:true,signal:controller.signal}).then(response=>{if(controller.signal.aborted)return;setState({key,data:response?.success?response.data:null,loading:false,error:response?.success?"":response?.message||"La fiche n’a pas pu être chargée."});});return()=>controller.abort();},[key]);
 const manage=context?.canManage===true&&!context?.readOnly&&Boolean(scope.entityId),entry=kind==="ecritures",cash=kind==="caisses",title=cash?"Caisse":entry?"Écriture de caisse":"Clôture de caisse";
 function line(label,value){return value!=null&&value!==""?<div key={label}><dt>{label}</dt><dd>{value}</dd></div>:null;}
 return <RecordEditorFrame title={title} subtitle={record?.CodeCaisse||record?.CodePaiement||(record?.ID_ClotureCaisse?"CL-"+record.ID_ClotureCaisse:"")} icon={CAISSE_REGISTERS[kind].icon} readOnly loading={current.loading} error={current.error} onClose={onClose} onReload={()=>setRetry(value=>value+1)} defaultWidth={900} className="caisse-detail" storageKey="sauverndeko.caisse.detail.width">
  {record?<>
   <section className="record-editor-section"><div className="caisse-detail-heading"><span className="caisse-detail-icon"><AppIcon name={CAISSE_REGISTERS[kind].icon} size={24}/></span><div><h2>{record.CodeCaisse||record.CodePaiement||"CL-"+record.ID_ClotureCaisse}</h2><p>{cash?record.NomCaisse:record.LibellePaiement||record.NomCaisse}</p></div>{cash||entry?<CaisseStatus record={record}/>:null}</div>
    <dl className="caisse-summary">{line("Entreprise",record.NomEntite)}{!cash?line("Caisse",record.NomCaisse):null}{line(cash?"Solde disponible":entry?"Montant":"Montant compté",formatCurrency(cash?record.MontantCaisse:entry?record.MontantPaiement:record.MontantCompte,record.DeviseCode))}{line("Devise",record.DeviseCode)}{!cash?line("Date et heure",formatDate(entry?record.DatePaiement:record.ClotureLe)):null}{cash?line("Responsable",record.Responsable||"Non affecté"):null}{entry?line("Mouvement",String(record.SensMouvement)==="1"?"Encaissement":"Décaissement"):null}{line("Référence",record.ReferenceExterne)}{line("Tiers",record.NomTiers)}{line("Auteur",record.Auteur)}{line("Validateur",record.Validateur)}{kind==="clotures"?<>{line("Solde théorique",formatCurrency(record.SoldeTheorique,record.DeviseCode))}{line("Écart constaté",formatCurrency(record.Ecart,record.DeviseCode))}</>:null}{line("Motif",record.Motif)}{line("Observations",record.ObsPaiement)}</dl>
   </section>
   {manage||cash?<section className="record-editor-section"><h3><AppIcon name="list"/>Actions</h3><div className="caisse-detail-actions">
    {cash?<ActionButton icon="movements" onClick={()=>{onClose();onNavigate("ecritures",{filters:{IdCaisseFk:String(record.IdCaisse)}});}}>Consulter le journal</ActionButton>:null}
    {cash&&manage&&data.canManage?<><ActionButton icon="edit" onClick={()=>onOpen({kind,id,mode:"edit"})}>Modifier</ActionButton><ActionButton icon="plus" variant="primary" disabled={record.Actif===false} onClick={()=>onOpen({kind:"ecritures",mode:"create",defaults:{IdCaisseFk:record.IdCaisse}})}>Nouvelle écriture</ActionButton><ActionButton icon="check-circle" disabled={record.Actif===false} onClick={()=>onOpen({kind:"clotures",mode:"create",defaults:{IdCaisseFk:record.IdCaisse}})}>Clôturer la caisse</ActionButton></>:null}
    {entry&&manage&&data.canManage?<ActionButton icon="edit" onClick={()=>onOpen({kind,id,mode:"edit"})}>Modifier le brouillon</ActionButton>:null}
    {entry&&manage&&data.canValidate?<ActionButton icon="check-circle" variant="primary" onClick={()=>onOpen({kind,id,mode:"valider"})}>Valider</ActionButton>:null}
    {entry&&manage&&data.canReverse?<ActionButton icon="reset" onClick={()=>onOpen({kind,id,mode:"contrepasser"})}>Contrepasser</ActionButton>:null}
   </div>{entry&&record.EtatEcriture==="POSTED"?<p className="record-editor-note">L’écriture est définitive. Une contrepassation conserve sa trace et enregistre le mouvement inverse.</p>:null}{kind==="clotures"?<p className="record-editor-note">Le comptage et son écart sont conservés sans modification du solde.</p>:null}</section>:null}
   {entry&&(record.IdPaiementOrigineFk||record.IdCompensateurFk||record.IdReglementFk)?<section className="record-editor-section"><h3><AppIcon name="clock"/>Écritures liées</h3><div className="caisse-detail-actions">{record.IdPaiementOrigineFk?<ActionButton icon="document" onClick={()=>onOpen({kind:"ecritures",id:record.IdPaiementOrigineFk})}>Écriture d’origine</ActionButton>:null}{record.IdCompensateurFk?<ActionButton icon="document" onClick={()=>onOpen({kind:"ecritures",id:record.IdCompensateurFk})}>{record.CodeCompensateur||"Écriture de contrepassation"}</ActionButton>:null}</div>{record.IdReglementFk?<p className="record-editor-note">Liée à un règlement de la logistique. Les corrections se font depuis ce règlement.</p>:null}</section>:null}
  </>:null}
 </RecordEditorFrame>;
}
