import { ThemeProvider } from "./contexts/ThemeContext";
import React from "react";
import {EntityScopeProvider,useEntityScope} from "./contexts/EntityScopeContext";
import ReactDOM from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import "bootstrap/dist/css/bootstrap.min.css";
import "bootstrap-icons/font/bootstrap-icons.css";
import App from "./App.jsx";
import { AuthProvider } from "./contexts/AuthContext";
import { FollowupFoldersProvider } from "./contexts/FollowupFoldersContext";
import { ConsultationProvider } from "./components/ConsultationProvider";
import "./styles.css";
import "./theme.css";

function EntityWorkspace(){const {scopeKey}=useEntityScope();return <FollowupFoldersProvider key={scopeKey}><ConsultationProvider><App /></ConsultationProvider></FollowupFoldersProvider>;}

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <ThemeProvider><BrowserRouter>
      <AuthProvider>
        <EntityScopeProvider><EntityWorkspace /></EntityScopeProvider>
      </AuthProvider>
    </BrowserRouter></ThemeProvider>
  </React.StrictMode>
);
