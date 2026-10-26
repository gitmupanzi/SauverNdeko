import { Component, Suspense, lazy } from "react";
import AppIcon from "./AppIcon";
import "./LazyView.css";

export function ScreenPlaceholder({label="Chargement…", compact=false}) {
  return <section className={"erp-screen-placeholder"+(compact?" is-compact":"")} role="status" aria-live="polite" aria-busy="true"><span className="erp-screen-placeholder-label">{label}</span><div aria-hidden="true"><span/><span/><span/></div></section>;
}
class ViewBoundary extends Component {
  state={error:null};
  static getDerivedStateFromError(error){return {error};}
  render(){
    if(this.state.error)return <section className="erp-screen-failure" role="alert"><AppIcon name="alert"/><div><strong>Cette vue n’a pas pu s’ouvrir.</strong><p>Vérifiez votre connexion, puis rechargez la page.</p><button type="button" onClick={()=>window.location.reload()}><AppIcon name="reset"/>Recharger la page</button></div></section>;
    return this.props.children;
  }
}

// Les vues se téléchargent à la demande ; une erreur de module propose une reprise explicite.
// Un rechargement est nécessaire quand le navigateur a mémorisé un import réseau rejeté.
export default function lazyView(loader,{label="Chargement…",compact=false}={}) {
  let pending;
  const load=()=>pending || (pending=loader().catch(error=>{pending=null;throw error;}));
  const View=lazy(load);
  function DeferredView(props){
    return <ViewBoundary><Suspense fallback={<ScreenPlaceholder label={label} compact={compact}/>}><View {...props}/></Suspense></ViewBoundary>;
  }
  return DeferredView;
}
