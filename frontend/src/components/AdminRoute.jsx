import { Navigate } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";

export default function AdminRoute({ children }) {
  const { loading, isAuthenticated, user } = useAuth();

  if (loading) {
    return (
      <div className="page-shell">
        <section className="table-empty-state">Verification des droits d'administration...</section>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/login?redirect=%2Fadmin" replace />;
  }

  if (!user?.permissions?.canAccessAdmin) {
    return <Navigate to="/profil" replace />;
  }

  return children;
}
