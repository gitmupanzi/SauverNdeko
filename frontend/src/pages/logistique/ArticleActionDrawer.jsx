import {useEffect,useRef,useState} from "react";
import DrawerDialog from "../../components/DrawerDialog";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import {useAuth} from "../../contexts/AuthContext";
import {fetchLogistiqueArticle,deleteLogistiqueArticle,hardDeleteLogistiqueArticle,updateLogistiqueArticle} from "../../services/logistique";
import "../../components/RecordEditor.css";
const LABELS={disable:"Désactiver l’article",enable:"Réactiver l’article",delete:"Supprimer l’article"};
export default function ArticleActionDrawer({articleId,action,onClose,onSaved}){
 const {user}=useAuth(),[data,setData]=useState(null),[meta,setMeta]=useState(null),[loading,setLoading]=useState(true),[busy,setBusy]=useState(false),[error,setError]=useState(""),[revision,setRevision]=useState(0);
 const mounted=useRef(true),saving=useRef(false);
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
 useEffect(()=>{let active=true;setLoading(true);setError("");fetchLogistiqueArticle(articleId).then(result=>{if(!active)return;if(result?.success){setData(result.data);setMeta(result.meta);}else{setData(null);setMeta(null);setError(result?.message||"La fiche n’a pas pu être chargée.");}setLoading(false);});return()=>{active=false;};},[articleId,revision]);
 const reason=action==="delete"&&!meta?.canDelete?meta?.deleteReason:action==="disable"&&data?.ValideArticle===false?"Cet article est déjà désactivé.":action==="enable"&&data?.ValideArticle===true?"Cet article est déjà actif.":"";
 const enabled=user?.permissions?.canWriteData===true&&!loading&&!busy&&meta?.revision&&!reason;
 async function submit(){
  if(!enabled||saving.current)return;saving.current=true;setBusy(true);setError("");
  const response=action==="delete"?await hardDeleteLogistiqueArticle(articleId,meta.revision):action==="disable"?await deleteLogistiqueArticle(articleId,meta.revision):await updateLogistiqueArticle(articleId,{ValideArticle:true,_version:meta.revision});
  if(!mounted.current)return;saving.current=false;setBusy(false);
  if(!response?.success){setError(response?.message||"L’opération n’a pas pu être terminée.");return;}
  onSaved(response.data,action==="delete"?"deleted":action==="disable"?"disabled":"enabled");
 }
 return <DrawerDialog title={LABELS[action]} icon={action==="delete"?"trash":"box"} onClose={onClose} busy={busy} defaultWidth={540} storageKey="sauverndeko.article-action.width" bodyClassName="record-editor-body" footer={<footer className="record-editor-footer"><span/><div><ActionButton disabled={busy} onClick={onClose}>Annuler</ActionButton><ActionButton icon={action==="delete"?"trash":"check-circle"} variant="primary" className={action==="delete"?"is-danger":""} disabled={!enabled} onClick={submit}>{busy?"Traitement…":action==="delete"?"Supprimer définitivement":action==="disable"?"Désactiver":"Réactiver"}</ActionButton></div></footer>}>
  {loading?<p className="record-editor-state" role="status">Chargement de la fiche…</p>:null}
  {data?<><div className="record-action-summary"><strong>{data.NomArticle}</strong><p>{data.CodeArticleInterne?"Code : "+data.CodeArticleInterne:"Code interne non renseigné"}</p><p>{data.RefArticle?"Réf. : "+data.RefArticle:"Référence non renseignée"}</p></div><p className="record-action-copy">{action==="disable"?"L’article restera consultable avec son historique. Il ne pourra plus être ajouté à de nouveaux bons.":action==="enable"?"L’article sera à nouveau disponible pour les nouveaux bons de stock.":"Cette suppression est définitive. Elle est possible uniquement pour un article désactivé, sans stock ni historique."}</p></>:null}
  {reason?<p className="record-editor-error" role="status"><AppIcon name="alert"/>{reason}</p>:null}
  {error?<div className="record-editor-error" role="alert"><span>{error}</span><ActionButton icon="refresh" onClick={()=>setRevision(x=>x+1)}>Recharger</ActionButton></div>:null}
 </DrawerDialog>;
}
