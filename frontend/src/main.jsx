import { ThemeProvider } from "./contexts/ThemeContext";
import React from "react";
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

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <ThemeProvider><BrowserRouter>
      <AuthProvider>
        <FollowupFoldersProvider><ConsultationProvider><App /></ConsultationProvider></FollowupFoldersProvider>
      </AuthProvider>
    </BrowserRouter></ThemeProvider>
  </React.StrictMode>
);
