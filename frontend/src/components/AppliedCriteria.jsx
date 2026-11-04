import AppIcon from "./AppIcon";
import "./AppliedCriteria.css";

/** Affiche uniquement les critères appliqués ; le parent conserve son brouillon. */
export default function AppliedCriteria({items=[],onRemove,disabled=false,label="Critères appliqués"}) {
  const visible=items.filter(item=>item&&item.value!==""&&item.value!=null);
  function remove(event,key){
    // Le bouton disparaît après la suppression : garder un repère stable au clavier.
    if(event?.detail===0 && event.currentTarget?.ownerDocument?.activeElement===event.currentTarget){
      event.currentTarget.closest(".erp-register")?.querySelector('.erp-table-search input[type="search"]')?.focus({preventScroll:true});
    }
    onRemove?.(key);
  }
  if(!visible.length)return null;
  return <div className="applied-criteria" role="group" aria-label={label}>
    {visible.map(item=><button key={item.key} type="button" className="applied-criterion" disabled={disabled} onClick={event=>remove(event,item.key)} aria-label={"Retirer le filtre "+item.label+" : "+item.value}>
      <span>{item.label} : <strong>{item.value}</strong></span><AppIcon name="close" size={13}/>
    </button>)}
  </div>;
}
