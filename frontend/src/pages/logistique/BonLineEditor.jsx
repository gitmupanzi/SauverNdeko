import {useEffect,useId,useRef,useState} from "react";
import {useAuth} from "../../contexts/AuthContext";
import {requestJson} from "../../services/api";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import DrawerDialog from "../../components/DrawerDialog";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import SearchSelect from "../../components/SearchSelect";
import LotFields,{lotErrors} from "../../components/LotFields";
import useReferencesRefresh from "../../hooks/useReferencesRefresh";
import {formatCurrency,formatDate,formatNumber,asArrayPayload} from "./logistiqueShared";
import {multiplyDecimal} from "../../utils/money";
import {lineForm,lineLots,linePrice,lineErrors,linePayload,lineDirection,closedBon} from "./lineForm";

const read=(path)=>requestJson("/api/logistique"+path,{requiresAuth:true});
const bonLabel=row=>[row.CodeCmd||"Bon #"+row.ID_Commande,row.TypeCmd||row.AbrTypeCmd,row.DateCmd?formatDate(row.DateCmd):"",row.DeviseCode].filter(Boolean).join(" · ");
const articleLabel=row=>[row.NomArticle||"Article #"+row.ID_Article,row.CodeArticleInterne||row.RefArticle].filter(Boolean).join(" · ");
function Field({id,label,error,hint,wide=false,children}) {
 return <div className={"record-field"+(wide?" is-wide":"")}><label htmlFor={id}>{label}</label>{children}{error?<small id={id+"-error"} className="record-field-error">{error}</small>:hint?<small id={id+"-hint"}>{hint}</small>:null}</div>;
}
function Section({title,icon,children}) {return <section className="record-editor-section"><h3><AppIcon name={icon}/>{title}</h3><div className="record-editor-grid">{children}</div></section>;}

// Chaque page est recherchée côté serveur ; aucune limite silencieuse au catalogue.
function PagedChoice({id,label,path,idKey,labelFor,value,selected,onChange,disabled,error}) {
 const [draft,setDraft]=useState(""),[query,setQuery]=useState(""),[skip,setSkip]=useState(0),[rows,setRows]=useState([]),[meta,setMeta]=useState(null),[loading,setLoading]=useState(true),[failure,setFailure]=useState(""),[reload,setReload]=useState(0);
 useReferencesRefresh(()=>setReload(x=>x+1),{enabled:!disabled});
 useEffect(()=>{
  let active=true;setLoading(true);setFailure("");
  const params=new URLSearchParams({q:query,take:"25",skip:String(skip),sortBy:idKey==="ID_Article"?"NomArticle":"DateCmd",sortDir:idKey==="ID_Article"?"asc":"desc",...(idKey==="ID_Article"?{statut:"true"}:{})});
  read(path+"?"+params).then(response=>{
   if(!active)return;
   if(!response?.success){setFailure(response?.message||"Les choix ne sont pas disponibles.");setLoading(false);return;}
   setRows(asArrayPayload(response));setMeta(response.meta||null);setLoading(false);
  });return()=>{active=false;};
 },[path,idKey,query,skip,reload]);
 const choices=rows.map(row=>({value:String(row[idKey]),label:labelFor(row)}));
 if(value&&!choices.some(option=>option.value===String(value)))choices.unshift({value:String(value),label:selected?labelFor(selected):"Valeur sélectionnée · #"+value});
 const total=Number(meta?.filteredCount??0),next=skip+rows.length<total;
 function search(){if(disabled)return;setQuery(draft.trim());setSkip(0);}
 return <div className="record-field is-wide">
  <label htmlFor={id}>{label}</label>
  <div className="erp-register-actions"><input type="search" aria-label={"Rechercher · "+label} value={draft} onChange={e=>setDraft(e.target.value)} onKeyDown={e=>{if(e.key==="Enter"){e.preventDefault();search();}}} disabled={disabled} placeholder={"Rechercher un "+(idKey==="ID_Article"?"article":"bon de stock")+"…"}/><ActionButton icon="search" onClick={search} disabled={disabled||loading}>Rechercher</ActionButton></div>
  <SearchSelect id={id} label={label} value={value} options={choices} onChange={onChange} disabled={disabled} loading={loading} invalid={Boolean(error)} describedBy={error?id+"-error":id+"-page"}/>
  {failure?<small className="record-field-error" role="alert">{failure} <button type="button" className="erp-object-link" onClick={()=>setReload(x=>x+1)} disabled={disabled||loading}>Réessayer</button></small>:null}
  <div className="erp-register-actions"><small id={id+"-page"} role="status">{loading?"Chargement des choix…":total?String(skip+1)+"–"+String(skip+rows.length)+" sur "+total+" · recherche sur tout le registre":"Aucun résultat."}</small><ActionButton icon="chevron-left" className="is-icon" aria-label={"Choix précédents · "+label} onClick={()=>setSkip(x=>Math.max(0,x-25))} disabled={disabled||loading||skip===0}/><ActionButton icon="chevron-right" className="is-icon" aria-label={"Choix suivants · "+label} onClick={()=>setSkip(x=>x+25)} disabled={disabled||loading||!next}/></div>
  {error?<small id={id+"-error"} className="record-field-error">{error}</small>:null}
 </div>;
}

export default function BonLineEditor({line=null,selectedCommande=null,onClose,onSaved}) {
 const {user}=useAuth(),creating=!line,prefix=useId(),mounted=useRef(true),saving=useRef(false),bodyRef=useRef(null);
 const [values,setValues]=useState(()=>lineForm(null,selectedCommande?.ID_Commande)),[initial,setInitial]=useState(()=>JSON.stringify({values:lineForm(null,selectedCommande?.ID_Commande),lots:[]}));
 const [record,setRecord]=useState(null),[meta,setMeta]=useState(null),[bon,setBon]=useState(null),[bonMeta,setBonMeta]=useState(null),[article,setArticle]=useState(null);
 const [loading,setLoading]=useState(!creating),[bonLoading,setBonLoading]=useState(creating&&Boolean(selectedCommande?.ID_Commande)),[articleLoading,setArticleLoading]=useState(false),[busy,setBusy]=useState(false);
 const [error,setError]=useState(""),[errors,setErrors]=useState({}),[reload,setReload]=useState(0),[conflict,setConflict]=useState(false),[confirmReload,setConfirmReload]=useState(false);
 const [lots,setLots]=useState([]),[knownLots,setKnownLots]=useState([]),[lotsLoading,setLotsLoading]=useState(false),[lotsFailure,setLotsFailure]=useState("");
 const [bonFailure,setBonFailure]=useState(""),[articleFailure,setArticleFailure]=useState("");
 const canWrite=user?.permissions?.canWriteData===true,dirty=JSON.stringify({values,lots})!==initial;
 const direction=lineDirection(bon),outgoing=direction==="sortie";
 const reason=bonFailure||articleFailure||(!creating&&meta?.canEdit!==true?(meta?.editReason||"Cette ligne n’est pas modifiable."):bonMeta?.canEdit===false?(bonMeta.editReason||"Ce bon n’est pas modifiable."):closedBon(bon)?"Ce bon est clôturé.":bon&&bon.ID_DeviseFk==null?"Renseignez la devise du bon avant ses lignes.":article?.ValideArticle===false?"Cet article est inactif.":"");
 const blocked=!canWrite||busy||loading||bonLoading||articleLoading;
 const canSubmit=canWrite&&!blocked&&!lotsLoading&&!lotsFailure&&!reason&&Boolean(bon&&article)&&(creating||Boolean(meta?.revision&&dirty));
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
 useEffect(()=>{
  if(creating)return;
  let active=true;setLoading(true);setError("");setErrors({});setConflict(false);setConfirmReload(false);
  Promise.all([read("/commandes/"+line.ID_CmdFk),read("/commande-details/"+line.ID_CmdFk+"/"+line.ID_ArticleFk),read("/articles/"+line.ID_ArticleFk)]).then(([parent,current,product])=>{
   if(!active)return;
   if(!parent?.success||!current?.success||!product?.success){setError([parent,current,product].find(response=>!response?.success)?.message||"La ligne n’a pas pu être chargée.");setRecord(null);setMeta(null);setLoading(false);return;}
   const next=lineForm(current.data),nextLots=lineLots(current.data?.Lots||[]);
   setBon(parent.data);setBonMeta(parent.meta);setRecord(current.data);setMeta(current.meta);setArticle(product.data);setValues(next);setLots(nextLots);setInitial(JSON.stringify({values:next,lots:nextLots}));setLoading(false);
  });return()=>{active=false;};
 },[creating,line?.ID_CmdFk,line?.ID_ArticleFk,reload]);
 useEffect(()=>{
  if(!creating)return;
  if(!values.ID_CmdFk){setBon(null);setBonMeta(null);setBonLoading(false);return;}
  let active=true;setBonLoading(true);setBonFailure("");
  read("/commandes/"+values.ID_CmdFk).then(response=>{
   if(!active)return;
   setBon(response?.success?response.data:null);setBonMeta(response?.success?response.meta:null);setBonFailure(response?.success?"":response?.message||"Le bon n’a pas pu être chargé.");setBonLoading(false);
  });return()=>{active=false;};
 },[creating,values.ID_CmdFk,reload]);
 useEffect(()=>{
  if(!creating)return;
  if(!values.ID_ArticleFk){setArticle(null);setArticleLoading(false);return;}
  let active=true;setArticleLoading(true);setArticleFailure("");
  read("/articles/"+values.ID_ArticleFk).then(response=>{
   if(!active)return;
   if(response?.success){setArticle(response.data);setValues(current=>({...current,PUCmdDetail:linePrice(response.data,bon)}));}
   else{setArticle(null);setArticleFailure(response?.message||"L’article n’a pas pu être chargé.");}
   setArticleLoading(false);
  });return()=>{active=false;};
 },[creating,values.ID_ArticleFk,bon?.ID_Commande,reload]);
 useEffect(()=>{
  setKnownLots([]);setLotsFailure("");
  if(!outgoing||!article?.ID_Article){setLotsLoading(false);return;}
  let active=true;setLotsLoading(true);
  async function load(){
   const available=[];let skip=0;
   while(active){
    const result=await read("/consultations/produit/"+article.ID_Article+"/lots?take=100&skip="+skip);
    if(!active)return;
    if(!result?.success){setLotsFailure(result?.message||"Les lots disponibles n’ont pas pu être chargés.");setLotsLoading(false);return;}
    const page=asArrayPayload(result);available.push(...page);skip+=page.length;
    const total=Number(result.meta?.filteredCount??result.meta?.totalCount??skip);
    if(skip>=total){setKnownLots(available);setLotsLoading(false);return;}
    if(!page.length){setLotsFailure("La liste des lots est incomplète. Rechargez la fiche.");setLotsLoading(false);return;}
   }
  }
  load();return()=>{active=false;};
 },[outgoing,article?.ID_Article,reload]);
 useEffect(()=>{if(!loading){const frame=requestAnimationFrame(()=>bodyRef.current?.querySelector('input:not(:disabled):not(:read-only),[role="combobox"]:not(:disabled)')?.focus({preventScroll:true}));return()=>cancelAnimationFrame(frame);}},[loading]);
 function change(name,value){setValues(current=>({...current,[name]:value}));setErrors(current=>({...current,[name]:""}));}
 function focusInvalid(fields){requestAnimationFrame(()=>{const name=Object.keys(fields)[0];bodyRef.current?.querySelector('[id="'+prefix+name+'"]')?.focus();});}
 function input(name,label,options={}){
  const {hint,type="text",...attributes}=options,id=prefix+name;
  return <Field id={id} label={label} error={errors[name]} hint={hint}><input id={id} name={name} type={type} value={values[name]??""} onChange={e=>change(name,e.target.value)} disabled={blocked||Boolean(reason)} aria-invalid={Boolean(errors[name])} aria-describedby={errors[name]?id+"-error":hint?id+"-hint":undefined} {...attributes}/></Field>;
 }
 function reloadRecord(){if(dirty)setConfirmReload(true);else setReload(x=>x+1);}
 async function submit(){
  if(!canSubmit||saving.current)return;
  const invalid=lineErrors(values,bon,article,record),lotError=lotErrors(lots,values.QteCmdDetail);
  if(lotError)invalid.Lots=lotError;
  setErrors(invalid);setError("");setConflict(false);
  if(Object.keys(invalid).length){setError("Vérifiez les champs indiqués.");focusInvalid(invalid);return;}
  saving.current=true;setBusy(true);
  const payload=linePayload(values,lots,creating?null:meta.revision);
  if(creating)payload.ID_CmdFk=values.ID_CmdFk;
  const response=await requestJson("/api/logistique/commande-details"+(creating?"":"/"+record.ID_CmdFk+"/"+record.ID_ArticleFk),{requiresAuth:true,method:creating?"POST":"PUT",body:JSON.stringify(payload)});
  if(!mounted.current)return;saving.current=false;setBusy(false);
  if(!response?.success){
   const details=response?.error?.details,fieldErrors=details&&typeof details==="object"&&!Array.isArray(details)?Object.fromEntries(Object.entries(details).filter(([key])=>key in values||key==="Lots").map(([key,value])=>[key,String(value)])):{};
   setErrors(fieldErrors);setError(Object.keys(fieldErrors).length?"Vérifiez les champs indiqués.":response?.message||"La ligne n’a pas pu être enregistrée.");setConflict(response?.error?.code==="LINE_CONFLICT");if(Object.keys(fieldErrors).length)focusInvalid(fieldErrors);return;
  }
  onSaved(response.data,creating?"created":"updated");
 }
 return <RecordEditorFrame title={creating?"Nouvelle ligne de bon":"Modifier la ligne du bon"} subtitle={bon?bonLabel(bon):"Article, quantité et prix"} icon="list" onClose={onClose} onSubmit={submit} busy={busy} loading={loading} dirty={dirty} canSubmit={canSubmit} error={error||lotsFailure||bonFailure||articleFailure} onReload={conflict||(!creating&&!record&&!loading)||bonFailure||articleFailure||lotsFailure?reloadRecord:null} storageKey="sauverndeko.bon-line-editor.width">
  <div ref={bodyRef}>
   {confirmReload?<div className="record-editor-error" role="alert"><span>Recharger abandonnera les modifications de cette fiche.</span><ActionButton onClick={()=>setConfirmReload(false)}>Continuer</ActionButton><ActionButton onClick={()=>{setConfirmReload(false);setReload(x=>x+1);}}>Recharger</ActionButton></div>:null}
   {!loading?<>
    {reason?<p className="record-editor-error" role="status">{reason}</p>:null}
    <Section title="Bon et article" icon="box">
     {creating?<><PagedChoice id={prefix+"ID_CmdFk"} label="Bon de stock *" path="/registre/commandes" idKey="ID_Commande" labelFor={bonLabel} value={values.ID_CmdFk} selected={bon} disabled={busy||!canWrite} error={errors.ID_CmdFk} onChange={value=>{if(!canWrite||value===values.ID_CmdFk)return;setBon(null);setArticle(null);setLots([]);setValues(current=>({...current,ID_CmdFk:value,ID_ArticleFk:"",PUCmdDetail:""}));setErrors({});}}/>
     <PagedChoice id={prefix+"ID_ArticleFk"} label="Article *" path="/registre/articles" idKey="ID_Article" labelFor={articleLabel} value={values.ID_ArticleFk} selected={article} disabled={busy||!canWrite||bonLoading||!bon||bonMeta?.canEdit===false} error={errors.ID_ArticleFk} onChange={value=>{if(!canWrite||value===values.ID_ArticleFk)return;setArticle(null);setLots([]);setValues(current=>({...current,ID_ArticleFk:value,PUCmdDetail:""}));setErrors(current=>({...current,ID_ArticleFk:""}));}}/></>:<><Field id={prefix+"ID_CmdFk"} label="Bon de stock"><input id={prefix+"ID_CmdFk"} readOnly value={bon?bonLabel(bon):"—"}/></Field><Field id={prefix+"ID_ArticleFk"} label="Article"><input id={prefix+"ID_ArticleFk"} readOnly value={article?articleLabel(article):"—"}/></Field></>}
     {article?<Field id={prefix+"stock"} label="Stock actuel"><input id={prefix+"stock"} readOnly value={formatNumber(article.QteArticle)+(article.Unite?" "+article.Unite:"")}/></Field>:null}
     <Field id={prefix+"devise"} label="Devise du bon"><input id={prefix+"devise"} readOnly value={bon?.DeviseCode||"Non renseignée"}/></Field>
    </Section>
    <Section title="Quantité et prix" icon="cash">
     {input("QteCmdDetail","Quantité *",{inputMode:"numeric",maxLength:10})}
     {input("PUCmdDetail","Prix unitaire *"+(bon?.DeviseCode?" · "+bon.DeviseCode:""),{inputMode:"decimal",hint:direction==="entree"?"Prix d’achat dans la devise du bon.":"Prix dans la devise du bon, sans conversion automatique."})}
     <Field id={prefix+"total"} label="Montant de la ligne" wide><output id={prefix+"total"} className="stock-receipt-total">{formatCurrency(multiplyDecimal(values.QteCmdDetail,values.PUCmdDetail),bon?.DeviseCode)}</output></Field>
    </Section>
    <div id={prefix+"Lots"} tabIndex={-1}><LotFields value={lots} onChange={next=>{setLots(next);setErrors(current=>({...current,Lots:""}));}} total={values.QteCmdDetail} disabled={blocked||lotsLoading||Boolean(reason)} known={knownLots} outgoing={outgoing} title={outgoing?"Lots sortants":"Lots reçus"} error={errors.Lots||lotsFailure}/>{lotsLoading?<p className="record-editor-note" role="status">Chargement des lots disponibles…</p>:null}</div>
    <Section title="Informations complémentaires" icon="document">
     <Field id={prefix+"ObsCmdDetail"} label="Observation" wide><textarea id={prefix+"ObsCmdDetail"} name="ObsCmdDetail" value={values.ObsCmdDetail} onChange={e=>change("ObsCmdDetail",e.target.value)} disabled={blocked||Boolean(reason)}/></Field>
     {input("LieuCmdDetail","Identifiant du lieu",{inputMode:"numeric",hint:"Facultatif, selon le paramétrage de votre organisation."})}
     <div className="record-field"><label htmlFor={prefix+"RemiseCmdDetail"}>Remise historique</label><input id={prefix+"RemiseCmdDetail"} readOnly value={values.RemiseCmdDetail==null?"Non renseignée":values.RemiseCmdDetail?"Oui":"Non"}/></div>
     {[['SelectCmdDetail','Sélection enregistrée']].map(([name,label])=><div key={name} className="record-field"><label className="record-editor-check" htmlFor={prefix+name}><input id={prefix+name} type="checkbox" checked={values[name]===true} disabled={blocked||Boolean(reason)} onChange={e=>change(name,e.target.checked)}/>{label}</label></div>)}
    </Section>
   </>:null}
  </div>
 </RecordEditorFrame>;
}

export function BonLineDelete({line,onClose,onSaved}) {
 const {user}=useAuth(),mounted=useRef(true),saving=useRef(false);
 const [record,setRecord]=useState(null),[meta,setMeta]=useState(null),[loading,setLoading]=useState(true),[busy,setBusy]=useState(false),[error,setError]=useState(""),[reload,setReload]=useState(0);
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
 useEffect(()=>{let active=true;setLoading(true);setError("");read("/commande-details/"+line.ID_CmdFk+"/"+line.ID_ArticleFk).then(response=>{if(!active)return;setRecord(response?.success?response.data:null);setMeta(response?.success?response.meta:null);setError(response?.success?"":response?.message||"La ligne n’a pas pu être chargée.");setLoading(false);});return()=>{active=false;};},[line.ID_CmdFk,line.ID_ArticleFk,reload]);
 const enabled=user?.permissions?.canWriteData===true&&!loading&&!busy&&meta?.canEdit===true&&Boolean(meta?.revision&&record);
 async function submit(){if(!enabled||saving.current)return;saving.current=true;setBusy(true);setError("");const response=await requestJson("/api/logistique/commande-details/"+line.ID_CmdFk+"/"+line.ID_ArticleFk,{requiresAuth:true,method:"DELETE",body:JSON.stringify({_version:meta.revision})});if(!mounted.current)return;saving.current=false;setBusy(false);if(!response?.success){setError(response?.message||"La ligne n’a pas pu être supprimée.");return;}onSaved(record,"deleted");}
 return <DrawerDialog title="Supprimer la ligne du bon" icon="trash" onClose={onClose} busy={busy} defaultWidth={540} storageKey="sauverndeko.bon-line-delete.width" bodyClassName="record-editor-body" footer={<footer className="record-editor-footer"><span/><div><ActionButton disabled={busy} onClick={onClose}>Annuler</ActionButton><ActionButton variant="primary" icon="trash" className="is-danger" disabled={!enabled} onClick={submit}>{busy?"Suppression…":"Supprimer la ligne"}</ActionButton></div></footer>}>
  {loading?<p className="record-editor-state" role="status">Chargement de la ligne…</p>:null}
  {record?<><div className="record-action-summary"><strong>{record.NomArticle||line.NomArticle||"Article"}</strong><p>{record.CodeCmd||line.CodeCmd||"Bon #"+line.ID_CmdFk} · {formatNumber(record.QteCmdDetail)} {record.AbrUnite||""} · {formatCurrency(record.MontantLigne,record.DeviseCode)}</p></div><p className="record-action-copy">La ligne et son mouvement seront annulés. Le stock et le montant du bon seront recalculés.</p></>:null}
  {meta?.canEdit===false?<p className="record-editor-error" role="status">{meta.editReason||"Cette ligne n’est pas modifiable."}</p>:null}
  {error?<div className="record-editor-error" role="alert"><span>{error}</span><ActionButton icon="refresh" onClick={()=>setReload(x=>x+1)} disabled={busy}>Recharger</ActionButton></div>:null}
 </DrawerDialog>;
}
