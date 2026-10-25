import {useCallback,useEffect,useId,useRef,useState} from "react";
import {useNavigate,useSearchParams} from "react-router-dom";
import {useAuth} from "../contexts/AuthContext";
import PasswordEditor from "../components/PasswordEditor";
import RecordEditorFrame from "../components/RecordEditorFrame";
import SearchSelect from "../components/SearchSelect";
import ActionButton from "../components/ActionButton";
import AppIcon from "../components/AppIcon";
import ConsultationTabs from "../components/ConsultationTabs";
import UserAvatar from "../components/UserAvatar";
import "./Profile.css";

const PROFILE_FIELDS=["NomUser","PrenomUser","EmailUser","PhoneUser","SexeUser"];
const MAX_PHOTO_BYTES=8*1024*1024;
const PROFILE_TABS=[{key:"personal",label:"Informations personnelles",icon:"user"},{key:"organisation",label:"Organisation",icon:"apps"},{key:"security",label:"Sécurité",icon:"lock"}];
function buildProfileForm(user){return Object.fromEntries(PROFILE_FIELDS.map(key=>[key,String(user?.[key] ?? "")]));}
function normalizedProfile(values){return Object.fromEntries(PROFILE_FIELDS.map(key=>[key,key==="PhoneUser"?String(values[key]||"").replace(/\D/g,""):String(values[key]??"").trim()]));}
function profilePayload(values,initial){const next=normalizedProfile(values),before=normalizedProfile(initial);return Object.fromEntries(PROFILE_FIELDS.filter(key=>next[key]!==before[key]).map(key=>[key,next[key]]));}
function photoFileError(file){if(!file)return "";if(!file.size)return "Ce fichier est vide.";if(file.size>MAX_PHOTO_BYTES)return "La photo ne doit pas dépasser 8 Mo.";if(!["image/jpeg","image/png","image/webp"].includes(file.type)&&!(file.type===""&&/\.(jpe?g|png|webp)$/i.test(file.name)))return "Choisissez une image JPEG, PNG ou WebP.";return "";}
function profileRequest(values,initial,file,removePhoto=false){const fields=profilePayload(values,initial);if(!file&&!removePhoto)return fields;const body=new FormData();body.append("payload",JSON.stringify({...fields,...(removePhoto&&!file?{_removePhoto:true}:{})}));if(file)body.append("photo",file,file.name);return body;}
function profileErrors(values,initial){
  const next=normalizedProfile(values),errors={};
  for(const [key,label] of [["PrenomUser","Le prénom"],["NomUser","Le nom"]]){if(!next[key])errors[key]=label+" est obligatoire.";else if(next[key].length>100)errors[key]="Utilisez au maximum 100 caractères.";}
  if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(next.EmailUser))errors.EmailUser="Indiquez une adresse e-mail valide.";
  else if(next.EmailUser.length>150)errors.EmailUser="Utilisez au maximum 150 caractères.";
  if(String(values.PhoneUser||"").trim()&&(!/^[+()\d\s.-]+$/.test(values.PhoneUser)||!next.PhoneUser))errors.PhoneUser="Indiquez un numéro de téléphone valide.";
  else if(next.PhoneUser.length>20)errors.PhoneUser="Le numéro ne peut pas dépasser 20 chiffres.";
  if(values.SexeUser!==initial.SexeUser&&!["M","F"].includes(next.SexeUser))errors.SexeUser="Choisissez une valeur proposée.";
  return errors;
}
function displayName(user){return [user?.PrenomUser,user?.NomUser].filter(Boolean).join(" ").trim()||"Mon profil";}
function roleLabel(user){if(user?.moduleAccess?.platformAdmin)return "Administrateur de la plateforme";if(user?.Is_Admin)return "Administrateur";return user?.role?.name || (user?.Is_staff?"Gestionnaire":"Utilisateur");}
function sexLabel(value){return ({M:"Masculin",F:"Féminin"})[value] || value || "—";}
function InfoField({label,value,wide=false}){return <div className={"account-profile-field"+(wide?" is-wide":"")}><dt>{label}</dt><dd>{value==null||value===""?"—":value}</dd></div>;}
function ProfileEditor({user,section,canWrite,updateProfile,onClose,onSaved}){
  const prefix=useId(),initial=useRef(buildProfileForm(user)),mounted=useRef(true),saving=useRef(false),fileInput=useRef(null),previewUrl=useRef("");
  const [values,setValues]=useState(()=>initial.current),[busy,setBusy]=useState(false),[errors,setErrors]=useState({}),[error,setError]=useState("");
  const [photoFile,setPhotoFile]=useState(null),[removePhoto,setRemovePhoto]=useState(false),[photoError,setPhotoError]=useState(""),[preview,setPreview]=useState("");
  const dirty=Object.keys(profilePayload(values,initial.current)).length>0||Boolean(photoFile||removePhoto);
  useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;if(previewUrl.current)URL.revokeObjectURL(previewUrl.current);};},[]);
  useEffect(()=>{const frame=requestAnimationFrame(()=>document.getElementById(prefix+(section==="photo"?"Photo":"PrenomUser"))?.focus({preventScroll:true}));return()=>cancelAnimationFrame(frame);},[prefix,section]);
  useEffect(()=>{if(!dirty&&!busy)return;const preventLeave=event=>{event.preventDefault();event.returnValue="";};window.addEventListener("beforeunload",preventLeave);return()=>window.removeEventListener("beforeunload",preventLeave);},[dirty,busy]);
  function change(key,value){if(saving.current||!canWrite)return;setValues(current=>({...current,[key]:value}));setErrors(current=>({...current,[key]:""}));setError("");}
  function replacePreview(file){const previous=previewUrl.current,next=file?URL.createObjectURL(file):"";previewUrl.current=next;setPreview(next);if(previous)URL.revokeObjectURL(previous);}
  function choosePhoto(event){const file=event.target.files?.[0];event.target.value="";if(!file||saving.current||!canWrite)return;const message=photoFileError(file);setPhotoError(message);if(message)return;setPhotoFile(file);setRemovePhoto(false);replacePreview(file);setError("");}
  function resetPhoto(remove=false){if(saving.current||!canWrite)return;setPhotoFile(null);setRemovePhoto(remove&&Boolean(user.UrlPhoto));setPhotoError("");setError("");replacePreview(null);if(fileInput.current)fileInput.current.value="";}
  function field(name,label,attributes={}){
    const id=prefix+name;
    return <div className="account-profile-editor-field"><label htmlFor={id}>{label}</label><input id={id} name={name} value={values[name]} onChange={event=>change(name,event.target.value)} disabled={busy||!canWrite} aria-invalid={Boolean(errors[name])} aria-describedby={errors[name]?id+"-error":undefined} {...attributes}/>{errors[name]?<small className="account-profile-field-error" id={id+"-error"}>{errors[name]}</small>:null}</div>;
  }
  async function submit(){
    if(saving.current||!canWrite)return;
    if(photoError){setError("Vérifiez la photo sélectionnée.");document.getElementById(prefix+"Photo")?.focus();return;}
    const invalid=profileErrors(values,initial.current);setErrors(invalid);setError("");
    if(Object.keys(invalid).length){setError("Vérifiez les champs indiqués.");requestAnimationFrame(()=>document.getElementById(prefix+Object.keys(invalid)[0])?.focus());return;}
    if(!dirty)return;
    saving.current=true;setBusy(true);
    try{
      const result=await updateProfile(profileRequest(values,initial.current,photoFile,removePhoto));
      if(!mounted.current)return;
      if(!result?.success||!result.data){setError(result?.message||"Le profil n’a pas pu être enregistré. Réessayez.");return;}
      onSaved("Profil mis à jour.");
    }catch{if(mounted.current)setError("L’enregistrement a échoué. Votre saisie est conservée.");}
    finally{saving.current=false;if(mounted.current)setBusy(false);}
  }
  const sexOptions=[{value:"M",label:"Masculin"},{value:"F",label:"Féminin"}];
  if(values.SexeUser&&!sexOptions.some(option=>option.value===values.SexeUser))sexOptions.unshift({value:values.SexeUser,label:"Valeur actuelle · "+values.SexeUser});
  const personal=<section className="account-profile-editor-section"><h3>Informations personnelles</h3><div className="account-profile-editor-grid">
    {field("PrenomUser","Prénom",{required:true,maxLength:100,autoComplete:"given-name"})}
    {field("NomUser","Nom",{required:true,maxLength:100,autoComplete:"family-name"})}
    {field("EmailUser","Adresse e-mail",{type:"email",required:true,maxLength:150,autoComplete:"email",inputMode:"email"})}
    {field("PhoneUser","Téléphone",{type:"tel",maxLength:40,autoComplete:"tel",placeholder:"+243…"})}
    <div className="account-profile-editor-field"><label htmlFor={prefix+"SexeUser"}>Sexe</label><SearchSelect id={prefix+"SexeUser"} label="Sexe" value={values.SexeUser} options={sexOptions} onChange={value=>change("SexeUser",value)} disabled={busy||!canWrite} invalid={Boolean(errors.SexeUser)} describedBy={errors.SexeUser?prefix+"SexeUser-error":undefined}/>{errors.SexeUser?<small className="account-profile-field-error" id={prefix+"SexeUser-error"}>{errors.SexeUser}</small>:null}</div>
  </div></section>;
  const photo=<section className="account-profile-editor-section"><h3>Photo de profil</h3><div className="account-profile-photo-preview"><UserAvatar user={{...user,...values}} className="account-profile-avatar" photo={photoFile?preview:removePhoto?"":undefined} onError={()=>{if(photoFile)setPhotoError("Cette image ne peut pas être affichée. Choisissez un autre fichier.");}}/><div><strong>{photoFile?photoFile.name:removePhoto?"Photo retirée":"Votre photo"}</strong><p>{photoFile?new Intl.NumberFormat("fr-FR").format(Math.ceil(photoFile.size/1024))+" Ko · Aperçu avant enregistrement":removePhoto||!user.UrlPhoto?"Vos initiales sont affichées sans photo.":"Photo actuelle"}</p><div className="account-profile-photo-actions"><ActionButton id={prefix+"Photo"} icon="camera" disabled={busy||!canWrite} aria-describedby={prefix+"Photo-hint"+(photoError?" "+prefix+"Photo-error":"")} aria-invalid={Boolean(photoError)} onClick={()=>fileInput.current?.click()}>Choisir une image</ActionButton><ActionButton icon="trash" disabled={busy||!canWrite||(!photoFile&&(!user.UrlPhoto||removePhoto))} onClick={()=>resetPhoto(true)}>Retirer</ActionButton>{photoFile||removePhoto||photoError?<ActionButton icon="reset" disabled={busy||!canWrite} onClick={()=>resetPhoto(false)}>Rétablir</ActionButton>:null}</div></div></div><input ref={fileInput} type="file" name="photo" accept="image/jpeg,image/png,image/webp" hidden disabled={busy||!canWrite} onChange={choosePhoto}/><p className="account-profile-field-hint" id={prefix+"Photo-hint"}>JPEG, PNG ou WebP · 8 Mo maximum.</p>{photoError?<p className="account-profile-field-error" id={prefix+"Photo-error"} role="alert">{photoError}</p>:null}</section>;
  return <RecordEditorFrame title={section==="photo"?"Modifier la photo":"Modifier le profil"} subtitle={displayName(user)} icon="user" onClose={onClose} onSubmit={submit} busy={busy} dirty={dirty} canSubmit={canWrite&&dirty&&!photoError} error={error} storageKey="sauverndeko.profile-editor.width"><fieldset className="account-profile-editor" disabled={busy||!canWrite}>{!canWrite?<p className="account-profile-field-hint" role="status">Votre profil est actuellement en consultation.</p>:null}{section==="photo"?<>{photo}{personal}</>:<>{personal}{photo}</>}</fieldset></RecordEditorFrame>;
}

export default function Profile(){
  const {user,loading,updateProfile,endLocalSession}=useAuth();
  const navigate=useNavigate();
  const [params,setParams]=useSearchParams(),[editor,setEditor]=useState(null),[feedback,setFeedback]=useState(null),[active,setActive]=useState("personal");
  const requested=params.get("modifier")==="1",consumed=useRef(false),scope=String(user?.IdUser??"")+":"+String(user?.IdEntiteFk??""),previousScope=useRef(scope);
  const canWrite=Boolean(user?.permissions?.canWriteData),entity=user?.entite,country=entity?.localisation?.country?.name || user?.scopeContext?.country?.name;
  const closeEditor=useCallback(()=>setEditor(null),[]);
  const saved=useCallback(message=>{setEditor(null);setFeedback({type:"success",message});},[]);
  useEffect(()=>{if(previousScope.current!==scope){previousScope.current=scope;setEditor(null);setFeedback(null);setActive("personal");}},[scope]);
  useEffect(()=>{
    if(!requested){consumed.current=false;return;}
    if(loading||!user||consumed.current)return;
    consumed.current=true;
    setActive("personal");
    if(canWrite)setEditor({user,section:"personal"});else setFeedback({type:"info",message:"Votre profil est actuellement en consultation."});
    const next=new URLSearchParams(params);next.delete("modifier");setParams(next,{replace:true});
  },[requested,loading,user?.IdUser,canWrite,params,setParams]);
  function passwordChanged(){setEditor(null);endLocalSession();navigate("/login?redirect=%2Fprofil",{replace:true,state:{passwordChanged:true}});}
  function openEditor(section="personal"){if(!canWrite)return;setFeedback(null);setEditor({user,section});}
  if(loading)return <main className="account-profile"><p className="account-profile-state" role="status">Chargement du profil…</p></main>;
  if(!user)return <main className="account-profile"><p className="account-profile-state" role="alert">Le profil est indisponible.</p></main>;
  const status=user.ValideUser===true?"Actif":user.ValideUser===false?"Inactif":"État non renseigné";
  return <main className="account-profile">
    <div className="account-profile-heading"><h1>Mon profil</h1><span>Mon compte</span></div>
    {feedback?<p className={"account-profile-feedback is-"+feedback.type} role="status">{feedback.type==="success"?<AppIcon name="check-circle"/>:<AppIcon name="user"/>}{feedback.message}</p>:null}
    <section className="account-profile-card account-profile-identity" aria-labelledby="account-profile-name">
      <div className="account-profile-identity-main"><div className="account-profile-avatar-wrap"><UserAvatar user={user} className="account-profile-avatar"/><button type="button" className="account-profile-photo-button" aria-label="Modifier la photo de profil" title={canWrite?"Modifier la photo":"Profil en consultation"} disabled={!canWrite} onClick={()=>openEditor("photo")}><AppIcon name="camera" size={17}/></button></div>
        <div className="account-profile-identity-copy"><h2 id="account-profile-name">{displayName(user)}</h2><p>{roleLabel(user)}{entity?.NomEntite?<><span className="account-profile-separator" aria-hidden="true">·</span>{entity.NomEntite}</>:null}</p><div className="account-profile-meta"><span className={"account-profile-status "+(user.ValideUser===true?"is-active":user.ValideUser===false?"is-inactive":"is-unknown")}>{status}</span>{user.IdUser!=null?<span>Compte #{user.IdUser}</span>:null}</div></div>
      </div><ActionButton icon="edit" className="account-profile-edit" disabled={!canWrite} title={!canWrite?"Profil en consultation":undefined} aria-label="Modifier le profil" onClick={()=>openEditor()}>Modifier</ActionButton>
    </section>
    <ConsultationTabs tabs={PROFILE_TABS} value={active} onChange={setActive} label="Rubriques du profil" idPrefix="profile"/>
    {PROFILE_TABS.filter(tab=>tab.key!==active).map(tab=><section key={tab.key} id={"profile-panel-"+tab.key} role="tabpanel" aria-labelledby={"profile-tab-"+tab.key} hidden/>)}
    <section className="account-profile-panel" id={"profile-panel-"+active} role="tabpanel" aria-labelledby={"profile-tab-"+active} tabIndex={0}>
    {active==="personal"?<section className="account-profile-card" aria-labelledby="account-profile-personal-title"><div className="account-profile-card-head"><h2 id="account-profile-personal-title">Informations personnelles</h2><ActionButton icon="edit" className="account-profile-edit" disabled={!canWrite} title={!canWrite?"Profil en consultation":undefined} aria-label="Modifier les informations personnelles" onClick={()=>openEditor()}>Modifier</ActionButton></div><dl className="account-profile-info-grid">
      <InfoField label="Prénom" value={user.PrenomUser}/><InfoField label="Nom" value={user.NomUser}/><InfoField label="Adresse e-mail" value={user.EmailUser}/><InfoField label="Téléphone" value={user.PhoneUser}/><InfoField label="Sexe" value={sexLabel(user.SexeUser)}/>
    </dl></section>:active==="security"?<section className="account-profile-card" aria-labelledby="account-profile-security-title"><div className="account-profile-card-head"><h2 id="account-profile-security-title">Sécurité du compte</h2><AppIcon name="lock"/></div><div className="account-profile-security"><div><h3>Mot de passe</h3><p>Confirmez votre mot de passe actuel pour en choisir un nouveau.</p><p>Vous devrez vous reconnecter après la modification.</p></div><ActionButton icon="lock" disabled={user.ValideUser!==true} onClick={()=>{setFeedback(null);setEditor({user,section:"password"});}}>Modifier le mot de passe</ActionButton></div></section>:
    <section className="account-profile-card" aria-labelledby="account-profile-organisation-title"><div className="account-profile-card-head"><h2 id="account-profile-organisation-title">Organisation</h2><span className="account-profile-readonly">Rattachement</span></div>{entity?<><dl className="account-profile-info-grid"><InfoField label="Nom de l’organisation" value={entity.NomEntite}/><InfoField label="Adresse e-mail" value={entity.EmailEntite}/><InfoField label="Téléphone" value={entity.PhoneEntite}/><InfoField label="Adresse" value={entity.AdresseEntite} wide/>{country?<InfoField label="Pays" value={country}/>:null}</dl><p className="account-profile-card-note">Ces informations sont gérées par votre administrateur.</p></>:<p className="account-profile-empty">Ce compte n’est rattaché à aucune organisation.</p>}</section>}
    </section>
    {editor?.section==="password"?<PasswordEditor key={scope} onClose={closeEditor} onChanged={passwordChanged}/>:editor?<ProfileEditor key={scope} user={editor.user} section={editor.section} canWrite={canWrite} updateProfile={updateProfile} onClose={closeEditor} onSaved={saved}/>:null}
  </main>;
}
