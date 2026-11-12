const STATUS_CODES={new:"info",active:"progress",pending:"warning",resolved:"success",closed:"neutral"};
const PRIORITY_CODES={low:"neutral",normal:"info",high:"warning",critical:"danger"};
const STATUS_LABELS={nouveau:"new",nouvelle:"new","en cours":"active","en attente":"pending",resolu:"resolved",resolue:"resolved",cloture:"closed",cloturee:"closed",clos:"closed",close:"closed"};
const PRIORITY_LABELS={basse:"low",faible:"low",normale:"normal",normal:"normal",haute:"high",elevee:"high",critique:"critical"};

function normalize(value){
  return String(value??"").trim().toLowerCase().normalize("NFD").replace(/\p{M}/gu,"").replace(/\s+/g," ");
}

function lookup(values,key){
  return Object.hasOwn(values,key)?values[key]:undefined;
}

function referenceTone(options,id,value,prefix,codes,labels){
  const option=id==null?null:options?.find(item=>String(item.id)===String(id));
  for(const candidate of [option?.abbr,value]){
    const key=normalize(candidate);
    const tone=key.startsWith(prefix)?lookup(codes,key.slice(prefix.length)):lookup(codes,lookup(labels,key));
    if(tone)return tone;
  }
  return "neutral";
}

export function SupportBadge({value,tone="neutral"}){
  return <span className={"erp-status support-badge is-"+tone}>{value||"Non renseigné"}</span>;
}

export function SupportPriority({value,id,options}){
  return <SupportBadge value={value} tone={referenceTone(options,id,value,"support.priority.",PRIORITY_CODES,PRIORITY_LABELS)}/>;
}

export function SupportStatus({value,code,id,options}){
  const tone=code?lookup(STATUS_CODES,normalize(code))||"neutral"
    :referenceTone(options,id,value,"support.status.",STATUS_CODES,STATUS_LABELS);
  return <SupportBadge value={value} tone={tone}/>;
}
