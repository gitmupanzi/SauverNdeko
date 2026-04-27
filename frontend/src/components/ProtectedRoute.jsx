import { Navigate, useLocation } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";

function buildRedirectPath(location) {
  return `${location.pathname || "/"}${location.search || ""}${location.hash || ""}`;
}

export default function ProtectedRoute({ children }) {
  const location = useLocation();
  const { loading, isAuthenticated } = useAuth();

  if (loading) {
    return (
      <div className="page-shell">
        <section className="table-empty-state">Verification de la session...</section>
      </div>
    );
  }

  if (!isAuthenticated) {
    const redirectPath = encodeURIComponent(buildRedirectPath(location));
    return <Navigate to={`/login?redirect=${redirectPath}`} replace />;
  }

  return children;
}
