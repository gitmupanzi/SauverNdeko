import {SupportBadge} from "./SupportBadge";
import {useEffect,useId,useRef,useState} from "react";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import ListState from "../../components/ListState";
import SearchSelect from "../../components/SearchSelect";
import {SimpleTable,formatDate} from "../logistique/logistiqueShared";
import {PROCESS_ACTIONS,PROCESS_EVENTS,processOptions,useProcessMutation,useProcessQuery} from "./supportProcess";
import {SUPPORT_ROOT} from "./supportForm";

const date=value=>value?formatDate(value):"—";
const documentLabel=row=>row.NomOriginal||row.NomFichier||"Justificatif";
const ALERT_STATUS={pending:{label:"En attente",tone:"neutral"},sent:{label:"Envoyée",tone:"success"},failed:{label:"Échec",tone:"warning"}};

function duration(step){
  if(step.durationMinutes!=null)return new Intl.NumberFormat("fr-FR",{style:"unit",unit:"minute",unitDisplay:"short"}).format(step.durationMinutes);
  if(!step.enteredAt||!step.exitedAt)return "—";
  const minutes=Math.floor((Date.parse(step.exitedAt)-Date.parse(step.enteredAt))/60000);
  return Number.isFinite(minutes)&&minutes>=0?minutes+" min":"—";
}

function blockageLabel(value){
  return typeof value==="string"?value:value?.reasonLabel||value?.label||value?.reason||"";
}

export default function SupportJourney({record,documents,active,refresh,disabled,onChanged,onDraftChange,onBusyChange,onShowDocuments}){
  const url=SUPPORT_ROOT+"/tickets/"+record.ID_Support+"/parcours";
  const query=useProcessQuery(active?url:null,refresh);
  const [selection,setSelection]=useState(null);
  const [feedback,setFeedback]=useState("");
  const run=query.data?.run;

  function select(action){
    setFeedback("");
    setSelection({action,revision:run?.revision});
    onDraftChange(true);
  }

  function cancel(){
    setSelection(null);
    onDraftChange(false);
  }

  function saved(data){
    const isStart=selection?.action.key==="start";
    const firstStep=data?.run?.current?.name;
    cancel();
    setFeedback(isStart?`Parcours démarré.${firstStep?` Première étape « ${firstStep} ».`:""}`:"Le parcours a été mis à jour.");
    query.reload();
    onChanged();
  }

  return <section className="record-editor-section" aria-busy={query.loading}>
    <h3><AppIcon name="movements"/>Parcours du dossier</h3>
    {query.error?<div className="admin-error" role="alert"><span>{query.error}</span><ActionButton icon="refresh" disabled={Boolean(selection)} onClick={query.reload}>Réessayer</ActionButton></div>:null}
    {query.loading?<ListState role="status" loading title="Chargement du parcours…"/>:null}
    {query.data?.available===false?<p className="support-empty">Le suivi par étapes sera disponible après la mise à jour du module.</p>:null}
    {feedback?<p className="support-process-feedback" role="status"><AppIcon name="check-circle"/>{feedback}</p>:null}
    {query.data?.available!==false&&query.data&&!run&&!selection?<UnlinkedJourney record={record} data={query.data}
      disabled={disabled} onStart={()=>select({key:"start"})}/>:null}
    {run?<><JourneySummary run={run}/>
      {!selection&&run.actions?.length?<div className="support-process-actions">{run.actions.map(item=>{
        const action=typeof item==="string"?{key:item}:item;
        const config=PROCESS_ACTIONS[action.key];
        if(!config)return null;
        const label=action.key==="advance"&&run.current?.isLast?"Terminer le parcours":config.label;
        return <ActionButton key={action.key} icon={config.icon} disabled={disabled} onClick={()=>select(action)}>{label}</ActionButton>;
      })}</div>:null}
    </>:null}
    {selection&&(run||selection.action.key==="start")?<JourneyAction selection={selection} run={run} models={query.data?.models||[]}
      documents={documents} disabled={disabled} url={url} onCancel={cancel} onSaved={saved}
      onBusyChange={onBusyChange} onShowDocuments={onShowDocuments}/>:null}
    {run?<><JourneyStages run={run}/><JourneyHistory run={run} documents={documents} onShowDocuments={onShowDocuments}/>
      {run.alerts?.length?<JourneyAlerts rows={run.alerts}/>:null}</>:null}
  </section>;
}

function UnlinkedJourney({record,data,disabled,onStart}){
  const hasModel=data.canStart&&data.models?.length>0;
  let description="Le démarrage du parcours nécessite les droits de gestion du suivi dans l’entreprise du ticket.";
  if(record.Archive){
    description="Un parcours ne peut être démarré que sur un ticket actif.";
  }else if(["resolved","closed"].includes(record.StatutCode)){
    description="Le ticket doit être rouvert avant de pouvoir y associer un modèle de suivi.";
  }else if(hasModel){
    description="Choisissez un modèle pour démarrer la première étape sur ce ticket.";
  }else if(data.canStart){
    description=record.TypeSupport
      ?`Aucun modèle actif pour le type « ${record.TypeSupport} ». Vous pouvez en activer un dans Modèles de suivi.`
      :"Aucun modèle actif pour ce type de ticket. Vous pouvez en activer un dans Modèles de suivi.";
  }
  return <ListState icon="movements" title="Aucun parcours associé" description={description}
    action={hasModel?<ActionButton icon="plus" variant="primary" disabled={disabled} onClick={onStart}>Associer un modèle de suivi</ActionButton>:null}/>;
}

function JourneySummary({run}){
  const step=run.current;
  const blockage=blockageLabel(step?.blockage);
  const [status,tone]=run.completedAt?["Terminé","success"]:step?.blockage?["Bloqué","danger"]
    :step?.requiresReceipt&&!step.receivedAt?["En attente de réception","warning"]:["En cours","progress"];
  return <div className="support-process-summary">
    <header><strong>{run.modelName}</strong><small>Version {run.version}</small><SupportBadge value={status} tone={tone}/>
      {step?.late?<span className="erp-status is-warning">Étape en retard</span>:null}
      {run.globalLate?<span className="erp-status is-warning">Délai global dépassé</span>:null}</header>
    <dl className="support-info-grid">
      {[["Étape actuelle",step?.name||"—"],["Service",step?.service||"—"],["Responsable",step?.responsible||"À affecter"],
        ["Entrée dans l’étape",date(step?.enteredAt)],["Échéance de l’étape",date(step?.dueAt)],["Échéance du dossier",date(run.globalDueAt)],
        ...(run.completedAt?[["Terminé le",date(run.completedAt)]]:[])].map(([label,value])=><div key={label}><dt>{label}</dt><dd>{value}</dd></div>)}
    </dl>
    {step?.blockage?<p className="support-content"><strong>Blocage</strong> {blockage||"Motif non renseigné"}</p>:null}
    {step?.validationRequired>0?<p className="support-content">Validations obtenues · {step.validationCount??0} sur {step.validationRequired}</p>:null}
  </div>;
}

function JourneyStages({run}){
  const columns=[
    {key:"name",label:"Étape",sortable:false,render:row=><span aria-current={row.id===run.current?.id?"step":undefined}>{row.position}. {row.name}</span>},
    {key:"service",label:"Service",sortable:false},
    {key:"responsible",label:"Responsable",sortable:false},
    {key:"enteredAt",label:"Entrée",sortable:false,render:row=>date(row.enteredAt)},
    {key:"transmittedAt",label:"Transmission",sortable:false,render:row=>date(row.transmittedAt)},
    {key:"receivedAt",label:"Réception",sortable:false,render:row=>date(row.receivedAt)},
    {key:"exitedAt",label:"Fin de l’étape",sortable:false,render:row=>date(row.exitedAt)},
    {key:"durationMinutes",label:"Durée écoulée",sortable:false,render:duration},
  ];
  return <div className="support-process-subsection">
    <h4>Étapes du parcours</h4>
    <SimpleTable rows={run.steps||[]} columns={columns} getRowId={row=>row.id} showSearch={false} showControls={false}
      defaultVisibleColumns={columns.map(column=>column.key)} defaultPinnedColumns={[]} emptyMessage="Aucune étape enregistrée."/>
  </div>;
}

function JourneyHistory({run,documents,onShowDocuments}){
  const history=run.history||[];
  const available=new Map(documents.map(row=>[String(row.ID_PieceFk),row]));
  return <div className="support-process-subsection">
    <h4>Historique du parcours</h4>
    {history.length?<ol className="support-history">{history.map((event,index)=>{
      const document=available.get(String(event.documentId));
      return <li key={event.id||index}>
        <span className="support-history-dot"><AppIcon name="clock" size={15}/></span>
        <div>
          <header><strong>{run.completedAt&&event.action==="advance"&&index===history.length-1?PROCESS_EVENTS.complete:PROCESS_EVENTS[event.action]||"Événement du parcours"}</strong><time dateTime={event.occurredAt}>{date(event.occurredAt)}</time></header>
          <small>{[event.actor,event.position?("Étape "+event.position):null].filter(Boolean).join(" · ")||"Auteur non renseigné"}</small>
          {event.reasonLabel||event.reason?<p className="support-content">{[event.reasonLabel,event.reason].filter(Boolean).join(" · ")}</p>:null}
          {event.information?<p className="support-content">{event.information}</p>:null}
          {document?<ActionButton icon="document" onClick={onShowDocuments}>{documentLabel(document)}</ActionButton>:null}
        </div>
      </li>;
    })}</ol>:<p className="support-empty">Aucun événement disponible.</p>}
  </div>;
}

function JourneyAlerts({rows}){
  const columns=[
    {key:"type",label:"Échéance",sortable:false,render:row=>row.type==="stage"?"Étape "+row.position:"Dossier"},
    {key:"occurrence",label:"Notification",sortable:false,render:row=>row.occurrence?"Relance "+row.occurrence:"Première alerte"},
    {key:"createdAt",label:"Date de création",sortable:false,render:row=>date(row.createdAt)},
    {key:"processedAt",label:"Date de traitement",sortable:false,render:row=>date(row.processedAt)},
    {key:"status",label:"État",sortable:false,render:row=>{
      const status=ALERT_STATUS[row.status]||{label:"Indéterminé",tone:"neutral"};
      return <span className={"erp-status is-"+status.tone}>{status.label}</span>;
    }},
    {key:"error",label:"Motif de l’échec",sortable:false},
  ];
  return <div className="support-process-subsection">
    <h4>Alertes de délai</h4>
    <SimpleTable rows={rows} columns={columns} getRowId={row=>row.id} showSearch={false} showControls={false}
      defaultVisibleColumns={columns.map(column=>column.key)} defaultPinnedColumns={[]}/>
  </div>;
}

function JourneyAction({selection,run,models,documents,disabled,url,onCancel,onSaved,onBusyChange,onShowDocuments}){
  const id=useId();
  const heading=useRef(null);
  const {action,revision}=selection;
  const config=PROCESS_ACTIONS[action.key];
  const isStart=action.key==="start";
  const [fields,setFields]=useState(()=>({modelId:isStart&&models.length===1?String(models[0].id):"",reason:"",reasonId:"",targetPosition:"",information:"",responsibleId:"",documentId:""}));
  const [error,setError]=useState("");
  const mutation=useProcessMutation();
  const step=run?.current;
  const needsReason=action.requiresReason||["return","reject","block"].includes(action.key);
  const needsInformation=action.key==="advance"&&Boolean(step?.requiredInformation);
  const needsDocument=action.key==="advance"&&step?.requiresDocument===true;
  const disabledFields=disabled||mutation.busy||mutation.uncertain;
  const reasonField={block:"blockerReasons",return:"returnReasons",reject:"rejectReasons"}[action.key];
  const reasons=step?.[reasonField]||[];
  const documentOptions=documents.filter(row=>row.ID_PieceFk).map(row=>({id:row.ID_PieceFk,label:documentLabel(row)}));
  useEffect(()=>{heading.current?.focus();},[]);

  function change(key,value){
    mutation.clearError();
    setError("");
    setFields(previous=>({...previous,[key]:value}));
  }

  async function submit(){
    if(!mutation.uncertain){
      if(isStart&&!fields.modelId){setError("Choisissez un modèle de suivi.");return;}
      if(action.key==="return"&&!fields.targetPosition){setError("Choisissez l’étape de retour.");return;}
      if(action.key==="assign"&&!fields.responsibleId){setError("Choisissez le nouveau responsable.");return;}
      if(reasons.length&&!fields.reasonId){setError("Choisissez un motif.");return;}
      if(needsReason&&!fields.reason.trim()){setError("Précisez le motif.");return;}
      if(needsInformation&&!fields.information.trim()){setError("Renseignez l’information demandée.");return;}
      if(needsDocument&&!fields.documentId){setError("Choisissez un justificatif dans les documents du dossier.");return;}
    }
    const values={action:action.key,requestId:crypto.randomUUID(),...(isStart?{}:{revision})};
    for(const key of ["modelId","reasonId","targetPosition","responsibleId","documentId"]){
      if(fields[key])values[key]=Number(fields[key]);
    }
    for(const key of ["reason","information"]){
      if(fields[key].trim())values[key]=fields[key].trim();
    }
    onBusyChange(true);
    try{await mutation.save(url,"POST",values,onSaved);}finally{onBusyChange(false);}
  }

  function choice(key,label,rows){
    return <div className="support-field"><label htmlFor={id+"-"+key}>{label}</label><SearchSelect id={id+"-"+key} label={label}
      value={fields[key]} options={processOptions(rows,fields[key],"Choisir…")} onChange={value=>change(key,value)} disabled={disabledFields}/></div>;
  }

  return <div className="support-process-action-form" aria-busy={mutation.busy} aria-label={config.label}>
    <h4 tabIndex={-1} ref={heading}>{action.key==="advance"&&step?.isLast?"Terminer le parcours":config.label}</h4>
    <div className="record-editor-grid">
      {isStart?choice("modelId","Modèle de suivi *",models):null}
      {action.key==="return"?choice("targetPosition","Étape de retour *",(run.returnTargets||[]).map(stage=>({id:stage.position,label:stage.name}))):null}
      {action.key==="assign"?choice("responsibleId","Nouveau responsable *",run.users||[]):null}
      {reasons.length?choice("reasonId","Motif *",reasons):null}
      {needsDocument?choice("documentId","Justificatif *",documentOptions):null}
      {needsDocument&&!documentOptions.length?<div className="support-field"><span>Ajoutez un justificatif avant de transmettre.</span><ActionButton icon="document" onClick={()=>{onCancel();onShowDocuments();}}>Ouvrir les documents</ActionButton></div>:null}
      {needsInformation?<label className="support-field is-wide"><span>Information requise · {step.requiredInformation}</span><textarea value={fields.information} rows={2} maxLength={4000}
        onChange={event=>change("information",event.target.value)} disabled={disabledFields}/></label>:null}
      {needsReason?<label className="support-field is-wide"><span>{reasons.length?"Justification *":"Motif *"}</span><textarea value={fields.reason} rows={2} maxLength={2000}
        onChange={event=>change("reason",event.target.value)} disabled={disabledFields}/></label>:null}
    </div>
    {error||mutation.error?<p className="record-field-error" role="alert">{error||mutation.error}</p>:null}
    <div className="support-process-actions">
      <ActionButton onClick={onCancel} disabled={mutation.busy||mutation.uncertain}>Annuler</ActionButton>
      <ActionButton icon={config.icon} variant="primary" onClick={submit} disabled={disabled||mutation.busy}>{mutation.busy?"Enregistrement…":mutation.uncertain?"Vérifier l’enregistrement":isStart?"Démarrer le parcours":"Confirmer"}</ActionButton>
    </div>
  </div>;
}
