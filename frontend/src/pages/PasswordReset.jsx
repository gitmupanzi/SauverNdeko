import {useEffect,useId,useLayoutEffect,useRef,useState} from "react";
import {Link,useLocation,useNavigate} from "react-router-dom";
import ThemePicker from "../components/ThemePicker";
import AppIcon from "../components/AppIcon";
import DrawerDialog from "../components/DrawerDialog";
import ActionButton from "../components/ActionButton";
import {useAuth} from "../contexts/AuthContext";
import {requestJson} from "../services/api";
import "./Login.css";
import "./PasswordReset.css";

const BASE="/SauverNdeko/auth/password-reset";
const EMPTY_PASSWORDS={newPassword:"",confirmPassword:""};

export function resetCredentials(location) {
  const hash=new URLSearchParams((location.hash || "").replace(/^#/,""));
  const query=new URLSearchParams(location.search || "");
  const parameters=hash.has("uid") || hash.has("token") ? hash : query;
  if(!parameters.has("uid")&&!parameters.has("token"))return null;
  const uid=parameters.get("uid") || "",token=parameters.get("token") || "";
  return {uid,token,malformed:!uid||!token||uid.length>256||token.length>512||!/^[A-Za-z0-9_=-]+$/.test(uid)||!/^[A-Za-z0-9_-]+$/.test(token)};
}
export function resetLinkUpdate(current,location) {
  const incoming=resetCredentials(location);
  if(!incoming)return {credentials:current,changed:false,clean:false};
  const same=current&&current.uid===incoming.uid&&current.token===incoming.token&&current.malformed===incoming.malformed;
  return {credentials:same?current:incoming,changed:!same,clean:true};
}
export function resetPasswordErrors(values,policy) {
  const errors={},length=Array.from(values.newPassword).length;
  if(!values.newPassword.trim())errors.newPassword="Saisissez un nouveau mot de passe.";
  else if(length<policy.minLength)errors.newPassword="Utilisez au moins "+policy.minLength+" caractères.";
  else if(length>policy.maxLength)errors.newPassword="Utilisez au maximum "+policy.maxLength+" caractères.";
  if(!values.confirmPassword)errors.confirmPassword="Confirmez le nouveau mot de passe.";
  else if(values.confirmPassword!==values.newPassword)errors.confirmPassword="Les mots de passe ne correspondent pas.";
  return errors;
}
function validPolicy(value) {
  return value && Number.isInteger(value.minLength)&&Number.isInteger(value.maxLength)&&value.minLength>0&&value.maxLength>=value.minLength&&value.maxLength<=1024;
}
function resetError(result) {
  if(result?.status===429)return "Trop de demandes. Réessayez dans quelques instants.";
  if(result?.status===503||result?.error?.code==="RESET_UNAVAILABLE")return "La récupération du mot de passe est indisponible pour le moment. Contactez votre administrateur.";
  if(result?.error?.code==="RESET_TIMEOUT")return "Le service ne répond pas. Réessayez.";
  if(result?.status===0)return "Service injoignable. Vérifiez votre connexion.";
  return "La demande n’a pas pu être traitée. Réessayez.";
}
async function resetRequest(path,body,controller) {
  let timedOut=false;
  const timer=window.setTimeout(()=>{timedOut=true;controller.abort();},25000);
  try {
    const result=await requestJson(BASE+path,{method:body?"POST":"GET",...(body?{body:JSON.stringify(body)}:{}),signal:controller.signal});
    return timedOut?{success:false,status:0,error:{code:"RESET_TIMEOUT"}}:result;
  } finally {window.clearTimeout(timer);}
}

export default function PasswordReset() {
  const location=useLocation(),navigate=useNavigate(),{endLocalSession}=useAuth(),prefix=useId();
  const [credentials,setCredentials]=useState(()=>resetCredentials(location));
  const credentialsRef=useRef(credentials);
  const confirming=credentials!==null;
  const [phase,setPhase]=useState("loading"),[policy,setPolicy]=useState(null),[revision,setRevision]=useState(0);
  const [email,setEmail]=useState(""),[passwords,setPasswords]=useState(EMPTY_PASSWORDS),[visible,setVisible]=useState({});
  const [busy,setBusy]=useState(false),[error,setError]=useState(""),[errors,setErrors]=useState({}),[leaveTarget,setLeaveTarget]=useState(null);
  const emailRef=useRef(null),passwordRef=useRef(null),headingRef=useRef(null),errorRef=useRef(null),mounted=useRef(true),saving=useRef(false),pending=useRef(null);
  const dirty=Boolean(passwords.newPassword||passwords.confirmPassword);
  useLayoutEffect(()=>{
    const previousTitle=document.title;
    document.title="Mot de passe oublié | SauverNdeko";
    const previousMeta=document.head.querySelector('meta[name="referrer"]'),oldReferrer=previousMeta?.getAttribute("content");
    const referrer=previousMeta || document.createElement("meta");referrer.name="referrer";referrer.content="no-referrer";if(!previousMeta)document.head.appendChild(referrer);
    return()=>{document.title=previousTitle;if(previousMeta){if(oldReferrer==null)referrer.removeAttribute("content");else referrer.content=oldReferrer;}else referrer.remove();};
  },[]);
  useLayoutEffect(()=>{
    const next=resetLinkUpdate(credentialsRef.current,location);
    if(!next.clean)return;
    if(next.changed){
      pending.current?.abort();pending.current=null;saving.current=false;
      credentialsRef.current=next.credentials;setCredentials(next.credentials);
      setPasswords(EMPTY_PASSWORDS);setVisible({});setLeaveTarget(null);setErrors({});setError("");setPolicy(null);setPhase("loading");setBusy(false);
    }
    navigate("/reset-password",{replace:true});
  },[location.hash,location.search,navigate]);
  useEffect(()=>{document.title=(confirming?"Nouveau mot de passe":"Mot de passe oublié")+" | SauverNdeko";},[confirming]);
  useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;pending.current?.abort();pending.current=null;};},[]);
  useEffect(()=>{
    let active=true;const controller=new AbortController(),context=credentials;
    if(credentialsRef.current!==context)return()=>{active=false;controller.abort();};
    setPhase("loading");setError("");setErrors({});setPolicy(null);
    if(credentials?.malformed){setPhase("invalid");return()=>{active=false;controller.abort();};}
    resetRequest(confirming?"/check":"",confirming?{uid:credentials.uid,token:credentials.token}:null,controller).then(result=>{
      if(!active||credentialsRef.current!==context)return;
      if(!result?.success){setPhase(result?.error?.code==="RESET_LINK_INVALID"?"invalid":"unavailable");setError(resetError(result));return;}
      const next=result.data;
      if(!validPolicy(next)){setPhase("unavailable");setError("La récupération du mot de passe est indisponible pour le moment. Contactez votre administrateur.");return;}
      if(confirming&&next.valid!==true){setPhase("invalid");return;}
      if(!confirming&&next.available!==true){setPhase("unavailable");setError("La récupération du mot de passe est indisponible pour le moment. Contactez votre administrateur.");return;}
      setPolicy(next);setPhase("ready");
    });
    return()=>{active=false;controller.abort();};
  },[credentials,revision,confirming]);
  useEffect(()=>{
    if(phase==="loading")return;
    const frame=requestAnimationFrame(()=>{
      if(phase==="ready")(confirming?passwordRef:emailRef).current?.focus({preventScroll:true});
      else headingRef.current?.focus({preventScroll:true});
    });return()=>cancelAnimationFrame(frame);
  },[phase,confirming]);
  useEffect(()=>{if(error&&phase==="ready")errorRef.current?.focus({preventScroll:true});},[error,phase]);
  useEffect(()=>{
    if(!dirty&&!busy)return;
    const prevent=event=>{event.preventDefault();event.returnValue="";};window.addEventListener("beforeunload",prevent);
    return()=>window.removeEventListener("beforeunload",prevent);
  },[dirty,busy]);
  function clearCredentials(){credentialsRef.current=null;setCredentials(null);}
  function changePassword(name,value){if(saving.current)return;setPasswords(current=>({...current,[name]:value}));setErrors(current=>({...current,[name]:""}));setError("");}
  function requestLeave(event,path){if(busy){event.preventDefault();return;}if(dirty){event.preventDefault();setLeaveTarget(path);}}
  function renewLink(event){event?.preventDefault();if(busy)return;if(dirty){setLeaveTarget("/reset-password");return;}clearCredentials();setPasswords(EMPTY_PASSWORDS);setVisible({});navigate("/reset-password",{replace:true});}
  function leave(){const target=leaveTarget;setLeaveTarget(null);setPasswords(EMPTY_PASSWORDS);setVisible({});if(target==="/reset-password")clearCredentials();navigate(target,{replace:target==="/reset-password"});}
  async function submit(event) {
    event.preventDefault();if(saving.current||phase!=="ready"||!policy)return;
    const invalid=confirming?resetPasswordErrors(passwords,policy):!email.trim()?{email:"Saisissez votre adresse e-mail."}:emailRef.current?.validity.typeMismatch?{email:"Saisissez une adresse e-mail valide."}:{};
    setErrors(invalid);setError("");
    if(Object.keys(invalid).length){requestAnimationFrame(()=>document.getElementById(prefix+Object.keys(invalid)[0])?.focus());return;}
    const controller=new AbortController();pending.current=controller;saving.current=true;setBusy(true);
    try {
      const body=confirming?{uid:credentials.uid,token:credentials.token,...passwords}:{email:email.trim()};
      const result=await resetRequest(confirming?"/confirm":"",body,controller);
      if(!mounted.current||pending.current!==controller)return;
      if(!result?.success){
        if(result?.error?.code==="RESET_LINK_INVALID"){setPasswords(EMPTY_PASSWORDS);setVisible({});setPhase("invalid");return;}
        const details=result?.error?.details,allowed=confirming?["newPassword","confirmPassword"]:["email"];
        const fieldErrors=details&&typeof details==="object"&&!Array.isArray(details)?Object.fromEntries(Object.entries(details).filter(([key])=>allowed.includes(key)).map(([key,value])=>[key,Array.isArray(value)?value.join(" "):String(value)])):{};
        setErrors(fieldErrors);setError(Object.keys(fieldErrors).length?"Vérifiez les champs indiqués.":resetError(result));
        if(Object.keys(fieldErrors).length)requestAnimationFrame(()=>document.getElementById(prefix+Object.keys(fieldErrors)[0])?.focus());
        return;
      }
      if(confirming){setPasswords(EMPTY_PASSWORDS);setVisible({});clearCredentials();endLocalSession();navigate("/login",{replace:true,state:{passwordChanged:true}});}
      else setPhase("sent");
    } finally {if(pending.current===controller){pending.current=null;saving.current=false;if(mounted.current)setBusy(false);}}
  }
  const title=phase==="sent"?"Consultez votre messagerie":phase==="invalid"?"Lien expiré ou invalide":confirming?"Nouveau mot de passe":"Mot de passe oublié ?";
  return <main className="login-screen password-reset-screen" aria-busy={phase==="loading"||busy}>
    <div className="login-theme"><ThemePicker/></div>
    <section className="login-card password-reset-card" aria-labelledby={prefix+"title"}>
      <Link className="password-reset-back" to="/login" onClick={event=>requestLeave(event,"/login")} aria-disabled={busy} tabIndex={busy?-1:undefined}><AppIcon name="arrow-left" size="1em"/>Retour à la connexion</Link>
      <div className="login-brand"><img src="/sauverndeko-logo.jpg" alt="" width="44" height="44" referrerPolicy="no-referrer"/><div><span className="login-brand-name">SauverNdeko</span></div></div>
      <header className="login-heading"><h1 ref={headingRef} tabIndex={-1} id={prefix+"title"}>{title}</h1>{phase==="ready"?<p>{confirming?"Choisissez un nouveau mot de passe pour votre compte.":"Recevez un lien pour choisir un nouveau mot de passe."}</p>:null}</header>
      {phase==="loading"?<p className="password-reset-state" role="status"><span className="login-spinner" aria-hidden="true"/>{confirming?"Vérification du lien…":"Chargement…"}</p>:null}
      {phase==="unavailable"?<div className="password-reset-state"><p role="alert">{error}</p><ActionButton icon="refresh" onClick={()=>setRevision(value=>value+1)}>Réessayer</ActionButton></div>:null}
      {phase==="invalid"?<div className="password-reset-state"><p>Ce lien n’est plus valide. Demandez un nouveau lien.</p><Link className="login-submit password-reset-primary-link" to="/reset-password" onClick={renewLink}>Demander un nouveau lien<AppIcon name="arrow-right" size="1em"/></Link></div>:null}
      {phase==="sent"?<div className="password-reset-state"><span className="password-reset-success-icon" aria-hidden="true"><AppIcon name="mail" size="1em"/></span><p role="status">Si un compte actif correspond à cette adresse, vous recevrez un lien de réinitialisation.</p><button type="button" className="password-reset-text-button" onClick={()=>{setPhase("ready");setError("");setErrors({});}}>Utiliser une autre adresse</button></div>:null}
      {phase==="ready"?<form className="login-form" onSubmit={submit} noValidate aria-busy={busy}>
        {error?<div ref={errorRef} className="login-error" role="alert" tabIndex={-1}><AppIcon name="alert" size="1em"/><span>{error}</span></div>:null}
        {confirming?[{name:"newPassword",label:"Nouveau mot de passe"},{name:"confirmPassword",label:"Confirmer le mot de passe"}].map(({name,label},index)=>{
          const id=prefix+name,hint=index===0?"De "+policy.minLength+" à "+policy.maxLength+" caractères.":"";
          return <div className="login-field" key={name}><label htmlFor={id}>{label}</label><div className="login-input-wrap login-password-wrap"><AppIcon name="lock" size="1em"/><input ref={index===0?passwordRef:null} id={id} name={name} type={visible[name]?"text":"password"} value={passwords[name]} onChange={event=>changePassword(name,event.target.value)} disabled={busy} autoComplete="new-password" autoCapitalize="none" spellCheck={false} maxLength={policy.maxLength*2} required aria-invalid={Boolean(errors[name])} aria-describedby={errors[name]?id+"-error":hint?id+"-hint":undefined}/><button type="button" className="login-password-toggle" disabled={busy} onClick={()=>setVisible(current=>({...current,[name]:!current[name]}))} aria-label={(visible[name]?"Masquer":"Afficher")+" · "+label} aria-pressed={Boolean(visible[name])} aria-controls={id}><AppIcon name={visible[name]?"eye-off":"eye"} size="1em"/></button></div>{errors[name]?<p className="login-field-error" id={id+"-error"}>{errors[name]}</p>:hint?<p className="password-reset-hint" id={id+"-hint"}>{hint}</p>:null}</div>;
        }):<div className="login-field"><label htmlFor={prefix+"email"}>Adresse e-mail</label><div className="login-input-wrap"><AppIcon name="mail" size="1em"/><input ref={emailRef} id={prefix+"email"} name="email" type="email" inputMode="email" autoComplete="email" autoCapitalize="none" spellCheck={false} maxLength={254} placeholder="vous@organisation.cd" value={email} onChange={event=>{setEmail(event.target.value);setErrors({});setError("");}} disabled={busy} required aria-invalid={Boolean(errors.email)} aria-describedby={errors.email?prefix+"email-error":undefined}/></div>{errors.email?<p className="login-field-error" id={prefix+"email-error"}>{errors.email}</p>:null}</div>}
        <button type="submit" className="login-submit" disabled={busy}>{busy?<span className="login-spinner" aria-hidden="true"/>:null}<span>{busy?(confirming?"Enregistrement…":"Envoi…"):(confirming?"Enregistrer le mot de passe":"Envoyer le lien")}</span>{!busy?<AppIcon name="arrow-right" size="1em"/>:null}</button>
      </form>:null}
    </section>
    <aside className="login-identity" aria-label="SauverNdeko"><div><img src="/sauverndeko-logo.jpg" alt="" width="76" height="76" referrerPolicy="no-referrer"/><h2>SauverNdeko</h2><p className="login-project-lead">Votre espace, en toute simplicité.</p><p className="login-project-summary">Retrouvez vos applications et les informations de votre organisation.</p></div></aside>
    {leaveTarget?<DrawerDialog title="Quitter cette page ?" onClose={()=>setLeaveTarget(null)} defaultWidth={460} storageKey="sauverndeko.password-reset.discard.width" footer={<div className="password-reset-discard-actions"><ActionButton onClick={()=>setLeaveTarget(null)}>Continuer</ActionButton><ActionButton variant="primary" onClick={leave}>Quitter</ActionButton></div>}><p className="password-reset-discard-copy">Votre nouveau mot de passe n’a pas été enregistré.</p></DrawerDialog>:null}
  </main>;
}
