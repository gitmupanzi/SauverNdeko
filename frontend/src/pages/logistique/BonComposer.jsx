import {fieldCurrencyReferences} from "../../utils/money";
import {REFERENCE_RETAINED_HINT,referenceLabel,retainReference,isRetainedReference} from "../../utils/referenceOptions";
import DestinationSelect from "../../components/DestinationSelect";
import TiersSelect from "../../components/TiersSelect";
import {useEffect,useId,useMemo,useRef,useState} from "react";
import {useAuth} from "../../contexts/AuthContext";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import ConsultationTabs from "../../components/ConsultationTabs";
import SearchSelect from "../../components/SearchSelect";
import ActionButton from "../../components/ActionButton";
import DrawerDialog from "../../components/DrawerDialog";
import RowActionsMenu from "../../components/RowActionsMenu";
import AppIcon from "../../components/AppIcon";
import LotFields,{lotErrors} from "../../components/LotFields";
import useReferencesRefresh from "../../hooks/useReferencesRefresh";
import {requestJson} from "../../services/api";
import {roundMoney} from "../../utils/quantities";
import {compareDecimal,currencyOptions,formatCurrency,multiplyDecimal,newCurrencyId} from "../../utils/money";
import {asArrayPayload,buildReferenceOptions,formatDate,formatNumber,SimpleTable} from "./logistiqueShared";
import {commandeForm} from "./commandeForm";
import {createReceiptRequestId} from "./receiptForm";
import {cataloguePrice,compositionBasket,compositionBasketSnapshot,compositionDirection,compositionHeaderErrors,compositionLine,compositionLineErrors,compositionLotsUnchanged,compositionPayload,compositionTotal,compositionType,MAX_COMPOSITION_LINES} from "./bonComposerForm";
import {lotAvailability,requiredLotQuantity,allocatedQuantity,wholeQuantity} from "../../utils/lotAllocation";
import {isStockOrder,previousStockCode} from "../../utils/stockDocumentTypes";
import "./BonComposer.css";
import "../../components/DataTable.css";

function Field({id,label,error,hint,wide=false,children}) {return <div className={"record-field"+(wide?" is-wide":"")}><label htmlFor={id}>{label}</label>{children}{error?<small id={id+"-error"} className="record-field-error">{error}</small>:hint?<small id={id+"-hint"}>{hint}</small>:null}</div>;}
const read=path=>requestJson("/api/logistique"+path,{requiresAuth:true});
const headerReferences={ID_StatutCmdFk:"commandeStatuses",ID_TiersFk:"clients",ID_ConditionPaiementFk:"commandeConditionPaiements",ID_ModePaiementFk:"commandeModesPaiement"};
const text=value=>value==null?"":String(value).trim();
const articleReferences=article=>[text(article.CodeArticleInterne)?"Code : "+text(article.CodeArticleInterne):"Code interne non renseigné",text(article.RefArticle)?"Réf. : "+text(article.RefArticle):"Référence non renseignée"].join(" · ");
const articleContext=article=>[text(article.CategorieArticle)||text(article.AbrCategorieArticle),text(article.TypeArticle)||text(article.AbrTypeArticle)].filter(Boolean).join(" · ");
const stockUnit=article=>text(article.AbrUnite)||text(article.Unite);

export default function BonComposer({commandeId=null,references:receivedReferences,onClose,onSaved,invoiceAvailable=false,onInvoice}) {
 const references=fieldCurrencyReferences(receivedReferences,"commandeCurrencies");
  const creating=commandeId==null;
  const {user}=useAuth(),prefix=useId(),mounted=useRef(true),saving=useRef(false),request=useRef(null),searchRef=useRef(null);
  const contextKey=String(user?.IdUser??"")+":"+String(user?.IdEntiteFk??""),initialContext=useRef(contextKey);
  const firstValues=useRef(null);if(firstValues.current==null)firstValues.current=commandeForm(null,newCurrencyId(references));
  const [values,setValues]=useState(firstValues.current),[basket,setBasket]=useState([]),[active,setActive]=useState("bon"),[headerErrors,setHeaderErrors]=useState({}),[lineErrors,setLineErrors]=useState({}),[error,setError]=useState("");
  const [busy,setBusy]=useState(false),[uncertain,setUncertain]=useState(false),[closeWarning,setCloseWarning]=useState(false),[clearWarning,setClearWarning]=useState(false);
  const [query,setQuery]=useState(""),[draftQuery,setDraftQuery]=useState(""),[grid,setGrid]=useState({take:10,skip:0,sortBy:"NomArticle",sortDir:"asc"}),[rows,setRows]=useState([]),[meta,setMeta]=useState(null),[loading,setLoading]=useState(false),[catalogueError,setCatalogueError]=useState(""),[catalogueRevision,setCatalogueRevision]=useState(0);
  const [selected,setSelected]=useState([]),[selectionReset,setSelectionReset]=useState(0),[knownLots,setKnownLots]=useState({}),lotsRequests=useRef(new Map());
  const [lineDetail,setLineDetail]=useState(null);
  const [sourceBon,setSourceBon]=useState(null),[editMeta,setEditMeta]=useState(null),[editLoading,setEditLoading]=useState(!creating),[editRevision,setEditRevision]=useState(0),[editReloadable,setEditReloadable]=useState(false),[reloadWarning,setReloadWarning]=useState(false);
  const initialBasket=useRef("[]");
  const canWrite=user?.permissions?.canWriteData===true&&contextKey===initialContext.current,editable=canWrite&&(creating||editMeta?.canEdit===true),disabled=busy||uncertain||editLoading||!editable;
  const direction=compositionDirection(compositionType(references,values,sourceBon)),currency=references?.currencies?.find(item=>String(item.id)===values.ID_DeviseFk)||(sourceBon&&String(sourceBon.ID_DeviseFk)===values.ID_DeviseFk?{code:sourceBon.DeviseCode}:null),currencyCode=currency?.code;
  const order=direction==="commande",typeFixedByOrder=!creating&&(isStockOrder(sourceBon)||order);
  const dirty=JSON.stringify(values)!==JSON.stringify(firstValues.current)||compositionBasketSnapshot(basket)!==initialBasket.current,total=compositionTotal(basket);
  const typeOptions=(references?.commandeTypes||[]).filter(type=>compositionDirection(type)&&!(!creating&&sourceBon&&!isStockOrder(sourceBon)&&compositionDirection(type)==="commande")).map(type=>({value:String(type.id),label:referenceLabel(type),disabled:type.disabled===true||type.incompatible===true,incompatible:type.incompatible===true}));
  const chosenIds=new Set(basket.map(line=>String(line.article.ID_Article))),newSelected=selected.filter(article=>!chosenIds.has(String(article.ID_Article)));
  useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;lotsRequests.current.queue=[];lotsRequests.current.clear();};},[]);
  useEffect(()=>{if(contextKey!==initialContext.current)onClose();},[contextKey,onClose]);
  useEffect(()=>{if(order)setActive(current=>current==="facturation"?"bon":current);},[order]);
  useEffect(()=>{if(direction!=="sortie"){lotsRequests.current.clear();lotsRequests.current.queue=[];setKnownLots({});}},[direction]);
  useEffect(()=>{
    if(creating)return;
    let active=true;setEditLoading(true);setError("");setEditReloadable(false);setReloadWarning(false);
    read("/commandes/"+commandeId+"/composition").then(response=>{
      if(!active)return;
      if(!response?.success){setEditMeta(null);setError(response?.message||"Le bon et ses articles n’ont pas pu être chargés.");setEditReloadable(true);setEditLoading(false);return;}
      const form=commandeForm(response.data.bon),lines=compositionBasket(response.data.lignes);firstValues.current=form;initialBasket.current=compositionBasketSnapshot(lines);
      setSourceBon(response.data.bon);setEditMeta(response.meta||null);setValues(form);setBasket(lines);setHeaderErrors({});setLineErrors({});setKnownLots({});lotsRequests.current.clear();setEditLoading(false);
    });return()=>{active=false;};
  },[creating,commandeId,editRevision]);
  useReferencesRefresh(()=>setCatalogueRevision(value=>value+1),{enabled:!disabled});
  useEffect(()=>{
    if(!direction||!values.ID_DeviseFk){setRows([]);setMeta(null);setLoading(false);return;}
    if(direction==="sortie"&&!disabled)for(const line of basket)loadLots(line.article.ID_Article);
    let live=true;setLoading(true);setCatalogueError("");
    const params=new URLSearchParams({q:query,...grid,statut:"true",stockState:"all",contexte:"composition",...(direction==="sortie"?{columnFilters:JSON.stringify({QteArticle:">0"})}:{})});
    read("/registre/articles?"+params).then(response=>{
      if(!live)return;
      if(!response?.success){setCatalogueError(response?.message||"Le catalogue n’a pas pu être chargé.");setLoading(false);return;}
      const next=asArrayPayload(response);setRows(next);setMeta(response.meta||null);setLoading(false);setSelectionReset(value=>value+1);
      // Actualiser le stock affiché, sans changer les prix ni les quantités du brouillon.
      setBasket(current=>current.map(line=>{const article=next.find(item=>String(item.ID_Article)===String(line.article.ID_Article));return article?{...line,article}:line;}));
    });return()=>{live=false;};
  },[direction,Boolean(values.ID_DeviseFk),query,grid,catalogueRevision]);
  function change(name,value){if(disabled)return;if(name==="ID_TypeCmdFk"&&(typeFixedByOrder||!creating&&compositionDirection(references?.commandeTypes?.find(type=>String(type.id)===String(value)))==="commande"))return;if((name==="ID_TypeCmdFk"||name==="ID_DeviseFk")&&(basket.length||!creating&&editMeta?.[name==="ID_TypeCmdFk"?"canChangeType":"canChangeCurrency"]!==true))return;setValues(current=>({...current,[name]:value}));setHeaderErrors(current=>({...current,[name]:""}));if(name==="ID_TypeCmdFk"){setGrid(current=>({...current,skip:0}));setSelected([]);setSelectionReset(current=>current+1);}}
  function changeLine(articleId,name,value){if(disabled)return;setBasket(current=>current.map(line=>{if(String(line.article.ID_Article)!==String(articleId))return line;if(line.original&&(line.article.ValideArticle!==true||line.article.missing))return line;return {...line,[name]:value};}));setLineErrors(current=>({...current,[articleId]:{...current[articleId],[name]:""}}));}
  function input(name,label,{hint,wide=false,type="text",...attributes}={}) {const id=prefix+name,invalid=headerErrors[name];return <Field id={id} label={label} hint={hint} error={invalid} wide={wide}><input id={id} name={name} type={type} value={values[name]??""} onChange={event=>change(name,event.target.value)} disabled={disabled} aria-invalid={Boolean(invalid)} aria-describedby={invalid?id+"-error":hint?id+"-hint":undefined} {...attributes}/></Field>;}
  function select(name,label,{nullable=true,boolean=false}={}) {
    const id=prefix+name,invalid=headerErrors[name],options=boolean?[{value:"true",label:"Oui"},{value:"false",label:"Non"}]:name==="ID_TypeCmdFk"?[...typeOptions]:name==="ID_DeviseFk"?currencyOptions(references):buildReferenceOptions(references?.[headerReferences[name]],label);
    if(values[name]&&!options.some(option=>String(option.value)===String(values[name])))options.unshift({value:String(values[name]),label:sourceBon?.[{ID_TypeCmdFk:"TypeCmd",ID_DeviseFk:"DeviseCode",ID_StatutCmdFk:"StatutCmd",ID_TiersFk:"NomClientSaisi",ID_ConditionPaiementFk:"ConditionPaiement",ID_ModePaiementFk:"ModePaiement"}[name]]||"Valeur actuelle",disabled:true,incompatible:true});
    const fixed=name==="ID_TypeCmdFk"&&typeFixedByOrder||!creating&&(name==="ID_TypeCmdFk"||name==="ID_DeviseFk")&&editMeta?.[name==="ID_TypeCmdFk"?"canChangeType":"canChangeCurrency"]!==true,locked=fixed||basket.length>0&&(name==="ID_TypeCmdFk"||name==="ID_DeviseFk"),hint=isRetainedReference(options,values[name])?REFERENCE_RETAINED_HINT:fixed?"Cette valeur est conservée avec l’historique du bon.":locked?"Videz le panier pour changer le type ou la devise.":"";
    return <Field id={id} label={label} error={invalid} hint={hint}><SearchSelect id={id} label={label} value={values[name]} options={[{value:"",label:nullable?"Non renseigné":"Choisir"},...options]} onChange={value=>change(name,value)} disabled={disabled||locked} invalid={Boolean(invalid)} describedBy={invalid?id+"-error":hint?id+"-hint":undefined}/></Field>;
  }
  function readonly(name,label,value){return <Field id={prefix+name} label={label}><input id={prefix+name} value={value==null||value===""?"Non renseigné":String(value)} readOnly/></Field>;}
  function focusHeader(invalid){const name=Object.keys(invalid)[0];setActive(["ID_TypeCmdFk","DateCmd","ID_DeviseFk","ID_TiersFk","NomClientSaisi","RefCmd","ID_DestinationFk","geolocalisationCmd","ObsCmd"].includes(name)?"bon":["ID_StatutCmdFk","UrlBL","SelectCmd"].includes(name)?"suivi":"facturation");requestAnimationFrame(()=>document.getElementById(prefix+name)?.focus());}
  function toArticles(){const invalid=compositionHeaderErrors(values,references,sourceBon);setHeaderErrors(invalid);if(Object.keys(invalid).length){setError("Vérifiez les informations du bon.");focusHeader(invalid);return;}setError("");setActive("articles");requestAnimationFrame(()=>searchRef.current?.focus({preventScroll:true}));}
  function addArticles(articles){
    if(disabled||loading||catalogueError||!direction||!currency)return;
    const eligible=articles.filter(article=>!chosenIds.has(String(article.ID_Article))&&article.ValideArticle!==false&&(direction!=="sortie"||compareDecimal(article.QteArticle,"0")===1));
    if(basket.length+eligible.length>MAX_COMPOSITION_LINES){setError("Un bon peut contenir au maximum "+MAX_COMPOSITION_LINES+" articles distincts.");return;}
    setBasket(current=>{const existing=new Set(current.map(line=>String(line.article.ID_Article))),added=eligible.filter(article=>{const id=String(article.ID_Article);if(existing.has(id))return false;existing.add(id);return true;});return current.length+added.length>MAX_COMPOSITION_LINES?current:[...current,...added.map(article=>compositionLine(article,values,references,sourceBon))];});setSelected([]);setSelectionReset(value=>value+1);setError("");
    if(direction==="sortie")for(const article of eligible)loadLots(article.ID_Article);
    if(eligible[0])requestAnimationFrame(()=>document.getElementById(prefix+"qty-"+eligible[0].ID_Article)?.focus({preventScroll:true}));
  }
  function removeArticle(id){if(disabled)return;setBasket(current=>current.filter(line=>String(line.article.ID_Article)!==String(id)));setLineErrors(current=>{const next={...current};delete next[id];return next;});}
  function focusLineIssue(issues){const id=Object.keys(issues)[0],fields=issues[id]||{},field=fields.QteCmdDetail?"qty":fields.PUCmdDetail?"price":fields.ObsCmdDetail?"obs":fields.LieuCmdDetail?"place":fields.SelectCmdDetail?"selected":fields.Lots?"lots":"qty";setActive("articles");setLineDetail(["qty","price"].includes(field)?null:{id,section:field==="lots"?"lots":"infos"});if(field==="lots")loadLots(id);requestAnimationFrame(()=>document.getElementById(prefix+field+"-"+id)?.focus());}
  function drainLots(){
    const jobs=lotsRequests.current;
    if(!jobs.queue)jobs.queue=[];if(jobs.active==null)jobs.active=0;
    while(mounted.current&&jobs.active<3&&jobs.queue.length){const task=jobs.queue.shift();jobs.active++;task().finally(()=>{jobs.active--;drainLots();});}
  }
  function loadLots(articleId,{force=false}={}){
    const id=String(articleId);
    if(disabled||direction!=="sortie"||!force&&lotsRequests.current.has(id))return;
    if(force&&knownLots[id]?.loading)return;
    const token={};lotsRequests.current.set(id,token);setKnownLots(current=>({...current,[id]:{loading:true,error:"",rows:null,meta:null}}));
    if(!lotsRequests.current.queue)lotsRequests.current.queue=[];
    lotsRequests.current.queue.push(async()=>{try{
      const available=[];let skip=0,stock=null;
      while(mounted.current&&lotsRequests.current.get(id)===token){
        const response=await read("/consultations/produit/"+id+"/lots?take=100&skip="+skip);
        if(!mounted.current||lotsRequests.current.get(id)!==token)return;
        if(!response?.success){lotsRequests.current.delete(id);setKnownLots(current=>({...current,[id]:{loading:false,error:response?.message||"Les lots ne sont pas disponibles.",rows:null,meta:null}}));return;}
        if(response.meta?.lotStock)stock=response.meta.lotStock;
        const page=asArrayPayload(response);available.push(...page);skip+=page.length;
        const count=Number(response.meta?.filteredCount??response.meta?.totalCount??skip);
        if(skip>=count){if(!stock){lotsRequests.current.delete(id);setKnownLots(current=>({...current,[id]:{loading:false,error:"Les disponibilités par lot doivent être actualisées. Réessayez.",rows:null,meta:null}}));return;}setKnownLots(current=>({...current,[id]:{loading:false,error:"",rows:available,meta:{lotStock:stock}}}));return;}
        if(!page.length){lotsRequests.current.delete(id);setKnownLots(current=>({...current,[id]:{loading:false,error:"La liste des lots est incomplète. Réessayez.",rows:null,meta:null}}));return;}
      }
    }catch{if(mounted.current&&lotsRequests.current.get(id)===token){lotsRequests.current.delete(id);setKnownLots(current=>({...current,[id]:{loading:false,error:"Les lots ne sont pas disponibles. Réessayez.",rows:null,meta:null}}));}}});drainLots();
  }
  function availabilityFor(line){const current=knownLots[line.article.ID_Article];return lotAvailability(current?.meta,current?.rows||[],line.original);}
  function lotState(line){
    const current=knownLots[line.article.ID_Article],available=availabilityFor(line),minimum=requiredLotQuantity(line.QteCmdDetail,available),assigned=allocatedQuantity(line.Lots);
    if(current?.loading)return "Vérification des lots…";
    if(current?.error)return "Vérifier les lots";
    if(minimum!=null&&wholeQuantity(minimum)>0n&&assigned!=null&&assigned<wholeQuantity(minimum))return "Lots requis · "+formatNumber(minimum)+" "+stockUnit(line.article);
    return assigned&&assigned>0n?"Lots · "+formatNumber(assigned.toString())+" "+stockUnit(line.article):"Lots et stock sans lot";
  }
  function requestClose(){if(busy)return;if(uncertain){setCloseWarning(true);return;}onClose();}
  function requestReload(){if(busy||uncertain)return;if(dirty)setReloadWarning(true);else setEditRevision(value=>value+1);}
  async function submit(){
    if(saving.current||!editable||editLoading||(!creating&&!editMeta?.revision)||(!creating&&!dirty&&!uncertain)||direction==="sortie"&&Object.values(knownLots).some(item=>item.loading))return;
    let snapshot=request.current;
    if(!uncertain){
      const invalid=compositionHeaderErrors(values,references,sourceBon),invalidLines={};
      for(const line of basket){const issues=compositionLineErrors(line,direction),unchanged=compositionLotsUnchanged(line),availability=availabilityFor(line),lotsIssue=order||unchanged?"":lotErrors(line.Lots,line.QteCmdDetail,{outgoing:direction==="sortie",availability});if(lotsIssue)issues.Lots=lotsIssue;if(direction==="sortie"&&!unchanged&&(!availability||knownLots[line.article.ID_Article]?.error))issues.Lots="Vérifiez les lots disponibles avant d’enregistrer.";if(Object.keys(issues).length)invalidLines[line.article.ID_Article]=issues;}
      setHeaderErrors(invalid);setLineErrors(invalidLines);setError("");
      if(Object.keys(invalid).length){setError("Vérifiez les informations du bon.");focusHeader(invalid);return;}
      if(creating&&!basket.length||basket.length>MAX_COMPOSITION_LINES){setActive("articles");setError(creating?"Ajoutez entre 1 et "+MAX_COMPOSITION_LINES+" articles au bon.":"Un bon peut contenir au maximum "+MAX_COMPOSITION_LINES+" articles.");return;}
      if(Object.keys(invalidLines).length){setError("Vérifiez les lignes indiquées.");focusLineIssue(invalidLines);return;}
      if(total==null||compareDecimal(total,"9999999999.99")===1){setActive("articles");setError("Le total du bon dépasse la limite autorisée.");return;}
      if(!user?.IdUser){setError("Votre session doit être actualisée avant de créer le bon.");return;}
      const payload=compositionPayload(values,basket,user.IdUser,sourceBon,editMeta?.revision,references),fingerprint=JSON.stringify(payload);
      if(!snapshot||snapshot.fingerprint!==fingerprint){snapshot={payload,fingerprint,requestId:createReceiptRequestId()};request.current=snapshot;}
    }
    if(!snapshot)return;
    saving.current=true;setBusy(true);setError("");setCloseWarning(false);
    const response=await requestJson(creating?"/api/logistique/commandes/composees":"/api/logistique/commandes/"+commandeId+"/composition",{requiresAuth:true,method:creating?"POST":"PUT",body:JSON.stringify({...snapshot.payload,requestId:snapshot.requestId})});
    if(!mounted.current)return;saving.current=false;setBusy(false);
    if(!response?.success||!response.data?.bon){
      const ambiguous=!response||!response.status||response.status>=500||response.success===true;
      if(ambiguous){setUncertain(true);setError("La réponse du serveur n’est pas parvenue. Réessayez sans modifier le bon.");return;}
      setUncertain(false);
      if(!creating&&response.status===409)setEditReloadable(true);
      const details=response.error?.details,bonIssues={},rowIssues={};
      if(details&&typeof details==="object"&&!Array.isArray(details))for(const [key,message] of Object.entries(details)){
        if(key.startsWith("bon.")&&key.slice(4) in values)bonIssues[key.slice(4)]=String(message);
        const match=/^lignes\.(\d+)(?:\.(.+))?$/.exec(key);if(match&&basket[Number(match[1])]){const id=basket[Number(match[1])].article.ID_Article,field=match[2]?.startsWith("Lots")?"Lots":["QteCmdDetail","PUCmdDetail","ObsCmdDetail","LieuCmdDetail","RemiseCmdDetail","SelectCmdDetail"].includes(match[2])?match[2]:"article";rowIssues[id]={...rowIssues[id],[field]:String(message)};}
      }
      const general=details&&typeof details==="object"?[details.bon,details.lignes,details.requestId].find(value=>typeof value==="string"&&value):"";
      const lotFailure=Object.entries(rowIssues).find(([,fields])=>fields.Lots),lotArticle=lotFailure?basket.find(line=>String(line.article.ID_Article)===String(lotFailure[0]))?.article:null,lotMessage=lotFailure?(lotArticle?.NomArticle?lotArticle.NomArticle+" : ":"")+lotFailure[1].Lots:"";
      setHeaderErrors(bonIssues);setLineErrors(rowIssues);for(const [id,fields] of Object.entries(rowIssues))if(fields.Lots)loadLots(id,{force:true});setError(general||lotMessage||response.message||"Le bon n’a pas pu être enregistré.");if(Object.keys(bonIssues).length)focusHeader(bonIssues);else if(Object.keys(rowIssues).length)focusLineIssue(rowIssues);return;
    }
    onSaved(response.data.bon,creating?"created":"updated");
  }
  const catalogueColumns=useMemo(()=>[
    {key:"NomArticle",label:"Article",width:250,render:row=><span className="erp-product-cell"><span className="erp-product-avatar"><AppIcon name="box" size={18}/></span><span className="erp-product-identity"><strong>{row.NomArticle||"Article sans nom"}</strong><small>{articleReferences(row)}</small>{articleContext(row)?<small className="bon-composer-product-context">{articleContext(row)}</small>:null}</span></span>},
    {key:"QteArticle",label:"Disponible",width:120,align:"right",render:row=>formatNumber(row.QteArticle)+(stockUnit(row)?" "+stockUnit(row):"")},
    {key:"cataloguePrice",label:order?"Prix convenu":direction==="entree"?"Prix d’achat proposé":"Prix de vente proposé",sortable:false,width:180,align:"right",render:row=>{const price=cataloguePrice(row,values,references,sourceBon);return price===""?"À saisir"+(currencyCode?" · "+currencyCode:""):formatCurrency(price,currencyCode);}},
    {key:"actions",label:"",sortable:false,width:105,render:row=><ActionButton icon={chosenIds.has(String(row.ID_Article))?"check-circle":"plus"} disabled={disabled||loading||Boolean(catalogueError)||chosenIds.has(String(row.ID_Article))} aria-label={"Ajouter "+(row.NomArticle||"l’article")} onClick={()=>addArticles([row])}>{chosenIds.has(String(row.ID_Article))?"Ajouté":"Ajouter"}</ActionButton>},
  ],[direction,values.ID_DeviseFk,references,sourceBon,basket,disabled,loading,catalogueError]);
  const lineLocked=line=>Boolean(line?.original)&&(line.article.ValideArticle!==true||line.article.missing);
  function openLine(line,section){if(order&&section==="lots")return;setLineDetail({id:String(line.article.ID_Article),section});if(section==="lots"&&!disabled&&!lineLocked(line))loadLots(line.article.ID_Article);}
  const basketColumns=[
    {key:"article",label:"Article et stock",width:310,sortable:false,render:line=>{const article=line.article,issues=lineErrors[article.ID_Article]||{};return <span className="bon-composer-cart-identity"><strong>{article.NomArticle||"Article #"+article.ID_Article}</strong><small>{articleReferences(article)} · Stock : {formatNumber(article.QteArticle)} {stockUnit(article)}{line.original?" · Quantité d’origine : "+formatNumber(line.original.QteCmdDetail):""}</small>{lineLocked(line)?<small>Historique conservé</small>:null}{direction==="sortie"?<button type="button" className={"erp-object-link bon-composer-lot-state"+(issues.Lots?" is-error":"")} disabled={busy} onClick={()=>openLine(line,"lots")}><AppIcon name="box" size={12}/>{lotState(line)}</button>:null}{issues.article?<small className="record-field-error">{issues.article}</small>:null}{["ObsCmdDetail","LieuCmdDetail","SelectCmdDetail","Lots"].some(key=>issues[key])?<button type="button" className="erp-object-link bon-composer-detail-error" onClick={()=>openLine(line,issues.Lots?"lots":"infos")}>Informations à vérifier</button>:null}</span>; }},
    {key:"QteCmdDetail",label:"Quantité",width:120,align:"right",sortable:false,render:line=>{const id=line.article.ID_Article,invalid=lineErrors[id]?.QteCmdDetail;return <div className="bon-composer-cart-field"><label className="erp-sr-only" htmlFor={prefix+"qty-"+id}>{"Quantité · "+line.article.NomArticle}</label><input id={prefix+"qty-"+id} className="bon-composer-cart-input is-quantity" inputMode="decimal" maxLength={15} value={line.QteCmdDetail} onChange={event=>changeLine(id,"QteCmdDetail",event.target.value)} onKeyDown={event=>{if(event.key==="Enter")event.preventDefault();}} disabled={disabled||lineLocked(line)} aria-invalid={Boolean(invalid)} aria-describedby={invalid?prefix+"qty-"+id+"-error":undefined}/>{invalid?<small id={prefix+"qty-"+id+"-error"} className="record-field-error">{invalid}</small>:null}</div>;}},
    {key:"PUCmdDetail",label:(order?"Prix convenu":"Prix unitaire")+(currencyCode?" · "+currencyCode:""),width:155,align:"right",sortable:false,render:line=>{const id=line.article.ID_Article,invalid=lineErrors[id]?.PUCmdDetail;return <div className="bon-composer-cart-field"><label className="erp-sr-only" htmlFor={prefix+"price-"+id}>{(order?"Prix convenu · ":"Prix unitaire · ")+line.article.NomArticle}</label><input id={prefix+"price-"+id} className="bon-composer-cart-input is-price" inputMode="decimal" maxLength={32} value={line.PUCmdDetail} placeholder="À saisir" onChange={event=>changeLine(id,"PUCmdDetail",event.target.value)} onKeyDown={event=>{if(event.key==="Enter")event.preventDefault();}} disabled={disabled||lineLocked(line)} aria-invalid={Boolean(invalid)} aria-describedby={invalid?prefix+"price-"+id+"-error":undefined}/>{invalid?<small id={prefix+"price-"+id+"-error"} className="record-field-error">{invalid}</small>:null}</div>;}},
    {key:"amount",label:"Montant",width:170,align:"right",sortable:false,render:line=>formatCurrency(roundMoney(multiplyDecimal(line.QteCmdDetail,line.PUCmdDetail)),currencyCode)},
    {key:"actions",label:"Actions",width:90,sortable:false,render:line=><RowActionsMenu label={line.article.NomArticle||"Article"} items={[{label:"Informations",icon:"document",disabled:busy,onSelect:()=>openLine(line,"infos")},...(!order?[{label:"Lots",icon:"box",disabled:busy,onSelect:()=>openLine(line,"lots")}]:[]),{label:"Retirer du bon",icon:"trash",danger:true,disabled,reason:disabled?"Le bon est en consultation.":"",onSelect:()=>removeArticle(line.article.ID_Article)}]}/>},
  ];
  const detailLine=lineDetail?basket.find(line=>String(line.article.ID_Article)===String(lineDetail.id)):null,detailDisabled=disabled||lineLocked(detailLine),detailIssues=detailLine?lineErrors[detailLine.article.ID_Article]||{}:{},detailPrice=detailLine?cataloguePrice(detailLine.article,values,references,sourceBon):"",detailKnown=detailLine?knownLots[detailLine.article.ID_Article]:null,detailAvailability=detailLine?availabilityFor(detailLine):null,detailPrefix=prefix+"-line-detail";
  const lotsBusy=direction==="sortie"&&Object.values(knownLots).some(item=>item.loading);
  return <RecordEditorFrame title={order?(creating?"Nouveau bon de commande":"Modifier le bon de commande"):creating?"Nouveau bon de stock":"Modifier le bon de stock"} subtitle={sourceBon?.CodeCmd||"Préparez le bon et ses articles"} icon="receipt" defaultWidth={1180} className="bon-composer-dialog" storageKey="sauverndeko.bon-composer.width" onClose={requestClose} onSubmit={submit} busy={busy} loading={editLoading&&!sourceBon} dirty={!uncertain&&dirty} canSubmit={canWrite&&!editLoading&&!lotsBusy&&(uncertain||editable&&(creating?basket.length>0:dirty))} submitLabel={uncertain?"Réessayer":creating?(order?"Enregistrer la commande":"Enregistrer le bon"):"Enregistrer les modifications"} error={error} onReload={!creating&&editReloadable&&!uncertain?requestReload:null}>
    <div className="bon-composer">
      {closeWarning?<div className="record-editor-error" role="alert"><span>Le bon a peut-être été enregistré. Réessayez pour vérifier avant de fermer.</span><div className="bon-composer-inline-actions"><ActionButton onClick={submit} disabled={busy}>Réessayer</ActionButton><ActionButton onClick={onClose} disabled={busy}>Fermer la fenêtre</ActionButton></div></div>:null}
      {reloadWarning?<div className="record-editor-error" role="alert"><span>Recharger le bon et abandonner les modifications ?</span><div className="bon-composer-inline-actions"><ActionButton onClick={()=>setReloadWarning(false)}>Continuer</ActionButton><ActionButton onClick={()=>setEditRevision(value=>value+1)}>Recharger</ActionButton></div></div>:null}
      {creating||sourceBon?<>
      {!creating&&sourceBon&&editMeta?.canEdit!==true?<p className="record-editor-error" role="status">{editMeta?.reason||"Ce bon est disponible en consultation."}</p>:null}
      <ConsultationTabs tabs={[{key:"bon",label:"Bon",icon:"receipt"},{key:"articles",label:"Articles",icon:"box"},{key:"suivi",label:"Suivi bon",icon:"list"},...(!order?[{key:"facturation",label:"Facturation",icon:"document"}]:[]),{key:"tracabilite",label:"Traçabilité",icon:"user"}]} value={active} onChange={setActive} label="Préparation du bon" idPrefix={prefix}/>
      <div className="bon-composer-summary"><span><AppIcon name={direction==="entree"?"stock-in":direction==="sortie"?"stock-out":"receipt"}/>{compositionType(references,values,sourceBon)?.label||"Type à choisir"}</span><span>{basket.length} article{basket.length>1?"s":""}</span><strong>Total <span>{formatCurrency(total,currencyCode)}</span></strong></div>{order?<p className="record-editor-note">Sans mouvement de stock.</p>:null}
      <section role="tabpanel" id={prefix+"-panel-bon"} aria-labelledby={prefix+"-tab-bon"} hidden={active!=="bon"} tabIndex={active==="bon"?0:-1}>
        <section className="record-editor-section"><h3><AppIcon name="receipt"/>Informations du bon</h3><div className="record-editor-grid">
          {select("ID_TypeCmdFk","Type de bon *",{nullable:false})}{input("DateCmd","Date et heure du bon *",{type:"datetime-local",step:1,hint:"Heure de Kinshasa."})}{select("ID_DeviseFk","Devise *",{nullable:false})}<Field id={prefix+"ID_TiersFk"} label="Tiers référencé" error={headerErrors.ID_TiersFk}><TiersSelect id={prefix+"ID_TiersFk"} value={values.ID_TiersFk} references={references?.clients||[]} currentLabel={sourceBon?.TiersNom||sourceBon?.NomClientSaisi||""} disabled={disabled} invalid={Boolean(headerErrors.ID_TiersFk)} onChange={(id,name)=>{change("ID_TiersFk",id);if(name)change("NomClientSaisi",name);}}/></Field>{input("NomClientSaisi","Nom du tiers",{maxLength:255})}{input("RefCmd","Référence",{maxLength:255})}<Field id={prefix+"ID_DestinationFk"} label="Destination" error={headerErrors.ID_DestinationFk}><DestinationSelect id={prefix+"ID_DestinationFk"} value={values.ID_DestinationFk} selectedLabel={sourceBon?.DestinationLibelle||""} onChange={value=>change("ID_DestinationFk",value)} disabled={disabled} invalid={Boolean(headerErrors.ID_DestinationFk)}/></Field>{input("geolocalisationCmd","Adresse complémentaire",{maxLength:255})}
          <Field id={prefix+"ObsCmd"} label="Observations" error={headerErrors.ObsCmd} wide><textarea id={prefix+"ObsCmd"} name="ObsCmd" rows={2} maxLength={255} value={values.ObsCmd} onChange={event=>change("ObsCmd",event.target.value)} disabled={disabled} aria-invalid={Boolean(headerErrors.ObsCmd)} aria-describedby={headerErrors.ObsCmd?prefix+"ObsCmd-error":undefined}/></Field>
        </div></section>
        <div className="bon-composer-next"><ActionButton variant="primary" icon="chevron-right" onClick={toArticles} disabled={disabled}>Choisir les articles</ActionButton></div>
      </section>
      <section role="tabpanel" id={prefix+"-panel-articles"} aria-labelledby={prefix+"-tab-articles"} hidden={active!=="articles"} tabIndex={active==="articles"?0:-1}>
        {!direction||!currency?<div className="record-editor-error" role="status"><span>Choisissez le type et la devise du bon pour consulter les articles.</span><ActionButton icon="receipt" onClick={()=>setActive("bon")}>Informations du bon</ActionButton></div>:<div className="bon-composer-workspace">
          <section className="bon-composer-catalogue"><header><div><h3>Catalogue des articles</h3><p>{order?"Articles actifs, quel que soit le stock disponible.":direction==="sortie"?"Articles actifs avec un stock disponible.":"Articles actifs à approvisionner."}</p></div><ActionButton icon="plus" variant="primary" disabled={disabled||loading||Boolean(catalogueError)||!newSelected.length} onClick={()=>addArticles(newSelected)}>Ajouter{newSelected.length?" · "+newSelected.length:" la sélection"}</ActionButton></header>
            <div className="bon-composer-search"><label htmlFor={prefix+"search"}><AppIcon name="search"/><span className="erp-sr-only">Rechercher un article</span><input ref={searchRef} id={prefix+"search"} type="search" placeholder="Rechercher un article, un code ou une référence…" value={draftQuery} disabled={disabled} onChange={event=>setDraftQuery(event.target.value)} onKeyDown={event=>{if(event.key==="Enter"){event.preventDefault();setQuery(draftQuery.trim());setGrid(current=>({...current,skip:0}));}}}/></label><ActionButton icon="search" disabled={disabled||loading} onClick={()=>{setQuery(draftQuery.trim());setGrid(current=>({...current,skip:0}));}}>Rechercher</ActionButton><label className="bon-composer-page-size"><span>Lignes</span><select value={grid.take} aria-label="Articles par page" disabled={disabled||loading} onChange={event=>setGrid(current=>({...current,take:Number(event.target.value),skip:0}))}>{[10,25,50].map(take=><option key={take} value={take}>{take}</option>)}</select></label></div>
            {catalogueError?<div className="record-editor-error" role="alert"><span>{catalogueError}</span><ActionButton icon="refresh" onClick={()=>setCatalogueRevision(value=>value+1)} disabled={disabled||loading}>Réessayer</ActionButton></div>:null}
            <div className="erp-results" data-density="compact"><SimpleTable rows={rows} columns={catalogueColumns} loading={loading} serverMeta={meta} serverState={grid} onServerChange={patch=>{if(!disabled)setGrid(current=>({...current,...patch}));}} enableSelection={!disabled} onSelectionChange={setSelected} selectionResetKey={selectionReset} defaultPinnedColumns={[]} showControls={false} toolbar={<></>} emptyMessage={catalogueError?"Le catalogue n’est pas disponible.":"Aucun article pour cette recherche."}/></div>
          </section>
          <section className="bon-composer-basket"><header><h3><AppIcon name="receipt"/>Articles du bon <span>{basket.length}</span></h3>{basket.length?<ActionButton icon="trash" disabled={disabled} onClick={()=>setClearWarning(true)}>Vider le panier</ActionButton>:null}</header>
            {clearWarning?<div className="record-editor-error" role="alert"><span>Retirer tous les articles du bon ?</span><div className="bon-composer-inline-actions"><ActionButton onClick={()=>setClearWarning(false)} disabled={disabled}>Continuer</ActionButton><ActionButton icon="trash" onClick={()=>{if(disabled)return;setBasket([]);setLineErrors({});setKnownLots({});setClearWarning(false);}} disabled={disabled}>Vider le panier</ActionButton></div></div>:null}
            {!basket.length?<div className="bon-composer-empty"><AppIcon name="box" size={26}/><strong>Aucun article ajouté</strong><p>Sélectionnez les articles dans le catalogue.</p></div>:<div className="erp-results bon-composer-cart-table" data-density="compact"><SimpleTable rows={basket} columns={basketColumns} getRowId={line=>line.article.ID_Article} defaultPinnedColumns={[]} defaultRowsPerPage={50} showControls={false} toolbar={<></>}/></div>}
            {basket.length?<div className="bon-composer-total"><span>{basket.length} article{basket.length>1?"s":""} · Total du bon</span><strong>{formatCurrency(total,currencyCode)}</strong></div>:null}
          </section>
        </div>}
      </section>
      <section role="tabpanel" id={prefix+"-panel-suivi"} aria-labelledby={prefix+"-tab-suivi"} hidden={active!=="suivi"} tabIndex={active==="suivi"?0:-1}>
        <section className="record-editor-section"><h3><AppIcon name="list"/>Suivi bon</h3><div className="record-editor-grid">{select("ID_StatutCmdFk","Statut du bon")}{!order?input("UrlBL","Lien du bon de livraison",{maxLength:255}):null}{select("SelectCmd","Marqué pour suivi",{boolean:true})}</div></section>
      </section>
      {!order?<section role="tabpanel" id={prefix+"-panel-facturation"} aria-labelledby={prefix+"-tab-facturation"} hidden={active!=="facturation"} tabIndex={active==="facturation"?0:-1}>
        <section className="record-editor-section"><h3><AppIcon name="document"/>Facturation</h3>
          {creating?<p className="record-editor-note">{direction==="entree"?"La création d’une facture concerne les bons de sortie.":"Enregistrez le bon pour créer sa facture."}</p>:invoiceAvailable&&onInvoice&&(direction==="sortie"||sourceBon?.CodeFacture)?<div className="bon-composer-invoice-action"><ActionButton icon="document" onClick={()=>{if(!busy&&!uncertain&&!dirty&&canWrite&&!editLoading)onInvoice(commandeId);}} disabled={!canWrite||busy||uncertain||dirty||editLoading}>{sourceBon?.CodeFacture?"Modifier la facture":"Créer la facture"}</ActionButton>{dirty?<small>Enregistrez les modifications du bon avant de gérer sa facture.</small>:null}</div>:null}
          <div className="record-editor-grid">
            {readonly("CodeFacture","Numéro de facture",sourceBon?.CodeFacture)}{readonly("DateFacture","Date de facture",sourceBon?.DateFacture?formatDate(sourceBon.DateFacture):null)}{readonly("StatusFacture","Statut de facturation",sourceBon?.StatusFacture)}{readonly("UrlFacture","Lien de la facture",sourceBon?.UrlFacture)}
            {select("ID_ConditionPaiementFk","Condition de paiement")}{select("ID_ModePaiementFk","Mode de paiement")}{input("DateEcheancePaiement","Échéance de paiement",{type:"datetime-local",step:1})}
            {[['MontantHT','Montant hors taxes'],['MontantTTC','Montant TTC'],['MontantRegleFacture','Montant réglé'],['MontantResteFacture','Reste à régler']].map(([name,label])=><div key={name}>{readonly(name,label,creating?"Calculé à l’enregistrement":formatCurrency(sourceBon?.[name],sourceBon?.DeviseCode))}</div>)}
          </div>
        </section>
      </section>:null}
      <section role="tabpanel" id={prefix+"-panel-tracabilite"} aria-labelledby={prefix+"-tab-tracabilite"} hidden={active!=="tracabilite"} tabIndex={active==="tracabilite"?0:-1}>
        <section className="record-editor-section"><h3><AppIcon name="user"/>Traçabilité</h3><div className="record-editor-grid">
          {readonly("CodeCmd","Code du bon",creating?"Attribué à l’enregistrement":sourceBon?.CodeCmd)}{!creating&&previousStockCode(sourceBon)?<>{readonly("AncienCodeCmd","Ancien code",previousStockCode(sourceBon))}{sourceBon.RenumeroteLe?readonly("RenumeroteLe","Renuméroté le",formatDate(sourceBon.RenumeroteLe)):null}</>:null}{readonly("ID_UserFk","Responsable",creating?[user?.PrenomUser,user?.NomUser].filter(Boolean).join(" "):sourceBon?.NomComplet||references?.users?.find(item=>String(item.id)===String(sourceBon?.ID_UserFk))?.label||(sourceBon?.ID_UserFk==null?null:"Utilisateur #"+sourceBon.ID_UserFk))}
          {readonly("DateHeureAutoCmd","Créé le",creating?"À l’enregistrement":sourceBon?.DateHeureAutoCmd?formatDate(sourceBon.DateHeureAutoCmd):null)}{!order?readonly("DateHeureAutoFacture","Facturation enregistrée le",creating?"À l’émission de la facture":sourceBon?.DateHeureAutoFacture?formatDate(sourceBon.DateHeureAutoFacture):null):null}
          {!order?readonly("ValideRemiseFacture","Remise historique",sourceBon?.ValideRemiseFacture==null?null:sourceBon.ValideRemiseFacture?"Oui":"Non"):null}
        </div></section>
      </section>
      {detailLine?<DrawerDialog title={detailLine.article.NomArticle||"Article du bon"} subtitle="Détail de la ligne" icon="box" defaultWidth={720} storageKey="sauverndeko.composer-line.width" bodyClassName="record-editor-body bon-composer-line-details" onClose={()=>{if(!busy)setLineDetail(null);}} busy={busy} footer={<footer className="record-editor-footer"><span>Les changements restent dans le brouillon du bon.</span><ActionButton icon="check-circle" onClick={()=>setLineDetail(null)} disabled={busy}>Terminer</ActionButton></footer>}>
        <ConsultationTabs tabs={[{key:"infos",label:"Informations",icon:"document"},...(!order?[{key:"lots",label:"Lots",icon:"box"}]:[])]} value={lineDetail.section} onChange={section=>openLine(detailLine,section)} label="Détail de la ligne" idPrefix={detailPrefix}/>
        <section role="tabpanel" id={detailPrefix+"-panel-infos"} aria-labelledby={detailPrefix+"-tab-infos"} hidden={lineDetail.section!=="infos"} tabIndex={lineDetail.section==="infos"?0:-1}><section className="record-editor-section"><h3><AppIcon name="document"/>Informations</h3><div className="record-editor-grid">
          <Field id={prefix+"obs-"+detailLine.article.ID_Article} label="Observation" error={detailIssues.ObsCmdDetail} wide><textarea id={prefix+"obs-"+detailLine.article.ID_Article} rows={3} maxLength={255} value={detailLine.ObsCmdDetail??""} onChange={event=>changeLine(detailLine.article.ID_Article,"ObsCmdDetail",event.target.value)} disabled={detailDisabled} aria-invalid={Boolean(detailIssues.ObsCmdDetail)} aria-describedby={detailIssues.ObsCmdDetail?prefix+"obs-"+detailLine.article.ID_Article+"-error":undefined}/></Field>
          <Field id={prefix+"place-"+detailLine.article.ID_Article} label="Identifiant du lieu" error={detailIssues.LieuCmdDetail} hint="Facultatif, selon le paramétrage de votre organisation."><input id={prefix+"place-"+detailLine.article.ID_Article} inputMode="numeric" maxLength={10} value={detailLine.LieuCmdDetail??""} onChange={event=>changeLine(detailLine.article.ID_Article,"LieuCmdDetail",event.target.value)} disabled={detailDisabled} aria-invalid={Boolean(detailIssues.LieuCmdDetail)} aria-describedby={detailIssues.LieuCmdDetail?prefix+"place-"+detailLine.article.ID_Article+"-error":undefined}/></Field>
          <Field id={prefix+"remise-"+detailLine.article.ID_Article} label="Remise historique"><input id={prefix+"remise-"+detailLine.article.ID_Article} value={detailLine.RemiseCmdDetail==null?"Non renseignée":detailLine.RemiseCmdDetail?"Oui":"Non"} readOnly/></Field>
          <Field id={prefix+"selected-"+detailLine.article.ID_Article} label="Sélection enregistrée" error={detailIssues.SelectCmdDetail}><SearchSelect id={prefix+"selected-"+detailLine.article.ID_Article} label="Sélection enregistrée" value={detailLine.SelectCmdDetail==null?"":String(detailLine.SelectCmdDetail)} options={[{value:"",label:"Non renseignée"},{value:"true",label:"Oui"},{value:"false",label:"Non"}]} onChange={value=>changeLine(detailLine.article.ID_Article,"SelectCmdDetail",value===""?null:value==="true")} disabled={detailDisabled} invalid={Boolean(detailIssues.SelectCmdDetail)} aria-describedby={detailIssues.SelectCmdDetail?prefix+"selected-"+detailLine.article.ID_Article+"-error":undefined}/></Field>
        </div>{detailPrice!==""&&detailPrice!==detailLine.PUCmdDetail?<button type="button" className="erp-object-link bon-composer-catalogue-price" disabled={detailDisabled} onClick={()=>changeLine(detailLine.article.ID_Article,"PUCmdDetail",detailPrice)}>Utiliser le prix catalogue : {formatCurrency(detailPrice,currencyCode)}</button>:null}</section></section>
        {!order?<section role="tabpanel" id={detailPrefix+"-panel-lots"} aria-labelledby={detailPrefix+"-tab-lots"} hidden={lineDetail.section!=="lots"} tabIndex={lineDetail.section==="lots"?0:-1}>
          {detailKnown?.error?<div className="record-editor-error" role="alert"><span>{detailKnown.error}</span><ActionButton icon="refresh" disabled={detailDisabled} onClick={()=>loadLots(detailLine.article.ID_Article,{force:true})}>Réessayer</ActionButton></div>:null}
          <div id={prefix+"lots-"+detailLine.article.ID_Article} tabIndex={-1}><LotFields articleId={detailLine.article.ID_Article} value={detailLine.Lots} onChange={lots=>changeLine(detailLine.article.ID_Article,"Lots",lots)} total={detailLine.QteCmdDetail} known={detailKnown?.rows||[]} availability={detailAvailability} loading={Boolean(detailKnown?.loading)} unit={stockUnit(detailLine.article)} outgoing={direction==="sortie"} disabled={detailDisabled||Boolean(detailKnown?.loading)} title={direction==="sortie"?"Lots sortants":"Lots reçus"} error={detailIssues.Lots}/></div>
        </section>:null}
      </DrawerDialog>:null}
      </>:null}
    </div>
  </RecordEditorFrame>;
}
