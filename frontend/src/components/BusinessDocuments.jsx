import {moduleRights} from "../services/moduleAccess";
import {useEffect,useRef,useState} from "react";
import {useAuth} from "../contexts/AuthContext";
import {useEntityScope} from "../contexts/EntityScopeContext";
import ActionButton from "./ActionButton";
import AppIcon from "./AppIcon";
import {requestJson,downloadApiFile} from "../services/api";
import {formatDate} from "../pages/logistique/logistiqueShared";
import "./BusinessDocuments.css";
const LABELS={entree:"Bon d’entrée",sortie:"Bon de sortie",livraison:"Bon de livraison",facture:"Facture",recu:"Reçu",avoir:"Avoir"};
const MIME_TYPES=new Set(["application/pdf","image/jpeg","image/png","image/webp"]);
export default function BusinessDocuments({kind,objectId,types=[],refreshKey=0}){
 const {user}=useAuth(),scope=useEntityScope(),input=useRef(null),mounted=useRef(true),operation=useRef(null),activeIdentity=useRef("");
 const [collection,setCollection]=useState({identity:"",rows:[]}),[error,setError]=useState(""),[failed,setFailed]=useState(null),[busy,setBusy]=useState(false),[loading,setLoading]=useState(true),[version,setVersion]=useState(0),[removing,setRemoving]=useState(null);
 const writable=scope.canWrite&&user?.permissions?.canWriteData===true,canDownload=user?.permissions?.canExportData!==false&&moduleRights(user,"logistique").canExport===true;
 const base="/api/logistique/documents/"+kind+"/"+objectId,identity=scope.scopeKey+":"+base;activeIdentity.current=identity;
 const pieces=collection.identity===identity?collection.rows:[];
 const current=key=>mounted.current&&activeIdentity.current===key;
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
 useEffect(()=>{operation.current=null;setBusy(false);setRemoving(null);setError("");setFailed(null);},[identity]);
 useEffect(()=>{let live=true;setLoading(true);requestJson(base+"/pieces",{requiresAuth:true}).then(result=>{if(!live||!current(identity))return;setLoading(false);if(result?.success)setCollection({identity,rows:Array.isArray(result.data)?result.data:[]});else{setError(result?.message||"Les justificatifs n’ont pas pu être chargés.");setFailed({kind:"list"});}});return()=>{live=false;};},[identity,version,refreshKey]);
 async function download(url,options){
  if(operation.current||!canDownload)return;const key=identity,ticket={};operation.current=ticket;setBusy(true);setError("");setFailed(null);
  try{await downloadApiFile(url,options);}catch(e){if(current(key)){setError(e.message||"Le document n’a pas pu être préparé.");setFailed({kind:"download",url,options});}}
  finally{if(current(key)&&operation.current===ticket){operation.current=null;setBusy(false);}}
 }
 async function upload(event){
  const file=event.target.files?.[0];event.target.value="";if(!file||operation.current||!writable)return;
  if(!MIME_TYPES.has(file.type)){setError("Choisissez un fichier PDF, JPEG, PNG ou WebP.");setFailed(null);return;}
  if(file.size>8*1024*1024){setError("Choisissez un fichier de 8 Mo maximum.");setFailed(null);return;}
  const key=identity,ticket={};operation.current=ticket;setBusy(true);setError("");setFailed(null);const body=new FormData();body.set("file",file);
  const result=await requestJson(base+"/pieces",{requiresAuth:true,method:"POST",body});if(!current(key))return;operation.current=null;setBusy(false);
  if(result?.success)setVersion(v=>v+1);else{setError(!result?.status||result.status>=500?"L’ajout reste à vérifier. Actualisez les justificatifs avant de renvoyer le fichier.":result?.message||"Le justificatif n’a pas pu être ajouté.");setFailed({kind:"list"});}
 }
 async function remove(){
  if(operation.current||!removing||!writable)return;const key=identity,ticket={};operation.current=ticket;setBusy(true);setError("");setFailed(null);
  const result=await requestJson(base+"/pieces/"+removing.ID_Piece,{requiresAuth:true,method:"DELETE"});if(!current(key))return;operation.current=null;setBusy(false);
  if(result?.success){setRemoving(null);setVersion(v=>v+1);}else{setError(result?.message||"Le justificatif n’a pas pu être retiré.");setFailed({kind:"list"});}
 }
 function retry(){if(busy)return;if(failed?.kind==="download")download(failed.url,failed.options);else{setError("");setFailed(null);setVersion(v=>v+1);}}
 return <section className="business-documents record-editor-section"><div className="business-document-heading"><h3><AppIcon name="document"/>Documents</h3><div>{types.map(type=><ActionButton key={type} icon="download" disabled={busy||!canDownload} onClick={()=>download(base+"/"+type+".pdf",{contentType:"application/pdf",filename:type+"-"+objectId+".pdf"})}>{LABELS[type]||type} · PDF</ActionButton>)}</div></div>
  {error?<div className="record-editor-error" role="alert"><span>{error}</span>{failed?<ActionButton icon="refresh" disabled={busy} onClick={retry}>{failed.kind==="download"?"Réessayer le téléchargement":"Actualiser les justificatifs"}</ActionButton>:null}</div>:null}
  <div className="business-document-heading"><h4>Justificatifs {pieces.length?<span className="business-document-count">{pieces.length}</span>:null}</h4>{writable?<><input ref={input} type="file" accept="application/pdf,image/jpeg,image/png,image/webp" hidden onChange={upload}/><ActionButton icon="plus" disabled={busy} onClick={()=>input.current?.click()}>Ajouter un justificatif</ActionButton></>:null}</div>
  {loading&&collection.identity!==identity?<p role="status" className="record-editor-note">Chargement des justificatifs…</p>:pieces.length?<ul className="business-document-list" aria-busy={loading}>{pieces.map(piece=><li key={piece.ID_Piece}><AppIcon name="document"/><div><strong>{piece.NomFichier}</strong><small>{formatDate(piece.CreeLe,{withTime:true})} · {Math.ceil(piece.TailleOctets/1024)} Ko</small></div><ActionButton icon="download" disabled={busy||!canDownload} onClick={()=>download(base+"/pieces/"+piece.ID_Piece,{contentType:piece.MimeType,filename:piece.NomFichier})}>Télécharger</ActionButton>{writable?<ActionButton icon="trash" disabled={busy} title="Retirer ce justificatif" aria-label={"Retirer "+piece.NomFichier} onClick={()=>setRemoving(piece)}/>:null}</li>)}</ul>:<p className="record-editor-note">Aucun justificatif.</p>}
  {removing?<div className="record-discard" role="alert"><span>Retirer « {removing.NomFichier} » de la liste active ?</span><div><ActionButton disabled={busy} onClick={()=>setRemoving(null)}>Conserver</ActionButton><ActionButton disabled={busy} onClick={remove}>Retirer</ActionButton></div></div>:null}
 </section>;
}