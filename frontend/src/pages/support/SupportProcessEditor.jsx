import {useId,useState} from "react";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import SearchSelect from "../../components/SearchSelect";
import {PROCESS_URL,processOptions,useProcessMutation} from "./supportProcess";

const ASSIGNEES=[
  {key:"serviceId",source:"services",label:"Service"},
  {key:"roleId",source:"roles",label:"Rôle"},
  {key:"responsibleId",source:"users",label:"Responsable"},
];
const VALIDATORS=[
  {key:"userId",source:"users",label:"Utilisateur"},
  {key:"roleId",source:"roles",label:"Rôle"},
  {key:"serviceId",source:"services",label:"Service"},
];
const STAGE_RULES=[
  ["requiresReceipt","Faire confirmer la réception"],
  ["allowReturn","Autoriser le retour à une étape précédente"],
  ["requiresDocument","Exiger un justificatif à la transmission"],
];
const REASONS=[
  {key:"blockerReasonIds",label:"Blocage"},
  {key:"returnReasonIds",label:"Retour"},
  {key:"rejectReasonIds",label:"Refus"},
];
const MAX_MINUTES=525600;
const invalidMinutes=value=>value!==""&&value!=null&&(!Number.isInteger(Number(value))||Number(value)<1||Number(value)>MAX_MINUTES);
const newStage=()=>({name:"",clientKey:crypto.randomUUID(),validators:[],...Object.fromEntries(REASONS.map(({key})=>[key,[]]))});
export const initialProcessModel=model=>model?{
  ...model,name:model.name??"",active:model.active??true,stages:(model.stages||[]).map(stage=>({...newStage(),...stage,name:stage.name??""})),
}:{name:"",description:"",typeId:"",globalMinutes:"",reminderMinutes:"",active:true,stages:[newStage()]};

function Field({label,wide,children}){
  const id=useId();
  return <div className={"support-field"+(wide?" is-wide":"")}><label htmlFor={id}>{label}</label>{children(id)}</div>;
}

function Choice({label,rows,value,onChange,disabled,readOnly=false,emptyLabel}){
  const current=String(value??"");
  const options=processOptions(rows,current,emptyLabel);
  if(current&&options.at(-1)?.incompatible&&options.at(-1).value===current){
    options[options.length-1]={...options.at(-1),label:readOnly?"Référence nº "+current:"Valeur à vérifier : "+current};
  }
  return <Field label={label}>{id=><SearchSelect id={id} label={label} options={options} value={current} onChange={onChange} disabled={disabled}/>}</Field>;
}

function DurationField({label,value,onChange,disabled}){
  return <Field label={label}>{id=><input id={id} type="number" min="1" max={MAX_MINUTES} step="1" inputMode="numeric" value={value??""} onChange={event=>onChange(event.target.value)} disabled={disabled}/>}</Field>;
}

export function processModelPayload(values,requestId){
  const {name,description,typeId,globalMinutes,reminderMinutes,active,revision,stages}=values;
  const numberOrNull=value=>value===""||value==null?null:Number(value);
  return {
    name:name.trim(),description:(description||"").trim(),typeId:numberOrNull(typeId),
    globalMinutes:numberOrNull(globalMinutes),reminderMinutes:numberOrNull(reminderMinutes),active,
    ...(revision!=null?{revision}:{}),requestId,
    stages:stages.map(stage=>({
      name:stage.name.trim(),
      ...Object.fromEntries(ASSIGNEES.map(({key})=>[key,numberOrNull(stage[key])])),
      minutes:numberOrNull(stage.minutes),requiresReceipt:Boolean(stage.requiresReceipt),
      allowReturn:Boolean(stage.allowReturn),requiresDocument:Boolean(stage.requiresDocument),
      requiredInformation:(stage.requiredInformation||"").trim(),
      validators:stage.validators.map(({target,...validator})=>Object.fromEntries(
        VALIDATORS.filter(({key})=>validator[key]).map(({key})=>[key,numberOrNull(validator[key])])
      )),
      ...Object.fromEntries(REASONS.map(({key})=>[key,(stage[key]||[]).map(Number)])),
    })),
  };
}

export function validateProcessModel(values,references){
  if(!values.name.trim())return "Saisissez le nom du modèle.";
  if(!values.typeId)return "Choisissez le type de dossier.";
  if(typeof values.active!=="boolean")return "Vérifiez l’état actif ou inactif du modèle.";
  if(invalidMinutes(values.globalMinutes)||invalidMinutes(values.reminderMinutes))
    return "Les délais et intervalles doivent être compris entre 1 et 525 600 minutes.";
  if(!values.stages.length)return "Ajoutez au moins une étape.";
  const unnamed=values.stages.findIndex(stage=>!stage.name.trim());
  if(unnamed!==-1)return "Saisissez le nom de l’étape "+(unnamed+1)+".";
  const invalidDeadline=values.stages.findIndex(stage=>invalidMinutes(stage.minutes));
  if(invalidDeadline!==-1)return "Le délai de l’étape "+(invalidDeadline+1)+" doit être compris entre 1 et 525 600 minutes.";
  const invalidRule=values.stages.findIndex(stage=>STAGE_RULES.some(([key])=>stage[key]!=null&&typeof stage[key]!=="boolean"));
  if(invalidRule!==-1)return "Vérifiez les options de transmission de l’étape "+(invalidRule+1)+".";
  const incomplete=values.stages.findIndex(stage=>stage.validators.some(validator=>!VALIDATORS.some(({key})=>validator[key])));
  if(incomplete!==-1)return "Choisissez une personne, un rôle ou un service pour chaque validation de l’étape "+(incomplete+1)+".";
  if(references){
    const allowed=Object.fromEntries(Object.entries(references).map(([key,rows])=>[key,
      new Set(processOptions(rows).filter(option=>!option.disabled).map(option=>option.value)),
    ]));
    const invalid=(source,value)=>Boolean(value)&&!allowed[source]?.has(String(value));
    if(invalid("types",values.typeId))return "Choisissez un type de dossier disponible.";
    const index=values.stages.findIndex(stage=>ASSIGNEES.some(({key,source})=>invalid(source,stage[key]))
      ||stage.validators.some(validator=>VALIDATORS.some(({key,source})=>invalid(source,validator[key])))
      ||REASONS.some(({key})=>stage[key].some(id=>invalid("reasons",id))));
    if(index!==-1)return "Vérifiez les références de l’étape "+(index+1)+".";
  }
  return "";
}

export default function SupportProcessEditor({model,draft,references,canManage,onClose,onSaved,readOnly=false}){
  const [initial]=useState(()=>initialProcessModel(model??draft));
  const [values,setValues]=useState(initial);
  const [error,setError]=useState("");
  const mutation=useProcessMutation();
  const editable=canManage&&!readOnly;
  const dirty=Boolean(draft)||values!==initial||mutation.uncertain;

  function submit(){
    if(!editable||mutation.busy)return;
    if(!mutation.uncertain){
      const issue=validateProcessModel(values);
      if(issue){setError(issue);return;}
    }
    const path=model?PROCESS_URL+"/"+model.id:PROCESS_URL;
    mutation.save(path,model?"PUT":"POST",processModelPayload(values,crypto.randomUUID()),onSaved);
  }

  return <RecordEditorFrame title={model?editable?"Modifier le modèle":"Consulter le modèle":"Nouveau modèle de suivi"}
    subtitle={model?"Version "+model.version:"Suivi des dossiers"} icon="folder" className="support-editor support-process-editor"
    storageKey="sauverndeko.support.process-editor.width" defaultWidth={1000} onClose={onClose} onSubmit={submit}
    readOnly={!editable} busy={mutation.busy} dirty={dirty} canSubmit={dirty}
    error={error||mutation.error} submitLabel={mutation.uncertain?"Vérifier l’enregistrement":model?"Enregistrer le modèle":"Créer le modèle"}>
    <SupportProcessModelFields model={model} values={values} references={references} editable={editable}
      disabled={!editable||mutation.busy||mutation.uncertain} onChange={next=>{
        mutation.clearError();
        setError("");
        setValues(next);
      }}/>
  </RecordEditorFrame>;
}

export function SupportProcessModelFields({model,values,references,editable,disabled,onChange}){
  const types=references.types??[];
  const typeOptions=model?.type&&!types.some(type=>String(type.id??type.value)===String(model.typeId))
    ?[...types,{id:model.typeId,label:model.type}]:types;
  function change(key,value){onChange({...values,[key]:value});}
  function changeStage(index,patch){
    change("stages",values.stages.map((stage,position)=>position===index?{...stage,...patch}:stage));
  }
  function moveStage(index,direction){
    const stages=[...values.stages];
    [stages[index],stages[index+direction]]=[stages[index+direction],stages[index]];
    change("stages",stages);
  }
  return <>
    <section className="record-editor-section">
      <h3><AppIcon name="folder"/>Modèle</h3>
      <div className="record-editor-grid">
        <Field label="Nom du modèle *">{id=><input id={id} value={values.name} maxLength={120} aria-required="true" disabled={disabled} onChange={event=>change("name",event.target.value)}/>}</Field>
        <Choice label="Type de dossier *" rows={typeOptions} value={values.typeId} emptyLabel="Choisir…" onChange={value=>change("typeId",value)} disabled={disabled||Boolean(model)} readOnly={!editable}/>
        <Field label="Description" wide>{id=><textarea id={id} value={values.description??""} maxLength={4000} rows={2} disabled={disabled} onChange={event=>change("description",event.target.value)}/>}</Field>
        <DurationField label="Délai global en minutes" value={values.globalMinutes} onChange={value=>change("globalMinutes",value)} disabled={disabled}/>
        <DurationField label="Intervalle de relance en minutes" value={values.reminderMinutes} onChange={value=>change("reminderMinutes",value)} disabled={disabled}/>
        <label className="support-process-check is-wide"><input type="checkbox" checked={Boolean(values.active)} disabled={disabled} onChange={event=>change("active",event.target.checked)}/>Modèle actif</label>
      </div>
      <p className="record-editor-note">Les délais sont calendaires. Un champ vide laisse le délai ou la relance désactivés.</p>
      {model&&editable?<p className="record-editor-note">Les dossiers engagés conservent la version utilisée à leur démarrage.</p>:null}
    </section>
    {values.stages.map((stage,index)=><ProcessStageEditor key={stage.clientKey} stage={stage} index={index} count={values.stages.length}
      disabled={disabled} showEditing={editable} references={references} onChange={patch=>changeStage(index,patch)}
      onMove={direction=>moveStage(index,direction)}
      onRemove={()=>change("stages",values.stages.filter((_,position)=>position!==index))}/>)}
    {editable?<div className="support-process-actions"><ActionButton icon="plus" disabled={disabled||values.stages.length>=30} onClick={()=>change("stages",[...values.stages,newStage()])}>Ajouter une étape</ActionButton></div>:null}
  </>;
}

function ProcessStageEditor({stage,index,count,references,disabled,showEditing,onChange,onMove,onRemove}){
  function changeValidator(index,validator){
    onChange({validators:stage.validators.map((item,position)=>position===index?validator:item)});
  }

  return <section className="record-editor-section">
    <header className="support-process-stage-heading">
      <h3>Étape {index+1}{stage.name.trim()?" · "+stage.name.trim():""}</h3>
      {showEditing?<div className="support-process-actions">
        <ActionButton aria-label={"Monter l’étape "+(index+1)} disabled={disabled||index===0} onClick={()=>onMove(-1)}>Monter</ActionButton>
        <ActionButton aria-label={"Descendre l’étape "+(index+1)} disabled={disabled||index===count-1} onClick={()=>onMove(1)}>Descendre</ActionButton>
        <ActionButton icon="trash" variant="danger" aria-label={"Retirer l’étape "+(index+1)} disabled={disabled||count===1} onClick={onRemove}>Retirer</ActionButton>
      </div>:null}
    </header>
    <div className="record-editor-grid">
      <Field label="Nom de l’étape *">{id=><input id={id} value={stage.name} maxLength={120} aria-required="true" disabled={disabled} onChange={event=>onChange({name:event.target.value})}/>}</Field>
      <DurationField label="Délai de l’étape en minutes" value={stage.minutes} onChange={minutes=>onChange({minutes})} disabled={disabled}/>
      {ASSIGNEES.map(({key,source,label})=><Choice key={key} label={label} rows={references[source]} value={stage[key]} onChange={value=>onChange({[key]:value})} disabled={disabled} readOnly={!showEditing}/>)}
      <Field label="Information à renseigner avant transmission" wide>{id=><textarea id={id} value={stage.requiredInformation??""} maxLength={1000} rows={2} disabled={disabled} onChange={event=>onChange({requiredInformation:event.target.value})}/>}</Field>
      {STAGE_RULES.map(([key,label])=><label className="support-process-check" key={key}><input type="checkbox" checked={Boolean(stage[key])} disabled={disabled} onChange={event=>onChange({[key]:event.target.checked})}/>{label}</label>)}
    </div>
    <div className="support-process-subsection"><h4>Motifs prédéfinis</h4>
      <div className="record-editor-grid">{REASONS.map(({key,label})=><ProcessReasons key={key} label={label} rows={references.reasons} selected={stage[key]}
        disabled={disabled} editable={showEditing} onChange={ids=>onChange({[key]:ids})}/>)}</div>
    </div>
    <div className="support-process-subsection">
      <h4>Validations de l’étape</h4>
      {stage.validators.map((validator,position)=><ValidatorEditor key={position} validator={validator} index={position}
        disabled={disabled} showEditing={showEditing} references={references}
        onChange={value=>changeValidator(position,value)} onRemove={()=>onChange({validators:stage.validators.filter((_,index)=>index!==position)})}/>)}
      {!stage.validators.length?<p className="support-empty">Aucune validation exigée.</p>:null}
      {showEditing?<ActionButton icon="plus" disabled={disabled||stage.validators.length>=10} onClick={()=>onChange({validators:[...stage.validators,{target:"userId"}]})}>Ajouter une validation</ActionButton>:null}
    </div>
  </section>;
}

function ProcessReasons({label,rows=[],selected=[],disabled,editable,onChange}){
  const remaining=rows.filter(row=>!selected.some(id=>String(id)===String(row.id??row.value??row.ID_Generique)));
  return <div className="support-process-reasons">
    {editable?<Choice label={label} rows={remaining} value="" emptyLabel="Ajouter un motif"
      onChange={id=>{if(id)onChange([...selected,id]);}} disabled={disabled||selected.length>=50}/>:<strong>{label}</strong>}
    <div className="support-process-actions">{selected.map(id=>{
      const option=processOptions(rows,id).find(option=>option.value===String(id));
      const caption=option?.incompatible?(editable?"Valeur à vérifier : ":"Référence nº ")+id:option?.label;
      return editable?<ActionButton key={id} icon="close" aria-label={"Retirer le motif "+caption} disabled={disabled} onClick={()=>onChange(selected.filter(item=>item!==id))}>{caption}</ActionButton>:
        <span key={id} className="erp-status is-neutral">{caption}</span>;
    })}</div>
    {!editable&&!selected.length?<small className="record-editor-note">Aucun motif prédéfini.</small>:null}
  </div>;
}

function ValidatorEditor({validator,index,references,disabled,showEditing,onChange,onRemove}){
  const target=validator.target||VALIDATORS.find(({key})=>validator[key])?.key||"userId";
  const field=VALIDATORS.find(({key})=>key===target);
  return <div className="support-process-validator">
    <Field label={"Validation "+(index+1)}>{id=><SearchSelect id={id} label={"Cible de la validation "+(index+1)} options={VALIDATORS.map(({key,label})=>({value:key,label}))} value={target} onChange={value=>onChange({target:value})} disabled={disabled}/>}</Field>
    <Choice label={field.label} rows={references[field.source]} value={validator[target]} onChange={value=>onChange({target,[target]:value})} disabled={disabled} readOnly={!showEditing}/>
    {showEditing?<ActionButton icon="trash" variant="danger" aria-label={"Retirer la validation "+(index+1)} disabled={disabled} onClick={onRemove}>Retirer</ActionButton>:null}
  </div>;
}
