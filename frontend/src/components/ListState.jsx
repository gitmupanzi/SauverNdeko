import AppIcon from "./AppIcon";
import "./ListState.css";

/** Une explication et une action réelle, sans inférer de résultat métier. */
export default function ListState({title="Aucun résultat",description,icon="search",action,loading=false,className="",role}) {
  return <div className={"ui-list-state"+(loading?" is-loading":"")+" "+className} role={role}>
    <span className="ui-list-state-icon" aria-hidden="true"><AppIcon name={loading?"refresh":icon}/></span>
    <div className="ui-list-state-copy"><strong>{title}</strong>{description?<div className="ui-list-state-description">{description}</div>:null}</div>
    {action?<div className="ui-list-state-action">{action}</div>:null}
  </div>;
}
