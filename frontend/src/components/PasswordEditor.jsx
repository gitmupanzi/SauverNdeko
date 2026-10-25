import {useEffect,useId,useRef,useState} from "react";
import RecordEditorFrame from "./RecordEditorFrame";
import AppIcon from "./AppIcon";
import {fetchPasswordPolicy,changeCurrentUserPassword} from "../services/auth";
import {passwordErrors} from "../utils/passwordForm";
import "./PasswordEditor.css";

const FIELDS=[{name:"currentPassword",label:"Mot de passe actuel",complete:"current-password"},{name:"newPassword",label:"Nouveau mot de passe",complete:"new-password"},{name:"confirmPassword",label:"Confirmer le nouveau mot de passe",complete:"new-password"}];
export default function PasswordEditor({onClose,onChanged}) {
  const prefix=useId(),mounted=useRef(true),saving=useRef(false),first=useRef(null);
  const [policy,setPolicy]=useState(null),[loading,setLoading]=useState(true),[busy,setBusy]=useState(false),[error,setError]=useState(""),[errors,setErrors]=useState({}),[revision,setRevision]=useState(0);
  const [values,setValues]=useState({currentPassword:"",newPassword:"",confirmPassword:""}),[visible,setVisible]=useState({});
  const dirty=Object.values(values).some(Boolean),allowed=policy?.canChangePassword===true;
  useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
  useEffect(()=>{let active=true;setLoading(true);setError("");fetchPasswordPolicy().then(result=>{
    if(!active)return;
    if(!result?.success){setPolicy(null);setError(result?.message||"La modification du mot de passe est indisponible.");}
    else setPolicy(result.data);
    setLoading(false);
  });return()=>{active=false;};},[revision]);
  useEffect(()=>{if(loading||!allowed)return;const frame=requestAnimationFrame(()=>first.current?.focus({preventScroll:true}));return()=>cancelAnimationFrame(frame);},[loading,allowed]);
  useEffect(()=>{if(!dirty&&!busy)return;const prevent=event=>{event.preventDefault();event.returnValue="";};window.addEventListener("beforeunload",prevent);return()=>window.removeEventListener("beforeunload",prevent);},[dirty,busy]);
  function change(name,value){if(saving.current)return;setValues(current=>({...current,[name]:value}));setErrors(current=>({...current,[name]:""}));setError("");}
  function focusInvalid(invalid){requestAnimationFrame(()=>document.getElementById(prefix+Object.keys(invalid)[0])?.focus());}
  async function submit(){
    if(saving.current||!allowed)return;
    const invalid=passwordErrors(values,policy);setErrors(invalid);setError("");
    if(Object.keys(invalid).length){setError("Vérifiez les champs indiqués.");focusInvalid(invalid);return;}
    saving.current=true;setBusy(true);
    const result=await changeCurrentUserPassword(values);
    if(!mounted.current)return;
    saving.current=false;setBusy(false);
    if(!result?.success){
      const details=result?.error?.details;
      const invalid=details&&typeof details==="object"&&!Array.isArray(details)?Object.fromEntries(Object.entries(details).filter(([key])=>key in values).map(([key,value])=>[key,Array.isArray(value)?value.join(" "):String(value)])):{};
      setErrors(invalid);setError(Object.keys(invalid).length?"Vérifiez les champs indiqués.":result?.status===429?"Trop de tentatives. Réessayez dans un instant.":result?.message||"Le mot de passe n’a pas pu être modifié.");
      if(Object.keys(invalid).length)focusInvalid(invalid);return;
    }
    setValues({currentPassword:"",newPassword:"",confirmPassword:""});setVisible({});onChanged();
  }
  return <RecordEditorFrame title="Modifier le mot de passe" subtitle="Sécurité du compte" icon="lock" onClose={onClose} onSubmit={submit} submitLabel="Modifier le mot de passe" loading={loading} busy={busy} dirty={dirty} canSubmit={allowed&&dirty} error={error} onReload={!loading&&!policy?()=>setRevision(value=>value+1):null} storageKey="sauverndeko.password-editor.width">
    {!loading&&policy?<section className="record-editor-section password-editor-section"><h3><AppIcon name="lock"/>Mot de passe</h3>
      {!allowed?<p className="password-editor-note" role="status">La modification du mot de passe est actuellement indisponible.</p>:<>
        <p className="password-editor-note">Confirmez votre mot de passe actuel. Vous devrez vous reconnecter après la modification.</p>
        <div className="password-editor-fields">{FIELDS.map(({name,label,complete},index)=>{
          const id=prefix+name,hint=name==="newPassword"?"De "+policy.minLength+" à "+policy.maxLength+" caractères. Évitez les mots de passe courants et vos informations personnelles.":"";
          return <div className="record-field" key={name}><label htmlFor={id}>{label}</label><div className="password-editor-input"><input ref={index===0?first:null} id={id} name={name} type={visible[name]?"text":"password"} value={values[name]} onChange={event=>change(name,event.target.value)} disabled={busy} autoComplete={complete} autoCapitalize="none" spellCheck={false} maxLength={(name==="currentPassword"?policy.currentPasswordMaxLength:policy.maxLength)*2} aria-invalid={Boolean(errors[name])} aria-describedby={errors[name]?id+"-error":hint?id+"-hint":undefined}/><button type="button" onClick={()=>setVisible(current=>({...current,[name]:!current[name]}))} disabled={busy} aria-label={(visible[name]?"Masquer":"Afficher")+" · "+label} aria-pressed={Boolean(visible[name])} aria-controls={id}><AppIcon name={visible[name]?"eye-off":"eye"}/></button></div>{errors[name]?<small className="record-field-error" id={id+"-error"}>{errors[name]}</small>:hint?<small id={id+"-hint"}>{hint}</small>:null}</div>;
        })}</div>
      </>}
    </section>:null}
  </RecordEditorFrame>;
}
