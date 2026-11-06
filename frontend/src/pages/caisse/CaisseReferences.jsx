import {useAuth} from "../../contexts/AuthContext";
import {mayOpen} from "../../services/moduleAccess";
import ReferenceSettings from "../../components/ReferenceSettings";

const LISTS = [
  {key:"devises", title:"Devises des caisses", icon:"wallet"},
  {key:"typesCaisses", title:"Types de caisse", icon:"tag"},
  {key:"typesPaiements", title:"Types d’opération", icon:"movements"},
];

export default function CaisseReferences({references = {}, onClose}) {
  const {user} = useAuth();
  const mappings = LISTS.map(({key, title, icon}) => {
    const metadata = references.referenceMeta?.[key];
    return {
      sourceKey:key,
      presentation:{title, icon},
      config:{referenceKey:key},
      effectiveIds:metadata?.categoryIds,
      effectiveCategoryLabels:metadata?.categoryLabels?.join(", "),
      defaultCategoryId:metadata?.defaultCategoryId,
      isLocked:metadata?.effectiveSource === "default",
    };
  });
  return <ReferenceSettings title="Caisse" mappings={mappings} references={references} showHistory={false}
    showCatalogue={mayOpen(user, "/referentiels")} onClose={onClose}/>;
}
