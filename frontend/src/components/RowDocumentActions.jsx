import {moduleRights} from "../services/moduleAccess";
import {useEffect,useRef,useState} from "react";
import {createPortal} from "react-dom";
import {useAuth} from "../contexts/AuthContext";
import {useEntityScope} from "../contexts/EntityScopeContext";
import {downloadApiFile} from "../services/api";
import RowActionsMenu from "./RowActionsMenu";
import ActionButton from "./ActionButton";
import "./RowDocumentActions.css";
export default function RowDocumentActions({documents=[],disabled=false,...props}){
 const {user}=useAuth(),scope=useEntityScope(),host=useRef(null),operation=useRef(null),mounted=useRef(true);
 const [busy,setBusy]=useState(false),[error,setError]=useState(''),[failed,setFailed]=useState(null),[label,setLabel]=useState('');
 const identity=scope.scopeKey+':'+JSON.stringify(documents),currentIdentity=useRef(identity);currentIdentity.current=identity;
 const allowed=user?.permissions?.canExportData!==false&&moduleRights(user,"logistique").canExport===true;
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;operation.current?.abort();};},[]);
 useEffect(()=>{operation.current?.abort();operation.current=null;setBusy(false);setError('');setFailed(null);return()=>operation.current?.abort();},[identity]);
 async function download(item){if(disabled||!allowed||operation.current||!item)return;const key=identity,controller=new AbortController();operation.current=controller;setBusy(true);setError('');setFailed(null);setLabel(item.label);try{await downloadApiFile(item.url,{signal:controller.signal,filename:item.filename,...(item.contentType?{contentType:item.contentType}:{})});}catch(failure){if(!controller.signal.aborted&&mounted.current&&currentIdentity.current===key){setError(failure.message||'Le téléchargement a échoué.');setFailed(item);}}finally{if(mounted.current&&currentIdentity.current===key&&operation.current===controller){operation.current=null;setBusy(false);}}}
 const exports=allowed?documents.filter(Boolean).map(item=>({label:item.label,icon:'download',disabled:disabled||busy,onSelect:()=>download(item)})):[];
 return <span ref={host} className="row-document-actions"><RowActionsMenu {...props} items={[...(props.items||[]),...exports]}/>{(busy||error)?createPortal(<div className="row-document-notice" role={error?'alert':'status'}><strong>{label}</strong><span>{error||'Préparation du téléchargement…'}</span>{error?<div><ActionButton icon="download" disabled={disabled||busy} onClick={()=>download(failed)}>Réessayer</ActionButton><ActionButton icon="close" aria-label="Fermer le message de téléchargement" onClick={()=>{setError('');setFailed(null);}}/></div>:null}</div>,host.current?.closest('dialog')||document.body):null}</span>;
}
