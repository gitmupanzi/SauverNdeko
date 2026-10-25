import AppIcon from "./AppIcon";
import ActionButton from "./ActionButton";
import {formatCurrency,formatDate,formatNumber,SimpleTable} from "../pages/logistique/logistiqueShared";

export default function OrderReturnHistory({remote,onOpen,onReturn,canWrite=false}) {
  const payload=remote.payload,data=payload?.data,meta=payload?.meta;
  if(!payload&&remote.loading)return <div className="commande360-placeholder" role="status">Chargement des restitutions…</div>;
  if(!payload?.success)return <div className="consult-state" role="alert"><p>{payload?.message||"Les restitutions n’ont pas pu être chargées."}</p><ActionButton icon="refresh" onClick={remote.retry}>Réessayer</ActionButton></div>;
  const lines=data.lignes||[],history=data.retours||[],currency=data.bonOrigine?.DeviseCode;
  const columns=[
    {key:"NomArticle",label:"Article",width:240,render:row=><strong>{row.NomArticle||"Article"}</strong>},
    {key:"QteSortie",label:"Sortie",align:"right",width:130,render:row=>formatNumber(row.QteSortie)+(row.AbrUnite?" "+row.AbrUnite:"")},
    {key:"QteDejaRetournee",label:"Restituée",align:"right",width:130,render:row=>formatNumber(row.QteDejaRetournee)},
    {key:"QteRestante",label:"Restante",align:"right",width:130,render:row=>formatNumber(row.QteRestante)},
    {key:"PUHistorique",label:"Prix de sortie",align:"right",width:160,render:row=>formatCurrency(row.PUHistorique,row.DeviseCode||currency)},
  ];
  const events=[
    {key:"CodeCmd",label:"Bon de retour",width:180,render:row=><button type="button" className="erp-object-link" onClick={()=>onOpen("commande",row.ID_CommandeRetourFk,row.CodeCmd)}>{row.CodeCmd||"Consulter"}</button>},
    {key:"DateRetour",label:"Date et heure",width:190,render:row=>formatDate(row.DateRetour)},
    {key:"Motif",label:"Motif",width:260},
    {key:"NbLignes",label:"Articles",width:100,align:"right",render:row=>formatNumber(row.NbLignes)},
    {key:"MontantTTC",label:"Valeur restituée",width:170,align:"right",render:row=>formatCurrency(row.MontantTTC,row.DeviseCode||currency)},
    {key:"NomComplet",label:"Enregistré par",width:190},
  ];
  return <div className="commande360-returns" aria-busy={remote.loading}>
    <section className="commande360-group"><div className="commande360-section-heading"><h4><AppIcon name="movements"/>Quantités restituées</h4>{canWrite&&meta?.canReturn&&onReturn?<ActionButton icon="stock-in" onClick={onReturn}>Restituer des articles</ActionButton>:null}</div>
      {meta?.reason?<p className="commande360-muted">{meta.reason}</p>:null}
      {meta?.requiresCreditNote?<p className="commande360-return-notice"><AppIcon name="alert"/>Un retour après émission nécessite un avoir. La facture d’origine reste conservée.</p>:null}
      {lines.length?<div className="erp-results" data-density="compact"><SimpleTable rows={lines} columns={columns} defaultPinnedColumns={[]} showControls={false} toolbar={<></>}/></div>:null}
    </section>
    <section className="commande360-group"><h4><AppIcon name="clock"/>Historique des restitutions <span className="erp-count">{history.length}</span></h4>
      {history.length?<div className="erp-results" data-density="compact"><SimpleTable rows={history} columns={events} defaultPinnedColumns={[]} showControls={false} toolbar={<></>}/></div>:<p className="commande360-muted">Aucune restitution enregistrée.</p>}
    </section>
  </div>;
}
