import {useEffect,useId,useRef,useState} from "react";
import {useAuth} from "../contexts/AuthContext";
import {useEntityScope} from "../contexts/EntityScopeContext";
import {moduleRights} from "../services/moduleAccess";
import {requestJson,downloadApiFile} from "../services/api";
import ActionButton from "./ActionButton";
import AppIcon from "./AppIcon";
import CategoricalSelect from "./CategoricalSelect";
import ConsultationTabs from "./ConsultationTabs";
import RecordEditorFrame from "./RecordEditorFrame";
import {formatCurrency,formatDate,formatNumber,SimpleTable} from "../pages/logistique/logistiqueShared";
import "./StockValuation.css";

const cleanCost=value=>String(value||"").trim().replace(",",".");
const validCost=value=>/^\d{1,10}(?:\.\d{1,6})?$/.test(cleanCost(value));
const unitCost=(value,currency)=>value==null?"—":formatNumber(value)+(currency?" "+currency:"");
const stateTone=value=>value==="Calculé"?"success":value==="À initialiser"?"warning":"neutral";
export default function StockValuation({articleId,defaultCurrencyId,onClose,onSaved}) {
 const {user}=useAuth(),scope=useEntityScope(),prefix=useId();
 const [tab,setTab]=useState("synthese"),[payload,setPayload]=useState(null),[loading,setLoading]=useState(true),[busy,setBusy]=useState(false),[error,setError]=useState(""),[revision,setRevision]=useState(0);
 const [currency,setCurrency]=useState(()=>String(defaultCurrencyId||"")),[cost,setCost]=useState(""),[motif,setMotif]=useState(""),[confirmed,setConfirmed]=useState(false),[editing,setEditing]=useState(false),[uncertain,setUncertain]=useState(false),[feedback,setFeedback]=useState(""),[exporting,setExporting]=useState(false),[grid,setGrid]=useState({take:25,skip:0});
 const ticket=useRef(null),editingVersion=useRef(null),live=useRef(true),source=useRef(""),loadedIdentity=useRef("");
 const path="/api/logistique/articles/"+articleId+"/valorisation";
 const data=payload?.data,article=data?.article,positions=data?.positions||[],position=positions.find(item=>String(item.ID_DeviseFk)===currency),movements=data?.movements||[];
 const canWrite=scope.canWrite&&user?.permissions?.canWriteData===true&&moduleRights(user,"logistique").canManage&&(data?.canConfigure??payload?.meta?.canConfigure)===true;
 useEffect(()=>{live.current=true;return()=>{live.current=false;};},[]);
 useEffect(()=>{
  const identity=scope.scopeKey+":"+articleId;source.current=identity;
  const controller=new AbortController();setLoading(true);setError("");
  if(loadedIdentity.current!==identity){loadedIdentity.current=identity;setPayload(null);setBusy(false);setEditing(false);setCost("");setMotif("");setConfirmed(false);setUncertain(false);ticket.current=null;}
  const params=new URLSearchParams({take:String(grid.take),skip:String(grid.skip),...(currency?{deviseId:currency}:{})});
  requestJson(path+"?"+params,{requiresAuth:true,signal:controller.signal}).then(result=>{
   if(controller.signal.aborted||source.current!==identity)return;setLoading(false);
   if(!result?.success){setError(result?.message||"La valorisation n’a pas pu être chargée.");return;}
   setPayload(result);setCurrency(current=>result.data?.positions?.some(item=>String(item.ID_DeviseFk)===current)?current:String(result.data?.positions?.[0]?.ID_DeviseFk||""));
  });return()=>controller.abort();
 },[articleId,scope.scopeKey,revision,grid.take,grid.skip,currency]);
 const dirty=editing&&(!!cost||!!motif||confirmed),canSubmit=canWrite&&editing&&!!position&&typeof editingVersion.current==="string"&&validCost(cost)&&!!motif.trim()&&confirmed&&!loading;
 function reload(){if(busy)return;setEditing(false);setCost("");setMotif("");setConfirmed(false);setUncertain(false);ticket.current=null;setRevision(value=>value+1);}
 function startEdit(){editingVersion.current=position?.Version??null;setCost("");setMotif("");setConfirmed(false);setEditing(true);setFeedback("");setError("");ticket.current=null;}
 function changeCurrency(value){if(busy||uncertain)return;setCurrency(value);setGrid(current=>({...current,skip:0}));setEditing(false);setCost("");setMotif("");setConfirmed(false);ticket.current=null;}
 async function submit(){
  if(!canSubmit||busy)return;
  const values={deviseId:position.ID_DeviseFk,coutUnitaire:cleanCost(cost),motif:motif.trim(),_version:editingVersion.current};
  const fingerprint=JSON.stringify(values);
  if(!ticket.current||ticket.current.fingerprint!==fingerprint)ticket.current={fingerprint,body:{...values,requestId:crypto.randomUUID()}};
  setBusy(true);setError("");const expected=source.current;
  const result=await requestJson(path,{method:"PUT",requiresAuth:true,body:JSON.stringify(ticket.current.body)});
  if(!live.current||source.current!==expected)return;setBusy(false);
  if(!result?.success){setUncertain(result?.status===0||result?.status>=500);setError(result?.message||"Le coût d’ouverture n’a pas pu être enregistré.");return;}
  setFeedback("Valorisation enregistrée.");setEditing(false);setCost("");setMotif("");setConfirmed(false);setUncertain(false);ticket.current=null;setRevision(value=>value+1);onSaved?.(result.data);
 }
 async function exportHistory(){
  if(exporting)return;setExporting(true);setError("");
  try{await downloadApiFile(path+"/export.xlsx"+(currency?"?deviseId="+encodeURIComponent(currency):""));}catch(cause){if(live.current)setError(cause.message||"L’export n’a pas pu être téléchargé.");}finally{if(live.current)setExporting(false);}
 }
 const audits=data?.history||[];
 const auditCurrency=row=>positions.find(item=>String(item.ID_DeviseFk)===String(row.Apres?.ID_DeviseFk??row.Avant?.ID_DeviseFk))?.DeviseCode||"";
 const auditColumns=[
  {key:"CreeLe",label:"Date et heure",width:180,render:row=>formatDate(row.CreeLe)},
  {key:"Operation",label:"Opération",width:150,render:row=>row.Operation==="ouverture"?"Initialisation":row.Operation==="reevaluation"?"Réévaluation":row.Operation},
  {key:"AncienCout",label:"Coût précédent",align:"right",width:170,render:row=>unitCost(row.Avant?.CoutOuverture,auditCurrency(row))},
  {key:"NouveauCout",label:"Coût confirmé",align:"right",width:170,render:row=>unitCost(row.Apres?.CoutOuverture,auditCurrency(row))},
  {key:"Motif",label:"Motif",width:280},
  {key:"NomAuteur",label:"Auteur",width:180,render:row=>row.NomAuteur||"Compte #"+row.ID_UserFk},
 ];
 const columns=[
  {key:"DateMvt",label:"Date et heure",width:180,render:row=>formatDate(row.DateMvt)},
  {key:"CodeCmd",label:"Bon de stock",width:140},
  {key:"QteSignee",label:"Quantité",align:"right",width:120,render:row=>formatNumber(row.QteSignee)},
  {key:"CoutUnitaire",label:"Coût unitaire",align:"right",width:160,render:row=>unitCost(row.CoutUnitaire,row.DeviseCode)},
  {key:"ValeurMouvement",label:"Valeur du mouvement",align:"right",width:170,render:row=>formatCurrency(row.ValeurMouvement,row.DeviseCode)},
  {key:"StockApres",label:"Stock après",align:"right",width:140,render:row=>formatNumber(row.StockApres)},
  {key:"ValeurApres",label:"Valeur après",align:"right",width:165,render:row=>formatCurrency(row.ValeurApres,row.DeviseCode)},
  {key:"OrigineCout",label:"Origine du coût",width:220},
 ].map(column=>({...column,sortable:false}));
 return <RecordEditorFrame title="Valorisation du stock" subtitle={article?.NomArticle||"Article"} icon="cash" defaultWidth={960} storageKey="sauverndeko.stock-valuation.width" busy={busy} loading={loading&&!data} readOnly={!editing} dirty={dirty} error={error} onReload={reload} canSubmit={canSubmit} onSubmit={submit} onClose={onClose} submitLabel={uncertain?"Vérifier l’enregistrement":"Confirmer le coût"}>
  <div className="stock-valuation">
   {feedback?<p className="stock-valuation-success" role="status">{feedback}</p>:null}
   {data?<>
    <ConsultationTabs tabs={[{key:"synthese",label:"Synthèse",icon:"cash"},{key:"historique",label:"Historique des coûts",icon:"clock"}]} value={tab} onChange={setTab} label="Valorisation de l’article" idPrefix={prefix}/>
    {positions.length>1?<label className="record-field stock-valuation-currency">Devise<CategoricalSelect value={currency} disabled={busy||uncertain||editing} onChange={event=>changeCurrency(event.target.value)}>{positions.map(item=><option key={item.ID_DeviseFk} value={item.ID_DeviseFk}>{item.DeviseCode}</option>)}</CategoricalSelect></label>:null}
    <section role="tabpanel" id={prefix+"-panel-synthese"} aria-labelledby={prefix+"-tab-synthese"} hidden={tab!=="synthese"}>
     {position?<>
      <section className="stock-valuation-summary"><header><h3><AppIcon name="cash"/>Coût moyen unitaire pondéré</h3><span className={"erp-status is-"+stateTone(position.EtatValorisation)}>{position.EtatValorisation||"Non déterminé"}</span></header>
       <dl><div><dt>Quantité valorisée</dt><dd>{formatNumber(position.QteValorisee)}{article?.AbrUnite?<small>{article.AbrUnite}</small>:null}</dd></div><div><dt>CUMP</dt><dd>{unitCost(position.CoutUnitaireMoyen,position.DeviseCode)}</dd></div><div><dt>Valeur du stock</dt><dd>{formatCurrency(position.ValeurStock,position.DeviseCode)}</dd></div></dl>
       {position.EtatValorisation==="À initialiser"?<p>Renseignez le coût unitaire d’ouverture pour valoriser le stock repris.</p>:null}
       {canWrite&&!editing?<ActionButton icon="edit" onClick={startEdit}>{position.EtatValorisation==="À initialiser"?"Initialiser la valorisation":"Réévaluer le stock"}</ActionButton>:null}
      </section>
      <section className="stock-valuation-opening"><h3><AppIcon name="document"/>Coût de référence</h3><dl><div><dt>Quantité de référence</dt><dd>{formatNumber(position.QuantiteArrete)}</dd></div><div><dt>Coût unitaire confirmé</dt><dd>{unitCost(position.CoutOuverture,position.DeviseCode)}</dd></div></dl></section>
      {editing?<section className="record-editor-section stock-valuation-form"><h3><AppIcon name="edit"/>{position.EtatValorisation==="À initialiser"?"Initialiser la valorisation":"Réévaluer le stock"}</h3><p>Confirmez le coût unitaire du stock courant sur la base de vos justificatifs. L’historique des écritures et des coûts reste conservé.</p>
       <label className="record-field">Coût unitaire à confirmer · {position.DeviseCode} *<input autoFocus required inputMode="decimal" maxLength={24} autoComplete="off" value={cost} disabled={busy||uncertain} onChange={event=>{setCost(event.target.value);setConfirmed(false);}} aria-invalid={!!cost&&!validCost(cost)} placeholder="0,00"/>{cost&&!validCost(cost)?<small className="record-field-error">Indiquez un coût positif ou nul, avec six décimales au maximum.</small>:null}</label>
       <label className="record-field">Motif *<textarea required rows={3} maxLength={1000} value={motif} disabled={busy||uncertain} onChange={event=>setMotif(event.target.value)} placeholder="Référence du justificatif et raison de cette valeur."/></label>
       <label className="stock-valuation-confirm"><input type="checkbox" checked={confirmed} disabled={busy||uncertain} onChange={event=>setConfirmed(event.target.checked)}/><span>Je confirme ce coût unitaire et la valorisation du stock courant.</span></label>
       {uncertain?<p role="status">La réponse n’a pas pu être confirmée. Réessayez pour vérifier la même demande, ou rechargez la fiche.</p>:null}
      </section>:null}
      {audits.length?<details className="stock-valuation-audit"><summary><AppIcon name="clock"/>Derniers coûts confirmés <span className="erp-count">{audits.length}</span></summary><div className="erp-results" data-density="compact"><SimpleTable rows={audits} columns={auditColumns} defaultPinnedColumns={[]} showControls={false} toolbar={<></>}/></div></details>:null}
     </>:<p className="stock-valuation-empty">Aucune position de valorisation disponible.</p>}
    </section>
    <section role="tabpanel" id={prefix+"-panel-historique"} aria-labelledby={prefix+"-tab-historique"} hidden={tab!=="historique"}>
     <div className="stock-valuation-export"><label className="stock-valuation-page-size">Lignes<CategoricalSelect value={grid.take} disabled={loading||busy} onChange={event=>setGrid({take:Number(event.target.value),skip:0})}>{[10,25,50,100].map(value=><option key={value} value={value}>{value}</option>)}</CategoricalSelect></label><ActionButton icon="download" onClick={exportHistory} disabled={exporting||user?.permissions?.canExportData===false||moduleRights(user,"logistique").canExport===false||payload?.meta?.canExport===false}>{exporting?"Export…":"Excel"}</ActionButton></div>
     <div className="erp-results" data-density="compact"><SimpleTable rows={movements} columns={columns} defaultPinnedColumns={[]} showControls={false} toolbar={<></>} serverMeta={data.pagination||{filteredCount:movements.length,take:grid.take,skip:grid.skip}} serverState={grid} onServerChange={patch=>setGrid(current=>({...current,...patch}))} loading={loading} emptyMessage="Aucun coût de mouvement disponible."/></div>
    </section>
   </>:null}
  </div>
 </RecordEditorFrame>;
}
