import {useState} from "react";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import BusinessDocuments from "../../components/BusinessDocuments";
import {commandeDateInput} from "./commandeForm";
import {SimpleTable,formatDate,formatNumber} from "./logistiqueShared";
import {AssetActionEditor,AssetSectionStatus,assetOptions,useAssetSection,validAssetDate} from "./ImmobilisationAction";

export const ASSET_EVENT_LABELS={ENTRETIEN:"Entretien",INVENTAIRE:"Inventaire",CESSION:"Cession",REBUT:"Mise au rebut"};
const EVENT_TYPES=assetOptions({ENTRETIEN:ASSET_EVENT_LABELS.ENTRETIEN,INVENTAIRE:ASSET_EVENT_LABELS.INVENTAIRE});
const DISPOSAL_TYPES=assetOptions({CESSION:ASSET_EVENT_LABELS.CESSION,REBUT:ASSET_EVENT_LABELS.REBUT});
const CYCLE_COLUMNS=[
 {key:"DateEvenement",label:"Date",width:115,render:row=>formatDate(row.DateEvenement,{withTime:false})},
 {key:"TypeEvenement",label:"Événement",width:130,render:row=>ASSET_EVENT_LABELS[row.TypeEvenement]||row.TypeEvenement||"—"},
 {key:"Motif",label:"Motif",width:245,render:row=><span className="immobilisation-history-text">{row.Motif||"—"}</span>},
 {key:"QuantiteTheorique",label:"Quantité attendue",width:130,align:"right",render:row=>formatNumber(row.QuantiteTheorique)},
 {key:"QuantiteComptee",label:"Quantité comptée",width:130,align:"right",render:row=>formatNumber(row.QuantiteComptee)},
 {key:"EcartInventaire",label:"Écart",width:100,align:"right",render:row=>formatNumber(row.EcartInventaire)},
 {key:"Observation",label:"Observation",width:210,render:row=><span className="immobilisation-history-text">{row.Observation||"—"}</span>},
 {key:"NomFichier",label:"Justificatif",width:180},
 {key:"Auteur",label:"Auteur",width:150},
 {key:"CreeLe",label:"Enregistré le",width:150,render:row=>formatDate(row.CreeLe)},
];

function validateCycle(values){
 const errors={};
 if(!validAssetDate(values.date))errors.date="Renseignez une date valide.";
 if(!values.motif.trim())errors.motif="Renseignez le motif.";
 if(values.type==="INVENTAIRE"&&!/^\d{1,18}$/.test(values.quantiteComptee.trim()))errors.quantiteComptee="Renseignez une quantité entière positive ou nulle.";
 return errors;
}

export default function ImmobilisationCycle({record,writable,onChanged,onAffect}){
 const section=useAssetSection(record.ID_Immobilisation,"cycle-vie"),[editor,setEditor]=useState(null),[feedback,setFeedback]=useState("");
 const canEvent=writable&&section.meta.canEvent===true;
 const canDispose=writable&&section.meta.canDispose===true;
 const documents=section.data?.documents||[];
 const events=section.data?.events||[];
 const documentOptions=[{value:"",label:"Sans justificatif"},...documents.map(piece=>({value:String(piece.ID_Piece),label:piece.NomFichier}))];
 const disposal=editor==="sortie";
 function saved(){
  setFeedback(disposal?"Sortie du bien enregistrée.":"Événement enregistré.");
  setEditor(null);
  section.reload();
  onChanged?.();
 }
 return <div className="immobilisation-section-stack">
  <section className="immobilisation-panel">
   <div className="immobilisation-panel-heading">
    <div><h3>Événements du bien</h3><p className="record-editor-note">Suivez les entretiens, comptages et sorties du bien.</p></div>
    <div className="immobilisation-panel-actions">
     {onAffect?<ActionButton icon="movements" onClick={onAffect}>Modifier l’affectation</ActionButton>:null}
     {canEvent?<ActionButton icon="plus" onClick={()=>setEditor("suivi")}>Ajouter un événement</ActionButton>:null}
     {canDispose?<ActionButton icon="stock-out" onClick={()=>setEditor("sortie")}>Enregistrer une sortie</ActionButton>:null}
    </div>
   </div>
   {feedback?<p className="immobilisation-feedback" role="status">{feedback}</p>:null}
   <AssetSectionStatus section={section}/>
   {section.data?<SimpleTable rows={events} columns={CYCLE_COLUMNS} getRowId={row=>row.ID_Evenement} showSearch={false} showControls={false} defaultPinnedColumns={[]} emptyMessage="Aucun événement enregistré."/>:null}
  </section>
  {section.data?<BusinessDocuments kind="immobilisation" objectId={record.ID_Immobilisation} canWrite={section.meta.canAttach===true} onChanged={section.reload}/>:null}
  {editor?<AssetActionEditor key={editor} recordId={record.ID_Immobilisation} section="cycle-vie" icon={disposal?"stock-out":"list"}
   title={disposal?"Sortie de l’immobilisation":"Ajouter un événement"} subtitle={record.NomImmobilisation}
   fields={[
    {key:"type",label:"Type d’événement *",options:disposal?DISPOSAL_TYPES:EVENT_TYPES},
    {key:"date",label:"Date *",kind:"date"},
    {key:"quantiteComptee",label:"Quantité comptée *",kind:"integer",maxLength:18,when:values=>values.type==="INVENTAIRE",help:"Le comptage est ajouté à l’historique du bien."},
    {key:"pieceId",label:"Justificatif",options:documentOptions,help:"Sélectionnez un justificatif déjà joint à la fiche."},
    {key:"motif",label:"Motif *",kind:"textarea",wide:true},
    {key:"observation",label:"Observation",kind:"textarea",wide:true,maxLength:4000},
   ]}
   initial={{type:disposal?"CESSION":"ENTRETIEN",date:commandeDateInput(new Date().toISOString()).slice(0,10),motif:"",observation:"",quantiteComptee:"",pieceId:""}}
   validate={validateCycle} payload={values=>({type:values.type,date:values.date,motif:values.motif.trim(),observation:values.observation.trim()||null,quantiteComptee:values.type==="INVENTAIRE"?values.quantiteComptee.trim():null,pieceId:values.pieceId||null,_version:record._version})}
   confirmation={disposal?"Je confirme la sortie du bien. Sa fiche et son historique seront conservés.":undefined}
   submitLabel={disposal?"Confirmer la sortie":"Enregistrer l’événement"} onClose={()=>setEditor(null)} onSaved={saved}
   onStale={()=>{setEditor(null);section.reload();onChanged?.();}}/>:null}
 </div>;
}
