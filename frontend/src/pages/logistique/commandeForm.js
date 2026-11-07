const TEXT_LIMITS = {RefCmd:255,NomClientSaisi:255,geolocalisationCmd:255,UrlBL:255,ObsCmd:255,CodeFacture:255,StatusFacture:243,UrlFacture:255};
const REFERENCES = ["ID_DepotFk","ID_TypeCmdFk","ID_StatutCmdFk","ID_TiersFk","ID_DestinationFk","ID_ConditionPaiementFk","ID_ModePaiementFk","ID_DeviseFk"];
const DATES = ["DateCmd","DateFacture","DateEcheancePaiement"];
const FLAGS = ["SelectCmd","ValideRemiseFacture"];
export const COMMANDE_EDITABLE_FIELDS = [...REFERENCES,...Object.keys(TEXT_LIMITS),...DATES,...FLAGS];
const zone = "Africa/Kinshasa";

/** Les dates SQL sans fuseau conservent l’heure métier ; seuls les instants zonés sont convertis. */
export function commandeDateInput(value) {
  if(value==null||value==="")return "";
  const raw=String(value).trim();
  if(!/(?:Z|[+-]\d{2}:?\d{2})$/i.test(raw)) {
    const match=raw.match(/^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2})(?::(\d{2}))?/);
    return match?match[1]+"T"+match[2]+":"+(match[3]||"00"):raw;
  }
  const date=new Date(raw);
  if(!Number.isFinite(date.getTime()))return raw;
  const parts=Object.fromEntries(new Intl.DateTimeFormat("en-CA",{timeZone:zone,year:"numeric",month:"2-digit",day:"2-digit",hour:"2-digit",minute:"2-digit",second:"2-digit",hourCycle:"h23"}).formatToParts(date).map(part=>[part.type,part.value]));
  return `${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}:${parts.second}`;
}
export function validCommandeDate(value) {
  const match=String(value).match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?$/);
  if(!match)return false;
  const [year,month,day,hour,minute,second]=match.slice(1).map(Number);
  const date=new Date(0);date.setUTCFullYear(year,month-1,day);date.setUTCHours(hour,minute,second||0,0);
  return year>=1&&date.getUTCFullYear()===year&&date.getUTCMonth()===month-1&&date.getUTCDate()===day&&date.getUTCHours()===hour&&date.getUTCMinutes()===minute&&date.getUTCSeconds()===(second||0);
}
export function commandeForm(record,defaultCurrencyId="",now=new Date()) {
  const values={};
  for(const key of [...REFERENCES,...Object.keys(TEXT_LIMITS)])values[key]=record?.[key]==null?"":String(record[key]);
  for(const key of DATES)values[key]=commandeDateInput(record?.[key]);
  for(const key of FLAGS)values[key]=record?.[key]==null?"":record[key]?"true":"false";
  if(!record){values.ID_DeviseFk=String(defaultCurrencyId||"");values.DateCmd=commandeDateInput(now.toISOString());}
  return values;
}
export function commandeErrors(values,record=null) {
  const errors={};
  if(!values.ID_TypeCmdFk)errors.ID_TypeCmdFk="Choisissez le type de bon.";
  if(!values.ID_DeviseFk)errors.ID_DeviseFk="Choisissez une devise.";
  for(const key of REFERENCES)if(values[key]&&!/^[1-9]\d*$/.test(values[key]))errors[key]="Choisissez une valeur de la liste.";
  for(const [key,max] of Object.entries(TEXT_LIMITS))if(Array.from(values[key]||"").length>max)errors[key]=`Limitez ce champ à ${max} caractères.`;
  if(!record&&!values.DateCmd)errors.DateCmd="Renseignez la date du bon.";
  for(const key of DATES)if(values[key]&&!validCommandeDate(values[key]))errors[key]="Renseignez une date et une heure valides.";
  for(const key of FLAGS)if(!["","true","false"].includes(values[key]))errors[key]="Choisissez une valeur de la liste.";
  for(const key of ["UrlBL","UrlFacture"]) {
    const value=String(values[key]||"").trim();
    if(value&&value!==String(record?.[key]||"").trim()&&/^(?:javascript|data|vbscript):/i.test(value))errors[key]="Utilisez un lien vers un document.";
  }
  return errors;
}
export function commandePayload(values,record,version,userId,meta={}) {
  const previous=record?commandeForm(record):null,payload={};
  for(const key of COMMANDE_EDITABLE_FIELDS) {
    if(record&&values[key]===previous[key])continue;
    if(record&&((key==="ID_TypeCmdFk"&&meta.canChangeType===false)||(key==="ID_DeviseFk"&&meta.canChangeCurrency===false)||(key==="CodeFacture"&&meta.canChangeInvoiceCode===false)))continue;
    const raw=values[key];
    payload[key]=FLAGS.includes(key)?raw===""?null:raw==="true":String(raw??"").trim()||null;
  }
  if(record)payload._version=version;
  else payload.ID_UserFk=userId;
  return payload;
}
