import {useEffect,useRef,useState} from "react";
import {useAuth} from "../../contexts/AuthContext";
import DrawerDialog from "../../components/DrawerDialog";
import ActionButton from "../../components/ActionButton";
import {requestJson} from "../../services/api";
import "../../components/RecordEditor.css";

export default function OrderDeleteDialog({commandeId,onClose,onSaved}) {
  const {user}=useAuth(),[record,setRecord]=useState(null),[meta,setMeta]=useState(null),[loading,setLoading]=useState(true),[busy,setBusy]=useState(false),[error,setError]=useState(""),[revision,setRevision]=useState(0);
  const mounted=useRef(true),saving=useRef(false);
  useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
  useEffect(()=>{let active=true;setLoading(true);setError("");setRecord(null);setMeta(null);requestJson("/api/logistique/commandes/"+commandeId,{requiresAuth:true}).then(response=>{if(!active)return;if(response?.success){setRecord(response.data);setMeta(response.meta||null);}else setError(response?.message||"Le bon n’a pas pu être chargé.");setLoading(false);});return()=>{active=false;};},[commandeId,revision]);
  const enabled=user?.permissions?.canWriteData===true&&!loading&&!busy&&Boolean(meta?.revision)&&meta?.canDelete===true;
  async function remove(){if(!enabled||saving.current)return;saving.current=true;setBusy(true);setError("");const response=await requestJson("/api/logistique/commandes/"+commandeId,{method:"DELETE",requiresAuth:true,body:JSON.stringify({_version:meta.revision})});if(!mounted.current)return;saving.current=false;setBusy(false);if(!response?.success){setError(response?.message||"Le bon n’a pas pu être supprimé.");return;}onSaved(record,"deleted");}
  return <DrawerDialog title="Supprimer le bon de stock" icon="trash" defaultWidth={540} storageKey="sauverndeko.commande-delete.width" bodyClassName="record-editor-body" onClose={onClose} busy={busy} footer={<footer className="record-editor-footer"><span/><div><ActionButton onClick={onClose} disabled={busy}>Annuler</ActionButton><ActionButton icon="trash" variant="primary" className="is-danger" onClick={remove} disabled={!enabled}>{busy?"Suppression…":"Supprimer définitivement"}</ActionButton></div></footer>}>
    {loading?<p className="record-editor-state" role="status">Chargement du bon…</p>:null}
    {record?<><div className="record-action-summary"><strong>{record.CodeCmd||"Bon sans code"}</strong><p>{record.RefCmd||record.NomClientSaisi||""}</p></div><p className="record-action-copy">Cette suppression est définitive. Seul un bon vide, sans historique ni facturation, peut être supprimé.</p>{meta?.canDelete!==true?<p className="record-editor-error" role="status">{meta?.deleteReason||"Ce bon doit être conservé avec son historique."}</p>:null}</>:null}
    {error?<div className="record-editor-error" role="alert"><span>{error}</span><ActionButton icon="refresh" onClick={()=>setRevision(value=>value+1)} disabled={busy}>Recharger le bon</ActionButton></div>:null}
  </DrawerDialog>;
}
