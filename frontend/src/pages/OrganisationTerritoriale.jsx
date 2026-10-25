import ModuleHeader from "../components/ModuleHeader";
import Admin from "./Admin";
import "./logistique/LogistiqueModern.css";

export default function OrganisationTerritoriale() {
  return <div className="logistics-modern territorial-module"><ModuleHeader title="Organisation territoriale" /><Admin schemaOnly="geolocalisation" moduleTitle="Organisation territoriale" /></div>;
}
