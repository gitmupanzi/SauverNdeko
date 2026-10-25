import {useEffect,useRef,useState} from "react";
import ArticlePhoto from "./ArticlePhoto";
import ActionButton from "./ActionButton";
import AppIcon from "./AppIcon";
import "./ProductPhotoPicker.css";
export default function ProductPhotoPicker({record,value,onChange,disabled=false,error=""}){
 const input=useRef(null),video=useRef(null),stream=useRef(null),mounted=useRef(true);
 const [preview,setPreview]=useState(""),[camera,setCamera]=useState(false),[opening,setOpening]=useState(false),[message,setMessage]=useState("");
 function stop(){stream.current?.getTracks().forEach(track=>track.stop());stream.current=null;setCamera(false);setOpening(false);}
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;stream.current?.getTracks().forEach(track=>track.stop());};},[]);
 useEffect(()=>{if(!value.file){setPreview("");return;}const url=URL.createObjectURL(value.file);setPreview(url);return()=>URL.revokeObjectURL(url);},[value.file]);
 useEffect(()=>{if(camera&&video.current&&stream.current){video.current.srcObject=stream.current;void video.current.play().catch(()=>{});}},[camera]);
 async function openCamera(){
  if(disabled||opening)return;setMessage("");
  if(!navigator.mediaDevices?.getUserMedia){setMessage("La caméra n’est pas disponible ici. Choisissez une photo.");return;}
  setOpening(true);
  try{
   const capture=await navigator.mediaDevices.getUserMedia({video:{facingMode:{ideal:"environment"},width:{ideal:1600},height:{ideal:1200}},audio:false});
   if(!mounted.current){capture.getTracks().forEach(track=>track.stop());return;}
   stream.current=capture;setCamera(true);
  }catch{if(mounted.current)setMessage("La caméra n’a pas pu être ouverte. Vérifiez son autorisation ou choisissez une photo.");}
  finally{if(mounted.current)setOpening(false);}
 }
 function choose(file){
  if(!file)return;setMessage("");
  if(!["image/jpeg","image/png","image/webp"].includes(file.type)){setMessage("Choisissez une photo JPEG, PNG ou WebP.");return;}
  if(file.size>8*1024*1024){setMessage("La photo ne doit pas dépasser 8 Mo.");return;}
  onChange({file,remove:false});stop();
 }
 function shoot(){
  const source=video.current;if(!source?.videoWidth){setMessage("La caméra n’est pas encore prête.");return;}
  const scale=Math.min(1,1600/Math.max(source.videoWidth,source.videoHeight)),canvas=document.createElement("canvas");
  canvas.width=Math.round(source.videoWidth*scale);canvas.height=Math.round(source.videoHeight*scale);
  canvas.getContext("2d").drawImage(source,0,0,canvas.width,canvas.height);
  canvas.toBlob(blob=>{if(blob&&mounted.current)choose(new File([blob],"capture.jpg",{type:"image/jpeg"}));},"image/jpeg",.9);
 }
 const hasPhoto=Boolean(preview||(!value.remove&&record?.PhotoArticle));
 return <section className="product-photo-picker" aria-label="Photo du produit">
  <div className="product-photo-preview">{preview?<img src={preview} alt="Nouvelle photo du produit"/>:!value.remove&&record?.PhotoArticle?<ArticlePhoto record={record}/>:<AppIcon name="box" size={36}/>}</div>
  <div className="product-photo-tools"><strong>Photo du produit</strong><span>JPEG, PNG ou WebP · 8 Mo maximum</span><div><ActionButton icon="document" disabled={disabled||opening} onClick={()=>input.current?.click()}>Choisir une photo</ActionButton><ActionButton icon="camera" disabled={disabled||opening} onClick={openCamera}>{opening?"Ouverture…":"Prendre une photo"}</ActionButton></div>
   <input ref={input} type="file" accept="image/jpeg,image/png,image/webp" aria-label="Choisir la photo du produit" hidden disabled={disabled} onChange={e=>{choose(e.target.files?.[0]);e.target.value="";}}/>
   {hasPhoto?<button className="product-photo-link" type="button" disabled={disabled} onClick={()=>onChange({file:null,remove:true})}>Retirer la photo</button>:null}
   {value.file||value.remove?<button className="product-photo-link" type="button" disabled={disabled} onClick={()=>onChange({file:null,remove:false})}>Rétablir la photo</button>:null}
  </div>
  {camera?<div className="product-camera"><video ref={video} autoPlay playsInline muted aria-label="Aperçu de la caméra"/><div><ActionButton onClick={stop}>Fermer la caméra</ActionButton><ActionButton icon="camera" variant="primary" onClick={shoot}>Capturer</ActionButton></div></div>:null}
  {error||message?<p className="record-field-error" role="alert">{error||message}</p>:null}
 </section>;
}
