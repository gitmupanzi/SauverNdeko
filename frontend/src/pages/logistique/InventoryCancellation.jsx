import {useEffect,useRef,useState} from 'react';
import RecordEditorFrame from '../../components/RecordEditorFrame';
import {requestJson} from '../../services/api';
import {inventoryError} from './InventoryEditor';
import {formatDate} from './logistiqueShared';

export default function InventoryCancellation({inventory,onClose,onSaved}){
 const [motif,setMotif]=useState(''),[busy,setBusy]=useState(false),[error,setError]=useState('');
 const ticket=useRef(null),live=useRef(true);
 useEffect(()=>{live.current=true;return ()=>{live.current=false;};},[]);
 async function submit(){
  if(busy||!motif.trim())return;
  if(!ticket.current||ticket.current.motif!==motif.trim())ticket.current={requestId:crypto.randomUUID(),_version:inventory.Version,motif:motif.trim()};
  setBusy(true);setError('');
  const response=await requestJson('/api/logistique/inventaires/'+inventory.ID_Inventaire+'/annuler',{method:'POST',requiresAuth:true,body:JSON.stringify(ticket.current)});
  if(!live.current)return;setBusy(false);
  if(!response.success){setError(inventoryError(response,'L’annulation n’a pas pu être enregistrée.'));return;}
  onSaved(response.data);
 }
 return <RecordEditorFrame title="Annuler la validation" subtitle={inventory.CodeInventaire} icon="reset" defaultWidth={680} storageKey="sauverndeko.inventory-cancellation.width" busy={busy} error={error} dirty={!!motif} canSubmit={!!motif.trim()} onSubmit={submit} onClose={onClose} submitLabel="Confirmer l’annulation">
  <section className="record-editor-section"><h3>{inventory.CodeInventaire}</h3><p>Validé le {formatDate(inventory.ValideLe)}</p><p>Des mouvements inverses corrigeront le stock actuel. Le comptage et ses écritures d’origine seront conservés.</p><label className="record-field">Motif de l’annulation *<textarea rows={4} maxLength={1000} value={motif} disabled={busy} autoFocus onChange={event=>setMotif(event.target.value)} placeholder="Précisez la raison de cette correction."/></label></section>
 </RecordEditorFrame>;
}
