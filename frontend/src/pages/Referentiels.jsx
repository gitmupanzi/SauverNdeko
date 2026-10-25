import ModuleHeader from "../components/ModuleHeader";
import Admin from "./Admin";
import "./logistique/LogistiqueModern.css";
export default function Referentiels() {
  return <div className="logistics-modern territorial-module"><ModuleHeader title="Référentiels"/><Admin schemaOnly="referentiel" moduleTitle="Référentiels"/></div>;
}
