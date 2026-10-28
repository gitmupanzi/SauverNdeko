import { requestJson } from "./api";

const pathFor = key => "/api/tableaux/" + encodeURIComponent(key) + "/preferences";

export function fetchTablePreferences(interfaceKey, signal) {
  return requestJson(pathFor(interfaceKey), { requiresAuth: true, signal });
}

export function saveTablePreferences(interfaceKey, usage, columns, version, signal) {
  return requestJson(pathFor(interfaceKey), {
    requiresAuth: true, method: "PUT", signal,
    body: JSON.stringify({ usage, columns, version }),
  });
}

export function resetTablePreferences(interfaceKey, usage, version, signal) {
  return requestJson(pathFor(interfaceKey), {
    requiresAuth: true, method: "DELETE", signal,
    body: JSON.stringify({ usage, version }),
  });
}
