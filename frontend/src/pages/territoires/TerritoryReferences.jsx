import {useEffect,useState} from "react";
import {Link} from "react-router-dom";
import {useAuth} from "../../contexts/AuthContext";
import {mayOpen} from "../../services/moduleAccess";
import {requestJson} from "../../services/api";
import {referenceLabel} from "../../utils/referenceOptions";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import AppIcon from "../../components/AppIcon";
import {TERRITORY_ROOT,TERRITORY_REGISTERS,territoryFields} from "./territorialDefinitions";
import {territoryTypeReference} from "./territorialForm";

export default function TerritoryReferences({kind,onClose,openInNewTab=false}){
 const {user}=useAuth(),[data,setData]=useState(null),[error,setError]=useState(""),[loading,setLoading]=useState(true),[retry,setRetry]=useState(0);
 useEffect(()=>{const controller=new AbortController();setLoading(true);setError("");requestJson(TERRITORY_ROOT+"/references/"+kind,{requiresAuth:true,signal:controller.signal}).then(response=>{if(controller.signal.aborted)return;setLoading(false);if(response?.success)setData(response.data);else setError(response?.message||"Les références n’ont pas pu être chargées.");});return()=>controller.abort();},[kind,retry]);
 const fields=territoryFields(kind).filter(field=>field.type==="select"),typeReference=territoryTypeReference(kind,data),navigation=openInNewTab?{target:"_blank",rel:"noopener noreferrer"}:{};
 return <RecordEditorFrame title="Réglages des références" subtitle={TERRITORY_REGISTERS[kind].title} icon="settings" onClose={onClose} defaultWidth={800} storageKey="sauverndeko.territoires.references.width" readOnly loading={loading} error={error} onReload={()=>setRetry(value=>value+1)}>
  {data?<><section className="record-editor-section"><p className="record-editor-note">Références partagées de l’organisation territoriale.{openInNewTab?" Le paramétrage s’ouvre dans un nouvel onglet pour conserver votre saisie.":""}</p>{mayOpen(user,"/referentiels")?<Link {...navigation} className="ui-action is-secondary" to="/referentiels?onglet=champs" onClick={onClose}><AppIcon name="tag"/>Référencement des champs{openInNewTab?" (nouvel onglet)":""}<AppIcon name="arrow-up-right"/></Link>:null}</section>
  {typeReference?.message?<section className="record-editor-section territory-reference-notice" role="status"><p className="record-editor-note">{typeReference.message}</p>{mayOpen(user,"/referentiels")?<Link {...navigation} className="ui-action is-secondary" to="/referentiels?onglet=valeurs" onClick={onClose}><AppIcon name="tag"/>Valeurs de référence{openInNewTab?" (nouvel onglet)":""}<AppIcon name="arrow-up-right"/></Link>:null}</section>:null}
  {fields.map(field=>{const reference=data.fieldReferences?.[field.name],options=data.options?.[field.optionsSource]||[],ids=reference?.categoryIds||[],labels=reference?.categoryLabels||[];return <section className="record-editor-section territory-reference" key={field.name}><div><span className="erp-product-avatar"><AppIcon name={reference?"tag":"globe"}/></span><div><h3>{field.label}</h3>{reference?<p>{ids.length?ids.map((id,index)=>String(id)+" · "+(Array.isArray(labels)?labels[index]:labels[id]||"")).join(" ; "):"Catégorie non renseignée"}</p>:<p>Rattachement à la hiérarchie territoriale</p>}</div><span className="erp-status is-neutral">{options.length} valeurs</span></div>{reference?.defaultCategoryId!=null?<small className="record-editor-note">Catégorie par défaut : {reference.defaultCategoryId}</small>:null}<details><summary>Voir les valeurs</summary><ul>{options.map(option=><li key={option.id??option.value}>{referenceLabel(option)}</li>)}</ul>{!options.length?<p className="record-editor-note">Aucune valeur disponible.</p>:null}</details></section>;})}
  {!fields.length?<section className="record-editor-section"><p>Aucune liste catégorielle sur ce niveau.</p></section>:null}
  </>:null}
 </RecordEditorFrame>;
}
