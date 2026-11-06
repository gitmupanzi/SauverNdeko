import { requestJson } from "./api";

const root = "/api/discussions";
export const ANNOUNCEMENT_TITLE_LIMIT = 160;
export const ANNOUNCEMENT_BODY_LIMIT = 5000;

export function markMessagesRead(discussionId, messageIds, signal) {
  return requestJson(root + "/" + encodeURIComponent(discussionId) + "/lecture", {
    requiresAuth: true, method: "POST", body: JSON.stringify({ messageIds }), signal,
  });
}

export function getContacts(query, skip, signal) {
  const params = new URLSearchParams({ q: query, skip });
  return requestJson(root + "/contacts?" + params, { requiresAuth: true, signal });
}

export function getAnnouncementContext(signal) {
  return requestJson(root + "/annonces/contexte", { requiresAuth: true, signal });
}

export function getAnnouncements(tab, params, signal) {
  const path = tab === "recues" ? "/annonces/recues" : "/annonces";
  return requestJson(root + path + "?" + new URLSearchParams(params), { requiresAuth: true, signal });
}

export function publishAnnouncement(body) {
  return requestJson(root + "/annonces", { requiresAuth: true, method: "POST", body });
}

export function markNotificationRead(id) {
  return requestJson("/api/notifications/" + encodeURIComponent(id) + "/read", {
    requiresAuth: true,
    method: "PATCH",
  });
}

const notificationEvent = "sauverndeko:notifications-changed";
export function refreshNotifications() {
  window.dispatchEvent(new Event(notificationEvent));
}
export function onNotificationsChanged(handler) {
  window.addEventListener(notificationEvent, handler);
  return () => window.removeEventListener(notificationEvent, handler);
}

export function uncertainDelivery(response) {
  return !response || response.status === 0 || response.status >= 500;
}

export function newMessageRequestId() {
  if (crypto.randomUUID) return crypto.randomUUID();
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  const hex = Array.from(bytes, value => value.toString(16).padStart(2, "0")).join("");
  return [hex.slice(0, 8), hex.slice(8, 12), hex.slice(12, 16), hex.slice(16, 20), hex.slice(20)].join("-");
}

const fullDate = new Intl.DateTimeFormat("fr-CD", {
  day: "numeric", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit",
});
const shortDate = new Intl.DateTimeFormat("fr-CD", { day: "numeric", month: "short" });
const time = new Intl.DateTimeFormat("fr-CD", { hour: "2-digit", minute: "2-digit" });

export function communicationTime(value, short = false) {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  if (!short) return fullDate.format(date);
  return date.toDateString() === new Date().toDateString() ? time.format(date) : shortDate.format(date);
}

const day = new Intl.DateTimeFormat("fr-CD", { day: "numeric", month: "long", year: "numeric" });

export function chatDay(value) {
  const date = new Date(value);
  if (!value || Number.isNaN(date.getTime())) return "";
  const today = new Date();
  if (date.toDateString() === today.toDateString()) return "Aujourd’hui";
  today.setDate(today.getDate() - 1);
  return date.toDateString() === today.toDateString() ? "Hier" : day.format(date);
}

export function chatHour(value) {
  const date = new Date(value);
  return value && !Number.isNaN(date.getTime()) ? time.format(date) : "";
}
