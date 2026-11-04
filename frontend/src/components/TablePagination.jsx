import AppIcon from "./AppIcon";
import ActionButton from "./ActionButton";
import "./TablePagination.css";
function pageNumbers(page,total){
  const values=total<=7 ? Array.from({length:total},(_,i)=>i+1) : [...new Set([1,...[page-1,page,page+1].filter(value=>value>1 && value<total),total])].sort((a,b)=>a-b);
  return values.flatMap((value,index)=>index && value>values[index-1]+1 ? ["gap-"+value,value] : [value]);
}
export default function TablePagination({total,take,page,onPage,loading=false}){
  const count=Math.max(0,Number(total)||0),size=Math.max(1,Number(take)||25);
  const pages=Math.max(1,Math.ceil(count/size));
  const current=Math.max(1,Math.min(Number(page)||1,pages));
  const first=count?(current-1)*size+1:0,last=Math.min(count,current*size);
  return <footer className="table-pagination">
    <div className="table-pagination-summary" role="status">{loading ? "Actualisation…" : count ? <><strong>{first}–{last}</strong> sur {count.toLocaleString("fr-FR")} résultat{count>1?"s":""}</> : "Aucun résultat"}</div>
    {pages>1?<nav className="table-pagination-nav" aria-label="Pagination du tableau">
      <ActionButton icon="chevron-left" aria-label="Précédent" title={current===1?"Première page":"Page précédente"} disabled={loading || current===1} onClick={()=>onPage(current-1)}><span className="table-pagination-step-label">Précédent</span></ActionButton>
      <div className="table-pagination-pages">{pageNumbers(current,pages).map(value=>typeof value==="string"?<span key={value} className="table-pagination-gap" aria-hidden="true">…</span>:value===current?<span key={value} className="table-pagination-number is-current" aria-current="page" title={"Page "+value}>{value}</span>:<button key={value} type="button" className="table-pagination-number" aria-label={"Aller à la page "+value} disabled={loading} onClick={()=>onPage(value)}>{value}</button>)}</div>
      <span className="table-pagination-mobile" aria-label={"Page "+current+" sur "+pages}>{current} / {pages}</span>
      <ActionButton aria-label="Suivant" title={current===pages?"Dernière page":"Page suivante"} disabled={loading || current===pages} onClick={()=>onPage(current+1)}><span className="table-pagination-step-label">Suivant</span><AppIcon name="chevron-right" /></ActionButton>
    </nav>:<span className="table-pagination-complete">{count?"Tous les résultats sont affichés":""}</span>}
  </footer>;
}
