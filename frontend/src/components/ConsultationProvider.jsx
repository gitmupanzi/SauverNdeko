import { createContext, useCallback, useContext, useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import { useFollowupFolders } from "../contexts/FollowupFoldersContext";
import { accessSignature, moduleRights } from "../services/moduleAccess";
import { requestJson } from "../services/api";
import DrawerDialog from "./DrawerDialog";
import lazyView from "./LazyView";
import "./Consultation.css";
const Context=createContext(null);
const ObjectContent=lazyView(()=>import("./ConsultationContent").then(module=>({default:module.ObjectContent})),{label:"Chargement de la fiche…",compact:true});
const IndicatorContent=lazyView(()=>import("./ConsultationContent").then(module=>({default:module.IndicatorContent})),{label:"Chargement de la liste…"});
export const ResultTable=lazyView(()=>import("./ConsultationContent").then(module=>({default:module.ResultTable})),{label:"Chargement de la liste…"});

export function useRead(url,externalVersion=0) {
  const [version, setVersion] = useState(0);
  const source = url ? url.split("?")[0]+"?depotId="+new URLSearchParams(url.split("?")[1]||"").get("depotId") : null;
  const [state, setState] = useState({ source, loading: Boolean(url), payload: null });
  useEffect(() => {
    if (!url) { setState({ source:null, loading: false, payload: null }); return; }
    const controller = new AbortController();
    setState((current) => ({ source, payload:current.source === source ? current.payload : null, loading:true }));
    requestJson(url, { requiresAuth: true, signal: controller.signal }).then((payload) => {
      if (!controller.signal.aborted) setState({ source, loading: false, payload });
    });
    return () => controller.abort();
  }, [url, version, externalVersion]);
  return { ...state, payload:state.source === source ? state.payload : null, retry: () => setVersion((value) => value + 1) };
}
export function IndicatorDetails({ metricKey, criteria, onReady }) {
  const { openProduct, openOrder } = useConsultations();
  const [query, setQuery] = useState(() => ({ ...criteria, populationQ: criteria.q || "", q: "", timeZone:Intl.DateTimeFormat().resolvedOptions().timeZone, take: 50, skip: 0 }));
  const entry = { id: metricKey, query };
  const open = (kind, id, label) => kind === "produit" ? openProduct({ ID_Article: id, NomArticle: label }) : openOrder({ ID_Commande: id, CodeCmd: label });
  return <IndicatorContent entry={entry} update={(patch) => setQuery(patch.query)} open={open} inline onReady={onReady} />;
}

function Dialog({ children, title, onClose, onBack }) {
  return <DrawerDialog id="consultation-dialog" titleId="consult-title" title={title} onClose={onClose} onBack={onBack} className="consultation-dialog" headerClassName="consult-header" bodyClassName="consult-content" closeClassName="consult-close" closeLabel="Fermer la consultation" storageKey="sauverndeko.consultation.width">{children}</DrawerDialog>;
}

export function ConsultationProvider({ children }) {
  const navigate=useNavigate();
  const openFolder=(key)=>{setHistory([]);navigate("/logistique?onglet=dossiers&dossier="+encodeURIComponent(key));};
  const { user, isAuthenticated } = useAuth();
  const [history, setHistory] = useState([]);
  useEffect(() => { setHistory([]); }, [user?.IdUser, user?.IdEntiteFk, user?.permissions?.canAccessAdmin, isAuthenticated, accessSignature(user)]);
  const open = useCallback((kind, id, label = "", criteria = {}, section = "identite") => {
    if (!user?.permissions?.canAccessAdmin || !moduleRights(user,"logistique").canRead || !id || !["produit", "commande", "indicateur"].includes(kind)) return;
    setHistory((current) => [...current.slice(-7), { kind, id, label, section, query: { ...criteria, take: 25, skip: 0 } }]);
  }, [user?.permissions?.canAccessAdmin, accessSignature(user)]);
  const update = (patch) => setHistory((current) => current.map((item, index) => index === current.length - 1 ? { ...item, ...patch } : item));
  const entry = history[history.length - 1];
  const openProductStock = (row, depotId = "") => open("produit",row.ID_Article,row.NomArticle,{depotId},"mouvements");
  return <Context.Provider value={{ openProductStock, openProductLots:(row)=>open("produit",row.ID_Article,row.NomArticle,{depotId:row.ID_DepotFk||row.depotId||""},"lots"), openProduct: (row) => open("produit", typeof row === "object" ? row.ID_Article || row.ID_ArticleFk : row, row?.NomArticle || "", {depotId:row?.ID_DepotFk||row?.depotId||""}), openOrder: (row) => open("commande", typeof row === "object" ? row.ID_Commande || row.ID_CmdFk || row.ID_cmdFk : row, row?.CodeCmd || ""), openOrderLines: (row) => open("commande", typeof row === "object" ? row.ID_Commande || row.ID_CmdFk || row.ID_cmdFk : row, row?.CodeCmd || "", {}, "lignes"), openOrderInvoice: (row) => open("commande", row && typeof row === "object" ? row.ID_Commande || row.ID_CommandeFk || row.ID_CmdFk || row.ID_cmdFk : row, row?.CodeCmd || row?.CodeFacture || "", {}, "facture"), openOrderPayments: (row) => open("commande", row && typeof row === "object" ? row.ID_Commande || row.ID_CommandeFk || row.ID_CmdFk || row.ID_cmdFk : row, row?.CodeCmd || row?.CodeFacture || row?.CodeFactureFk || "", {}, "reglements"), openFolder, openMetric: (key, criteria = {}, label = "") => open("indicateur", key, label, criteria) }}>{children}
    {entry && isAuthenticated ? <Dialog title={entry.kind === "produit" ? "Produit 360" + (entry.label ? " · " + entry.label : "") : entry.kind === "commande" ? "Bon de stock 360" + (entry.label ? " · " + entry.label : "") : entry.label || "Détail de l’indicateur"} onClose={() => setHistory([])} onBack={history.length > 1 ? () => setHistory((current) => current.slice(0, -1)) : null}>
      {entry.kind === "indicateur" ? <IndicatorContent key={entry.kind + entry.id} entry={entry} update={update} open={open} /> : <ObjectContent key={entry.kind + entry.id} entry={entry} update={update} open={open} openFolder={openFolder} />}
    </Dialog> : null}
  </Context.Provider>;
}
export function useConsultations() {
  const context = useContext(Context);
  if (!context) throw new Error("ConsultationProvider manquant.");
  return context;
}
