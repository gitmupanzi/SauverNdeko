import { requestJson } from "./api";

function buildQueryString(options = {}) {
  const params = new URLSearchParams();

  Object.entries(options).forEach(([key, value]) => {
    if (value == null || value === "") {
      return;
    }

    params.set(key, String(value));
  });

  const queryString = params.toString();
  return queryString ? `?${queryString}` : "";
}

function logistiqueGet(path, options = {}) {
  return requestJson(`/api/logistique${path}${buildQueryString(options)}`, {
    requiresAuth: true,
  });
}

function logistiqueWrite(path, method, payload) {
  return requestJson(`/api/logistique${path}`, {
    method,
    requiresAuth: true,
    body: JSON.stringify(payload),
  });
}

export function fetchLogistiqueDashboard() {
  return logistiqueGet("/dashboard");
}

export function fetchLogistiqueReferences() {
  return logistiqueGet("/references");
}

export function fetchLogistiqueArticles(options = {}) {
  return logistiqueGet("/articles", options);
}

export function createLogistiqueArticle(payload) {
  return logistiqueWrite("/articles", "POST", payload);
}

export function updateLogistiqueArticle(id, payload) {
  return logistiqueWrite(`/articles/${id}`, "PUT", payload);
}

export function deleteLogistiqueArticle(id) {
  return requestJson(`/api/logistique/articles/${id}`, {
    method: "DELETE",
    requiresAuth: true,
  });
}

export function fetchLogistiqueCommandes(options = {}) {
  return logistiqueGet("/commandes", options);
}

export function createLogistiqueCommande(payload) {
  return logistiqueWrite("/commandes", "POST", payload);
}

export function updateLogistiqueCommande(id, payload) {
  return logistiqueWrite(`/commandes/${id}`, "PUT", payload);
}

export function fetchLogistiqueCommandeDetails(commandeId, options = {}) {
  return logistiqueGet(`/commandes/${commandeId}/details`, options);
}

export function fetchLogistiqueMouvements(options = {}) {
  return logistiqueGet("/mouvements", options);
}

export function createLogistiqueCommandeDetail(commandeId, payload) {
  return logistiqueWrite(`/commandes/${commandeId}/details`, "POST", payload);
}

export function updateLogistiqueCommandeDetail(commandeId, articleId, payload) {
  return logistiqueWrite(`/commandes/${commandeId}/details/${articleId}`, "PUT", payload);
}

export function deleteLogistiqueCommandeDetail(commandeId, articleId) {
  return requestJson(`/api/logistique/commandes/${commandeId}/details/${articleId}`, {
    method: "DELETE",
    requiresAuth: true,
  });
}

export function fetchLogistiqueStockAudit(options = {}) {
  return logistiqueGet("/stock/audit", options);
}

export function fetchLogistiqueAlertesStock(options = {}) {
  return logistiqueGet("/stock/alertes", options);
}

export function fetchLogistiqueConsommation(options = {}) {
  return logistiqueGet("/stock/consommation", options);
}

export function fetchLogistiqueCouverture(options = {}) {
  return logistiqueGet("/stock/couverture", options);
}

export function fetchLogistiqueCommandesSansDetails(options = {}) {
  return logistiqueGet("/commandes-sans-details", options);
}

export function fetchLogistiqueReglements(options = {}) {
  return logistiqueGet("/reglements", options);
}

export function fetchLogistiqueReglementEntries(options = {}) {
  return logistiqueGet("/reglements/entries", options);
}

export function createLogistiqueReglement(payload) {
  return logistiqueWrite("/reglements", "POST", payload);
}

export function updateLogistiqueReglement(id, payload) {
  return logistiqueWrite(`/reglements/${id}`, "PUT", payload);
}
