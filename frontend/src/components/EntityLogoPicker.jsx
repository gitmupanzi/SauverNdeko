import {useEffect,useRef,useState} from "react";
import {fetchEntityLogo} from "../services/entityProfile";
import {entityLogoError} from "../utils/entityProfile";
import ActionButton from "./ActionButton";
import AppIcon from "./AppIcon";

export default function EntityLogoPicker({record,value,onChange,disabled=false,readOnly=false,error="",contextKey=""}){
  const input=useRef(null),[picture,setPicture]=useState(""),[failure,setFailure]=useState(""),[loading,setLoading]=useState(false),[revision,setRevision]=useState(0);
  useEffect(()=>{
    let live=true,objectUrl="";const controller=new AbortController();setPicture("");setFailure("");setLoading(false);
    const publish=blob=>{if(!live)return;objectUrl=URL.createObjectURL(blob);setPicture(objectUrl);setLoading(false);};
    if(value.file)publish(value.file);
    else if(!value.remove&&record?.HasLogo){setLoading(true);fetchEntityLogo(record,{signal:controller.signal}).then(publish).catch(error=>{if(live&&error.name!=="AbortError"){setLoading(false);setFailure(error.message||"Le logo n’a pas pu être chargé.");}});}
    return()=>{live=false;controller.abort();if(objectUrl)URL.revokeObjectURL(objectUrl);};
  },[contextKey,record?.IdEntite,record?.HasLogo,record?.LogoSha256Entite,record?.LogoModifieLe,value.file,value.remove,revision]);
  function choose(file){if(!file||disabled)return;const issue=entityLogoError(file);setFailure(issue);if(!issue)onChange({file,remove:false});}
  return <section className="entity-profile-logo" aria-label="Logo de l’entreprise">
    <div className="entity-profile-logo-preview" aria-busy={loading}>{picture?<img src={picture} alt={"Logo de "+(record?.NomEntite||"l’entreprise")}/>:<AppIcon name="apps" size={34}/>}</div>
    <div><strong>Logo de l’entreprise</strong><p className="record-editor-note">PNG, JPEG ou WebP · 2 Mo maximum</p>{loading?<p className="record-editor-note" role="status">Chargement du logo…</p>:null}
      {!readOnly?<div className="entity-profile-inline"><input ref={input} type="file" hidden accept="image/png,image/jpeg,image/webp" disabled={disabled} onChange={event=>{choose(event.target.files?.[0]);event.target.value="";}}/><ActionButton icon="document" disabled={disabled} onClick={()=>input.current?.click()}>Choisir un logo</ActionButton>{value.file||!value.remove&&record?.HasLogo?<ActionButton icon="trash" disabled={disabled} onClick={()=>onChange({file:null,remove:true})}>Retirer</ActionButton>:null}{value.file||value.remove?<ActionButton icon="reset" disabled={disabled} onClick={()=>onChange({file:null,remove:false})}>Rétablir</ActionButton>:null}</div>:!record?.HasLogo?<p className="record-editor-note">Aucun logo enregistré.</p>:null}
      {error||failure?<p className="record-field-error" role="alert">{error||failure}{failure&&!value.file&&record?.HasLogo?<button type="button" className="erp-object-link" disabled={disabled} onClick={()=>setRevision(value=>value+1)}>Réessayer</button>:null}</p>:null}
    </div>
  </section>;
}
