import lazyView from "../components/LazyView";
import AdminPortal from "./admin/AdminPortal";

// Compatibilité des anciens écrans génériques ; /territoires utilise son portail dédié.
const LegacyAdmin = lazyView(() => import("./LegacyAdmin"), { label: "Ouverture de l’organisation territoriale…" });
export default function Admin(props) {
  return props.schemaOnly ? <LegacyAdmin {...props}/> : <AdminPortal/>;
}
