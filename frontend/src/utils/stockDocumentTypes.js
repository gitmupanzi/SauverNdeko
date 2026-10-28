/** Classify a configured document without using a database ID or interpreting zero as an order. */
export function stockDocumentKind(type) {
  if (!type) return "";
  if (type.kind === "commande" || type.NatureBon === "commande" || [type.abbr, type.AbrTypeCmd, type.AbrGenerique].some(code => code === "CMD")) return "commande";
  if (["entree", "sortie"].includes(type.kind || type.NatureBon)) return type.kind || type.NatureBon;
  const sign=Number(type.sign ?? type.SigneCommande);
  if (sign === 1 || type.EstCommandeEntree === true) return "entree";
  if (sign === -1 || type.EstCommandeSortie === true) return "sortie";
  const code=String(type.abbr || type.AbrTypeCmd || type.TypeCmd || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").trim().toLowerCase();
  return code === "be" || code.startsWith("entr") ? "entree" : code === "bs" || code.startsWith("sort") ? "sortie" : "";
}

export const isStockOrder = record => stockDocumentKind(record) === "commande";
export const canCreateStockInvoice = record => stockDocumentKind(record) === "sortie" && record?.returnContext?.isReturn !== true && record?.canInvoice !== false;

export function previousStockCode(record) {
  const previous=typeof record?.AncienCodeCmd === "string" ? record.AncienCodeCmd.trim() : "";
  return previous && previous !== String(record?.CodeCmd ?? "").trim() ? previous : "";
}
