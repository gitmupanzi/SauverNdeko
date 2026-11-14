import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import { requestJson } from "../services/api";
import { moduleRights, tabRights } from "../services/moduleAccess";
import AppIcon from "./AppIcon";

export default function SearchNeedAction({ source, shareSearch = false }) {
  const { user } = useAuth();
  const discussions = moduleRights(user, "discussions");
  const requests = tabRights(user, "discussions", "demandes");
  const canManage = user?.moduleAccess?.readOnly === false &&
    discussions.canRead && discussions.canManage && requests.canRead && requests.canManage;
  if (!canManage) return null;

  return shareSearch
    ? <ResearchShareLink key={user.IdUser + ":" + user.IdEntiteFk} source={source}/>
    : <NeedLink source={source}/>;
}

function ResearchShareLink({ source }) {
  const [canShare, setCanShare] = useState(false);
  useEffect(() => {
    const controller = new AbortController();
    requestJson("/api/discussions/besoins/options", {
      requiresAuth: true,
      signal: controller.signal,
    }).then(response => {
      if (!controller.signal.aborted) {
        setCanShare(response?.success === true && response.data?.canWrite === true &&
          response.data.canShareResearch === true);
      }
    }, () => {});
    return () => controller.abort();
  }, []);

  return canShare ? <NeedLink source={source} shareSearch/> : null;
}

function NeedLink({ source, shareSearch = false }) {
  return (
    <Link
      className={shareSearch ? "ui-action" : "ui-action is-primary"}
      to="/discussions?onglet=demandes"
      state={{ newNeed: shareSearch ? { source, nature: "recherche" } : { source } }}
    >
      <AppIcon name="document" /> {shareSearch ? "Partager cette recherche" : "Exprimer un besoin"}
    </Link>
  );
}
