import {useState} from "react";
import lazyView from "./LazyView";
import ActionButton from "./ActionButton";
const StockValuation=lazyView(()=>import("./StockValuation"),{label:"Chargement de la valorisation…",compact:true});
import ArticlePhoto from "./ArticlePhoto";
import AppIcon from "./AppIcon";
import { formatCurrency, formatDate, formatNumber } from "../pages/logistique/logistiqueShared";
import "./ProductOverview.css";
const text = value => value == null || value === "" ? "—" : String(value);
function Field({ label, value, numeric = false, date = false, dateOnly = false, currency }) {
  return <div><dt>{label}</dt><dd className={numeric ? "is-numeric" : ""}>{value == null || value === "" ? "—" : currency !== undefined ? formatCurrency(value,currency) : numeric ? formatNumber(value) : date ? formatDate(value,{withTime:!dateOnly}) : text(value)}</dd></div>;
}
function Group({ title, icon, children, note }) {
  return <section className="product-overview-group"><h4><AppIcon name={icon}/>{title}</h4><dl>{children}</dl>{note ? <p>{note}</p> : null}</section>;
}
export function ProductHeading({ record }) {
  const stock = String(record.EtatStock || "");
  const tone = /rupture/i.test(stock) ? "danger" : /faible/i.test(stock) ? "warning" : /disponible/i.test(stock) ? "success" : "neutral";
  return <div className="product-overview-hero"><span className="product-overview-avatar"><ArticlePhoto record={record}/></span><div className="product-overview-title"><p>{record.CategorieArticle || "Article"}</p><h3>{record.NomArticle || "Article sans nom"}</h3><div className="product-overview-codes"><span>Code : {text(record.CodeArticleInterne)}</span>{record.RefArticle ? <span>Réf. : {record.RefArticle}</span> : null}</div></div><div className="product-overview-status">{stock ? <span className={"erp-status is-"+tone}>{stock}</span> : null}{record.ValideArticle != null ? <span className={"erp-status is-"+(record.ValideArticle ? "info" : "neutral")}>{record.ValideArticle ? "Actif" : "Inactif"}</span> : null}</div></div>;
}
export default function ProductOverview({ record }) {
  const [valuation,setValuation]=useState(false);
  return <div className="product-overview">
    <section className="product-overview-stock" aria-label="Situation du stock">{[["QteArticle","Stock actuel","box"],["QteMinArticle","Seuil minimum","alert"],["QteACommander","À commander","stock-in"]].map(([key,label,icon]) => <div key={key}><span><AppIcon name={icon}/>{label}</span><strong>{formatNumber(record[key])}{record.Unite ? <small>{record.Unite}</small> : null}</strong></div>)}</section>
    <Group title="Informations générales" icon="tag"><Field label="Catégorie" value={record.CategorieArticle}/><Field label="Type" value={record.TypeArticle}/><Field label="Unité" value={record.Unite}/><Field label="Responsable" value={record.NomComplet}/><Field label="Poids unitaire" value={record.PoidsUnitaire==null?null:formatNumber(record.PoidsUnitaire)+(record.UnitePoids?" "+record.UnitePoids:"")}/></Group>
    <Group title="Prix catalogue" icon="cash"><Field label="Prix d’achat" value={record.PUArticle} currency={record.DeviseCode || ""}/><Field label="Prix de vente" value={record.PVArticle} currency={record.DeviseCode || ""}/><Field label="Valeur au prix catalogue" value={record.ValeurStockAchat} currency={record.DeviseCode || ""}/><Field label="Marge unitaire" value={record.MargeUnitaire} currency={record.DeviseCode || ""}/></Group>
    <section className="product-overview-group product-valuation-entry"><div className="product-valuation-heading"><h4><AppIcon name="cash"/>Valorisation du stock</h4><ActionButton icon="cash" onClick={()=>setValuation(true)}>Consulter le CUMP</ActionButton></div><p>Coûts d’ouverture, coût moyen et historique des mouvements.</p></section>
    {valuation?<StockValuation articleId={record.ID_Article} defaultCurrencyId={record.ID_DeviseFk} onClose={()=>setValuation(false)}/>:null}
    <Group title="Conservation" icon="calendar"><Field label="Date générale · stock sans lot" value={record.DatePeremptionArticle} date dateOnly/><Field label="Prochaine péremption en stock" value={record.DateProchainePeremption} date dateOnly/><Field label="Quantité périmée" value={record.StockPerime==null?null:formatNumber(record.StockPerime)+(record.Unite?" "+record.Unite:"")}/><Field label="Quantité proche de péremption" value={record.StockProchePeremption==null?null:formatNumber(record.StockProchePeremption)+(record.Unite?" "+record.Unite:"")}/><Field label="Début de l’alerte" value={record.DatePeremptionAlerteArticle} date/><Field label="État de péremption" value={record.EtatPeremption}/><Field label="Délai d’alerte (jours)" value={record.NbreJoursAlerteArticle} numeric/></Group>
    {record.InformationArticle ? <section className="product-overview-group product-overview-note"><h4><AppIcon name="document"/>Informations sur l’article</h4><p style={{whiteSpace:"pre-wrap"}}>{record.InformationArticle}</p></section>:null}
    {record.ObsArticle ? <section className="product-overview-group product-overview-note"><h4><AppIcon name="document"/>Observation</h4><p>{record.ObsArticle}</p></section> : null}
  </div>;
}
