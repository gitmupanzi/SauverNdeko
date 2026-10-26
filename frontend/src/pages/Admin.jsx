import lazyView from "../components/LazyView";
import AdminPortal from "./admin/AdminPortal";

// Les anciens écrans territoriaux conservent leur contrat jusqu’à leur refonte.
const LegacyAdmin = lazyView(() => import("./LegacyAdmin"), { label: "Ouverture de l’organisation territoriale…" });
export default function Admin(props) {
  return props.schemaOnly ? <LegacyAdmin {...props}/> : <AdminPortal/>;
}
