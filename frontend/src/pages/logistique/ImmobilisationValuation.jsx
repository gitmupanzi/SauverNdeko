import {useState} from "react";
import ActionButton from "../../components/ActionButton";
import {compareDecimal,currencyOptions} from "../../utils/money";
import {commandeDateInput} from "./commandeForm";
import {SimpleTable,formatCurrency,formatDate,formatNumber} from "./logistiqueShared";
import {AssetActionEditor,AssetSectionStatus,assetOptions,useAssetSection,validAssetDate} from "./ImmobilisationAction";

const USAGE={COMPTABLE:"Comptable",FISCAL:"Fiscal"};
const FRAMEWORKS={SYSCOHADA:"SYSCOHADA révisé",IFRS:"IFRS",FISCAL:"Règles fiscales"};
const frameworksFor=usage=>assetOptions(FRAMEWORKS).filter(option=>usage==="COMPTABLE"?option.value!=="FISCAL":usage==="FISCAL"?option.value==="FISCAL":false);
const METHODS={LINEAIRE_JOURS:"Linéaire au prorata des jours",NON_AMORTISSABLE:"Sans amortissement"};
const TYPES={DOTATION:"Dotation",AMELIORATION:"Amélioration",DEPRECIATION:"Perte de valeur",CESSION:"Cession",REBUT:"Mise au rebut"};
const DATE_OPTIONS={withTime:false};
const DAY=({date})=><>{formatDate(date,DATE_OPTIONS)}</>;
const isMoney=value=>/^\d{1,16}(?:[.,]\d{1,2})?$/.test(value.trim());
const normalizedMoney=value=>value.trim().replace(",",".");
const moneyLabel={AMELIORATION:"Coût de l’amélioration *",DEPRECIATION:"Montant de la perte de valeur *",CESSION:"Prix de cession *"};
const isDisposal=type=>type==="CESSION"||type==="REBUT";
const amountRequired=type=>Object.hasOwn(moneyLabel,type);
const scheduleColumns=currency=>[
 {key:"DateDebut",label:"Début",width:135,render:row=><DAY date={row.DateDebut}/>},
 {key:"DateFin",label:"Fin",width:135,render:row=><DAY date={row.DateFin}/>},
 {key:"Montant",label:"Dotation prévue",width:175,align:"right",render:row=>formatCurrency(row.Montant,currency)},
];
const eventColumns=currency=>[
 {key:"DateEffet",label:"Date d’effet",width:125,render:row=><DAY date={row.DateEffet}/>},
 {key:"TypeEvenement",label:"Événement",width:145,render:row=>TYPES[row.TypeEvenement]||row.TypeEvenement||"—"},
 {key:"Montant",label:"Montant",width:140,align:"right",render:row=>formatCurrency(row.Montant,currency)},
 {key:"ValeurAvantSortie",label:"VNC avant sortie",width:145,align:"right",render:row=>formatCurrency(row.ValeurAvantSortie,currency)},
 {key:"Motif",label:"Motif",width:215,render:row=><span className="immobilisation-history-text">{row.Motif||"—"}</span>},
 {key:"CreeLe",label:"Enregistré le",width:150,render:row=>formatDate(row.CreeLe)},
 {key:"Auteur",label:"Auteur",width:145,render:row=>row.Auteur??row.CreeParUserFk??"—"},
];
const periodColumns=[
 {key:"UsagePlan",label:"Suivi",width:135,render:row=>USAGE[row.UsagePlan]||row.UsagePlan||"—"},
 {key:"JusquAu",label:"Clôturé jusqu’au",width:135,render:row=><DAY date={row.JusquAu}/>},
 {key:"Motif",label:"Motif",width:240,render:row=><span className="immobilisation-history-text">{row.Motif||"—"}</span>},
 {key:"CreeLe",label:"Enregistré le",width:150,render:row=>formatDate(row.CreeLe)},
 {key:"Auteur",label:"Auteur",width:145,render:row=>row.Auteur??row.CreeParUserFk??"—"},
];

function validatePlan(values,record){
 const errors={};
 if(!values.usage)errors.usage="Choisissez le type de suivi.";
 if(!frameworksFor(values.usage).some(option=>option.value===values.referentiel))errors.referentiel="Choisissez le référentiel validé pour ce type de suivi.";
 if(!values.methode)errors.methode="Choisissez la méthode validée.";
 if(!values.deviseId)errors.deviseId="Choisissez la devise du plan.";
 if(!isMoney(values.cout))errors.cout="Renseignez un montant positif ou nul, à deux décimales maximum.";
 if(!isMoney(values.residuel)||compareDecimal(values.residuel,values.cout)>0)errors.residuel="Renseignez un montant de zéro à la valeur d’acquisition.";
 if(!validAssetDate(values.debut)||values.debut<"1900-01-01"||values.debut>"9899-12-31")errors.debut="Renseignez une date valide.";
 else if(record.DateAcquisition&&values.debut<record.DateAcquisition)errors.debut="Le début du plan ne peut pas précéder l’acquisition.";
 if(values.methode==="LINEAIRE_JOURS"&&(!/^[1-9]\d{0,3}$/.test(values.duree.trim())||Number(values.duree)>1200))errors.duree="Renseignez une durée de 1 à 1 200 mois.";
 if(!values.motif.trim())errors.motif="Renseignez la référence de validation comptable.";
 return errors;
}
function validatePosting(values,disposalDate){
 const errors={};
 if(!values.type)errors.type="Choisissez le type d’événement.";
 if(!validAssetDate(values.date))errors.date="Renseignez une date valide.";
 else if(isDisposal(values.type)&&values.date!==disposalDate)errors.date="Indiquez la date de sortie physique du bien.";
 if(amountRequired(values.type)&&(!isMoney(values.montant)||(values.type!=="CESSION"&&compareDecimal(values.montant,"0")<=0)))errors.montant="Renseignez un montant valide à deux décimales maximum.";
 if(!values.motif.trim())errors.motif="Renseignez le motif.";
 return errors;
}
function validateClosing(values){
 const errors={};
 if(!values.usage)errors.usage="Choisissez le type de suivi.";
 if(!validAssetDate(values.date))errors.date="Renseignez une date valide.";
 if(!values.motif.trim())errors.motif="Renseignez le motif de clôture.";
 return errors;
}

function AssetPlan({plan,currency,canPost,onPost}){
 const planTitle="Suivi "+(USAGE[plan.UsagePlan]||plan.UsagePlan).toLowerCase();
 const projected=plan.schedule||[];
 const events=plan.events||[];
 return <article className="immobilisation-panel">
  <div className="immobilisation-panel-heading">
   <div><h3>{planTitle}</h3><p className="record-editor-note">{FRAMEWORKS[plan.Referentiel]||plan.Referentiel} · {METHODS[plan.Methode]||plan.Methode}</p></div>
   <div className="immobilisation-panel-actions">
    {plan.DateSortie?<span className="erp-status is-neutral">Sortie comptabilisée</span>:null}
    {canPost&&!plan.DateSortie?<ActionButton icon="plus" onClick={onPost}>Enregistrer un événement</ActionButton>:null}
   </div>
  </div>
  <dl className="immobilisation-metrics">
   <div><dt>Valeur brute</dt><dd>{formatCurrency(plan.CoutBrut,currency)}</dd></div>
   <div><dt>Amortissements cumulés</dt><dd>{formatCurrency(plan.AmortissementsCumules,currency)}</dd></div>
   <div><dt>Pertes de valeur cumulées</dt><dd>{formatCurrency(plan.PertesCumulees,currency)}</dd></div>
   <div><dt>Valeur nette comptable</dt><dd>{formatCurrency(plan.ValeurNetteComptable,currency)}</dd></div>
  </dl>
  <dl className="immobilisation-plan-details">
   <div><dt>Coût d’acquisition</dt><dd>{formatCurrency(plan.CoutAcquisition,currency)}</dd></div>
   <div><dt>Valeur résiduelle</dt><dd>{formatCurrency(plan.ValeurResiduelle,currency)}</dd></div>
   <div><dt>Début du plan</dt><dd><DAY date={plan.DateDebut}/></dd></div>
   {plan.DureeMois?<div><dt>Durée</dt><dd>{formatNumber(plan.DureeMois)} mois</dd></div>:null}
   {plan.DerniereDateAmortie?<div><dt>Dernière date amortie</dt><dd><DAY date={plan.DerniereDateAmortie}/></dd></div>:null}
   {plan.ClotureJusquAu?<div><dt>Période clôturée jusqu’au</dt><dd><DAY date={plan.ClotureJusquAu}/></dd></div>:null}
   {plan.DateSortie?<div><dt>Sortie comptable</dt><dd><DAY date={plan.DateSortie}/></dd></div>:null}
   {plan.ValideLe?<div><dt>Plan validé le</dt><dd>{formatDate(plan.ValideLe)}</dd></div>:null}
   {plan.Justification?<div className="immobilisation-plan-justification"><dt>Référence de validation</dt><dd>{plan.Justification}</dd></div>:null}
  </dl>
  <details className="immobilisation-details">
   <summary>Échéancier prévisionnel <span>{projected.length}</span></summary>
   <SimpleTable columns={scheduleColumns(currency)} rows={projected} getRowId={row=>row.DateDebut+"-"+row.DateFin} showSearch={false} showControls={false} defaultPinnedColumns={[]} emptyMessage="Aucune dotation prévue."/>
  </details>
  <details className="immobilisation-details">
   <summary>Événements comptables <span>{events.length}</span></summary>
   <SimpleTable columns={eventColumns(currency)} rows={events} getRowId={row=>row.ID_EvenementValeur} showSearch={false} showControls={false} defaultPinnedColumns={[]} emptyMessage="Aucun événement comptable enregistré."/>
  </details>
 </article>;
}

export default function ImmobilisationValuation({record,writable,references,onChanged}){
 const section=useAssetSection(record.ID_Immobilisation,"valorisation"),[editor,setEditor]=useState(null),[feedback,setFeedback]=useState("");
 const plans=section.data?.plans||[],periods=section.data?.periods||[];
 const unusedUsages=assetOptions(USAGE).filter(option=>!plans.some(plan=>plan.UsagePlan===option.value));
 const currencies=currencyOptions(references);
 const defaultCurrencyId=currencies.find(currency=>currency.value===String(record.ID_DeviseFk)&&!currency.disabled)?.value||"";
 const plan=editor?.plan;
 const disposal=plan?.TypeSortiePhysique||record.TypeSortie;
 const disposalDate=plan?.DateSortiePhysique||record.DateSortie;
 const currencyFor=plan=>plan.DeviseCode||currencies.find(currency=>currency.value===String(plan.ID_DeviseFk))?.code||plan.Devise||(String(plan.ID_DeviseFk)===String(record.ID_DeviseFk)?record.DeviseCode:undefined);
 const today=commandeDateInput(new Date().toISOString()).slice(0,10);
 function saved(){
  setFeedback(({create:"Plan de valorisation enregistré.",post:"Événement comptable enregistré.",close:"Période clôturée."})[editor.kind]);
  setEditor(null);
  section.reload();
  onChanged?.();
 }
 const modalProps={recordId:record.ID_Immobilisation,section:"valorisation",subtitle:record.NomImmobilisation,onSaved:saved,onClose:()=>setEditor(null),onStale:()=>{setEditor(null);section.reload();onChanged?.();}};
 return <div className="immobilisation-section-stack">
  <section className="immobilisation-panel">
   <div className="immobilisation-panel-heading">
    <div><h3>Plans de valorisation</h3><p className="record-editor-note">Chaque plan suit ses propres règles. Faites valider ses paramètres par votre comptable avant de l’enregistrer.</p></div>
    <div className="immobilisation-panel-actions">
     {writable&&section.meta.canCreate===true&&!record.DateSortie&&unusedUsages.length?<ActionButton icon="plus" onClick={()=>setEditor({kind:"create"})}>Nouveau plan</ActionButton>:null}
     {writable&&section.meta.canClose===true?<ActionButton icon="lock" onClick={()=>setEditor({kind:"close"})}>Clôturer une période</ActionButton>:null}
    </div>
   </div>
   {feedback?<p className="immobilisation-feedback" role="status">{feedback}</p>:null}
   <AssetSectionStatus section={section}/>
   {section.data&&!plans.length?<p className="record-editor-note">Aucun plan de valorisation pour ce bien.</p>:null}
  </section>
  {plans.map(plan=><AssetPlan key={plan.ID_Plan} plan={plan} currency={currencyFor(plan)} canPost={writable&&section.meta.canPost===true} onPost={()=>setEditor({kind:"post",plan})}/>)}
  {periods.length?<section className="immobilisation-panel"><h3>Clôtures de l’entreprise</h3><SimpleTable columns={periodColumns} rows={periods} getRowId={row=>row.ID_ClotureValeur} showSearch={false} showControls={false} defaultPinnedColumns={[]}/></section>:null}
  {editor?.kind==="create"?<AssetActionEditor key="create" {...modalProps} title="Nouveau plan de valorisation" icon="chart"
   fields={[
    {key:"usage",label:"Type de suivi *",options:unusedUsages,reset:["referentiel"]},
    {key:"referentiel",label:"Référentiel *",options:values=>frameworksFor(values.usage),help:"Choisissez d’abord le type de suivi."},
    {key:"methode",label:"Méthode *",options:assetOptions(METHODS)},
    {key:"deviseId",label:"Devise *",options:currencies},
    {key:"cout",label:"Coût d’acquisition *",kind:"decimal",maxLength:19,help:record.ValeurAcquisition!=null&&record.DeviseCode?"Valeur de la fiche "+formatCurrency(record.ValeurAcquisition,record.DeviseCode)+". Saisissez le montant validé dans la devise choisie.":"Saisissez le montant validé dans la devise choisie."},
    {key:"residuel",label:"Valeur résiduelle *",kind:"decimal",maxLength:19},
    {key:"debut",label:"Date de début *",kind:"date"},
    {key:"duree",label:"Durée en mois *",kind:"integer",maxLength:4,when:values=>values.methode==="LINEAIRE_JOURS"},
    {key:"motif",label:"Référence de validation comptable *",kind:"textarea",wide:true,help:"Indiquez la validation du référentiel, de la méthode, de la durée et de la date retenus."},
   ]}
   initial={{usage:unusedUsages.length===1?unusedUsages[0].value:"",referentiel:"",methode:"",deviseId:defaultCurrencyId,cout:"",residuel:"",debut:"",duree:"",motif:""}}
   validate={values=>validatePlan(values,record)} payload={values=>({action:"CREER",usage:values.usage,referentiel:values.referentiel,methode:values.methode,cout:normalizedMoney(values.cout),residuel:normalizedMoney(values.residuel),debut:values.debut,duree:values.methode==="LINEAIRE_JOURS"?Number(values.duree):null,deviseId:values.deviseId,motif:values.motif.trim(),_version:record._version})}
   submitLabel="Enregistrer le plan"/>:null}
  {editor?.kind==="post"?<AssetActionEditor key={"post-"+plan.ID_Plan} {...modalProps} title="Événement comptable" subtitle={"Suivi "+(USAGE[plan.UsagePlan]||plan.UsagePlan).toLowerCase()+" · "+record.NomImmobilisation} icon="chart"
   fields={[
    {key:"type",label:"Type d’événement *",options:assetOptions(TYPES).filter(option=>isDisposal(option.value)?option.value===disposal:option.value!=="DOTATION"||plan.Methode!=="NON_AMORTISSABLE")},
    {key:"date",label:"Date d’effet *",kind:"date",help:disposalDate?"Date de sortie physique "+formatDate(disposalDate,DATE_OPTIONS)+".":"Pour une dotation, indiquez la date jusqu’à laquelle amortir."},
    {key:"montant",label:values=>moneyLabel[values.type],kind:"decimal",maxLength:19,when:values=>amountRequired(values.type),help:currencyFor(plan)?"Devise du plan "+currencyFor(plan)+".":undefined},
    {key:"motif",label:"Motif *",kind:"textarea",wide:true},
   ]}
   initial={{type:"",date:disposalDate||today,montant:"",motif:""}}
   validate={values=>validatePosting(values,disposalDate)} payload={values=>({action:"EVENEMENT",planId:plan.ID_Plan,type:values.type,date:values.date,...(amountRequired(values.type)?{montant:normalizedMoney(values.montant)}:{}),motif:values.motif.trim(),_version:plan._version})}
   confirmation="Je confirme l’enregistrement de cet événement dans l’historique du plan." submitLabel="Enregistrer l’événement"/>:null}
  {editor?.kind==="close"?<AssetActionEditor key="close" {...modalProps} title="Clôturer une période" subtitle={record.NomEntite} icon="lock"
   fields={[
    {key:"usage",label:"Type de suivi *",options:assetOptions(USAGE)},
    {key:"date",label:"Clôturer jusqu’au *",kind:"date",help:"La clôture s’applique à tous les plans de ce type dans l’entreprise."},
    {key:"motif",label:"Motif *",kind:"textarea",wide:true},
   ]}
   initial={{usage:"",date:"",motif:""}} validate={validateClosing} payload={values=>({action:"CLOTURER",usage:values.usage,date:values.date,motif:values.motif.trim()})}
   confirmation="Je confirme la clôture pour l’ensemble de l’entreprise et le type de suivi choisi." submitLabel="Confirmer la clôture"/>:null}
 </div>;
}
