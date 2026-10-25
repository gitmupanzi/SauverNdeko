import AppIcon from "./AppIcon";
import { formatCurrency, formatDate, formatNumber } from "../pages/logistique/logistiqueShared";
import "./OrderOverview.css";

const text=value=>value==null || value==="" ? "—" : String(value);
export const hasOrderInvoice=record=>typeof record?.CodeFacture==="string" && Boolean(record.CodeFacture.trim());
export const ORDER_SECTION_FIELDS={
  lots:["NomArticle","NumeroLot","Quantite","QuantiteSignee","DateMvt","DatePeremptionLot"],
  lignes:["NomArticle","RefArticle","QteCmdDetail","AbrUnite","PUCmdDetail","MontantLigne"],
  mouvements:["DateMvt","NomArticle","NomTypeMvt","QteMvtSigned","PUMvt","MontantMvt","OrigineMouvement"],
  facture:["CodeFacture","DateFacture","DateEcheancePaiement","MontantFacture","TotalRegle","Reste","EtatReglement"],
  reglements:["DateReglement","MontantRegle","CodeFactureFk"],
};
export function orderConsultationTabs(sections=[],{returns=false}={}){
  const available=new Set(sections);
  return [
    {key:"identite",label:"Synthèse",icon:"receipt"},
    ...(available.has("lignes")?[{key:"lignes",label:"Lignes",icon:"list"}]:[]),
    ...(available.has("mouvements")?[{key:"mouvements",label:"Mouvements",icon:"movements"}]:[]),
    ...(available.has("lots")?[{key:"lots",label:"Lots",icon:"box"}]:[]),
    ...(available.has("facture") || available.has("reglements")?[{key:"facturation",label:"Facturation",icon:"wallet"}]:[]),
    ...(returns?[{key:"retours",label:"Restitutions",icon:"movements"}]:[]),
    {key:"controle",label:"Contrôle",icon:"shield"},
  ];
}
export function orderReadSection(section,invoiceSection,record,sections=[]){
  if(section==="facturation")return hasOrderInvoice(record) && sections.includes(invoiceSection) ? invoiceSection : null;
  return ["lots","lignes","mouvements"].includes(section) && sections.includes(section) ? section : null;
}
export function OrderStatus({value}){
  if(value==null || value==="")return <span>—</span>;
  const label=String(value);
  const tone=/incohérent|retard|annul|refus/i.test(label)?"danger":/sans lignes|sans détails|attente|partiel|non facturé|non réglé|à régler/i.test(label)?"warning":/^(cohérent(?:e)?|réglé(?:e)?|soldé(?:e)?|validé(?:e)?|terminé(?:e)?|livré(?:e)?)$/i.test(label)?"success":/en cours|entrée/i.test(label)?"info":"neutral";
  return <span className={"erp-status is-"+tone}>{label}</span>;
}
function Field({label,value,money=false,date=false,numeric=false,code}){
  const shown=money?formatCurrency(value,code):date?formatDate(value):numeric?formatNumber(value):text(value);
  return <div><dt>{label}</dt><dd className={money || numeric?"commande360-number":""}>{shown}</dd></div>;
}
function Group({title,icon,children,className=""}){
  return <section className={"commande360-group "+className}><h4><AppIcon name={icon}/>{title}</h4>{children}</section>;
}
function Metric({label,value,icon,onClick,tone="neutral",note}){
  const Tag=onClick?"button":"div";
  return <Tag {...(onClick?{type:"button",onClick}: {})} className={"commande360-metric is-"+tone}>
    <span className="commande360-metric-label"><AppIcon name={icon}/>{label}{onClick?<AppIcon name="chevron-right" size={13}/>:null}</span>
    <strong>{value}</strong>{note?<small>{note}</small>:null}
  </Tag>;
}
export function OrderHeading({record}){
  const direction=record.EstCommandeEntree===true?"stock-in":record.EstCommandeSortie===true?"stock-out":"receipt";
  return <div className="commande360-hero"><span className="commande360-avatar"><AppIcon name={direction} size={25}/></span>
    <div className="commande360-identity"><p>Bon de stock</p><h3>{record.CodeCmd || "Bon n° "+record.ID_Commande}</h3>
      <div className="commande360-codes">{record.RefCmd?<span>Réf. {record.RefCmd}</span>:null}{record.DateCmd?<span><AppIcon name="calendar" size={13}/>{formatDate(record.DateCmd)}</span>:null}</div>
      <div className="commande360-statuses">{record.TypeCmd?<OrderStatus value={record.TypeCmd}/>:null}{record.StatutCmd?<OrderStatus value={record.StatutCmd}/>:null}{record.EtatPaiement?<OrderStatus value={record.EtatPaiement}/>:null}</div>
    </div>
  </div>;
}
export function OrderInvoiceMetrics({record,onSection}){
  const invoiced=hasOrderInvoice(record),code=record.DeviseCode;
  return <div className="commande360-metrics" aria-label="Situation du bon">
    <Metric label="Lignes" value={formatNumber(record.NbLignes)} icon="list" onClick={onSection?()=>onSection("lignes"):null} note={record.NbArticlesDistincts==null?null:formatNumber(record.NbArticlesDistincts)+" article"+(String(record.NbArticlesDistincts)==="1"?"":"s")+" distinct"+(String(record.NbArticlesDistincts)==="1"?"":"s")}/>
    <Metric label={invoiced?"Montant facturé":"Montant du bon"} value={formatCurrency(invoiced?record.MontantFacture??record.MontantTTC:record.MontantTTC,code)} icon="cash"/>
    <Metric label="Réglé" value={invoiced?formatCurrency(record.TotalRegleReel,code):"—"} icon="check-circle" onClick={invoiced && onSection?()=>onSection("facturation","reglements"):null} note={!invoiced?"Non facturé":null}/>
    <Metric label="Solde à régler" value={invoiced?formatCurrency(record.ResteReel,code):"—"} icon="wallet" onClick={invoiced && onSection?()=>onSection("facturation","facture"):null} tone={record.EstPaiementEnRetard===true?"danger":"neutral"}/>
  </div>;
}
export function OrderBillingHeading({record}){
  if(!hasOrderInvoice(record))return <section className="commande360-empty"><span><AppIcon name="document" size={22}/></span><h4>Aucune facture associée</h4><p>Ce bon n’est pas facturé.</p></section>;
  return <div className="commande360-billing-heading"><span className="commande360-billing-icon"><AppIcon name="document" size={21}/></span><div><p>Facture</p><h4>{record.CodeFacture}</h4></div><OrderStatus value={record.EtatPaiement}/>{record.EstPaiementEnRetard===true?<span className="erp-status is-danger">En retard</span>:null}</div>;
}
export function OrderControl({record,onSection}){
  const content=record.EstCommandeSansDetails===true?"Sans lignes":record.EstCommandeSansDetails===false?"Lignes présentes":"Non déterminé";
  const amount=record.EstMontantIncoherent===true?"Montant incohérent":record.EstMontantIncoherent===false?"Cohérent":"Non déterminé";
  return <div className="commande360-control"><Group title="Contrôle du bon" icon="shield"><div className="commande360-control-status"><OrderStatus value={record.EtatControleCommande}/></div>
    <dl className="commande360-checks"><div><dt>Contenu du bon</dt><dd><OrderStatus value={content}/>{onSection?<button type="button" className="erp-object-link" onClick={()=>onSection("lignes")}>Voir les lignes<AppIcon name="chevron-right" size={13}/></button>:null}</dd></div><div><dt>Cohérence des montants</dt><dd><OrderStatus value={amount}/></dd></div><div><dt>Type de bon</dt><dd>{text(record.TypeCmd)}</dd></div><div><dt>Facturation</dt><dd><OrderStatus value={hasOrderInvoice(record)?"Facturé":"Non facturé"}/></dd></div></dl>
    </Group><Group title="Montants de référence" icon="cash"><dl><Field label="Montant hors taxes" value={record.MontantHT} money code={record.DeviseCode}/><Field label="Total des lignes" value={record.MontantDetails} money code={record.DeviseCode}/><Field label="Écart" value={record.EcartMontantDetails} money code={record.DeviseCode}/><Field label="Devise" value={record.DeviseCode}/></dl></Group>
  </div>;
}
export default function OrderOverview({record,onSection}){
  const invoiced=hasOrderInvoice(record);
  const party=record.EstCommandeEntree===true?"Fournisseur":record.EstCommandeSortie===true?"Client":"Tiers";
  return <div className="commande360-overview"><OrderInvoiceMetrics record={record} onSection={onSection}/>
    <Group title="Informations du bon" icon="receipt"><dl><Field label="Référence" value={record.RefCmd}/><Field label="Date et heure du bon" value={record.DateCmd} date/><Field label={party} value={record.NomClientSaisi}/><Field label="Responsable" value={record.NomComplet}/><Field label="Créé le" value={record.DateHeureAutoCmd} date/><Field label="Devise" value={record.DeviseCode}/></dl></Group>
    <Group title="Facturation" icon="document">{invoiced?<dl><Field label="Facture" value={record.CodeFacture}/><Field label="Montant facturé" value={record.MontantFacture??record.MontantTTC} money code={record.DeviseCode}/><Field label="Valeur du bon d’origine" value={record.MontantTTC} money code={record.DeviseCode}/><Field label="Date de facture" value={record.DateFacture} date/><Field label="Échéance" value={record.DateEcheancePaiement} date/><Field label="Dernier règlement" value={record.DernierReglement} date/><Field label="Condition de paiement" value={record.ConditionPaiement}/><Field label="Mode de paiement" value={record.ModePaiement}/></dl>:<p className="commande360-muted">Aucune facture associée à ce bon.</p>}{onSection?<button type="button" className="erp-object-link commande360-group-link" onClick={()=>onSection("facturation")}>Consulter la facturation<AppIcon name="chevron-right" size={13}/></button>:null}</Group>
    {record.ObsCmd?<Group title="Observation" icon="document" className="commande360-note"><p>{record.ObsCmd}</p></Group>:null}
  </div>;
}
