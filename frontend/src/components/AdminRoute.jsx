import { Navigate, useLocation } from "react-router-dom";
import { loginPathFor } from "../services/authNavigation";
import { useAuth } from "../contexts/AuthContext";

export default function AdminRoute({ children }) {
  const location = useLocation();
  const { loading, isAuthenticated, user } = useAuth();

  if (loading) {
    return (
      <div className="page-shell">
        <section className="table-empty-state">Verification des droits d'administration...</section>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to={loginPathFor(location)} replace />;
  }

  if (!user?.permissions?.canAccessAdmin) {
    return <Navigate to="/profil" replace />;
  }

  return children;
}
