import {categoricalKey} from "./categoricalValues";

/** Classify a configured document without using a database ID or interpreting zero as an order. */
export function stockDocumentKind(type) {
  if (!type) return "";
  const kind = categoricalKey(type.kind);
  const nature = categoricalKey(type.NatureBon);
  const codes = [type.abbr, type.AbrTypeCmd, type.AbrGenerique].map(categoricalKey);
  if (kind === "commande" || nature === "commande" || codes.includes("cmd")) return "commande";

  const direction = kind || nature;
  if (direction === "entree" || direction === "entrée") return "entree";
  if (direction === "sortie") return "sortie";
  const sign=Number(type.sign ?? type.SigneCommande);
  if (sign === 1 || type.EstCommandeEntree === true) return "entree";
  if (sign === -1 || type.EstCommandeSortie === true) return "sortie";
  const code = categoricalKey(type.abbr || type.AbrTypeCmd || type.AbrGenerique || type.TypeCmd);
  return code === "be" || code.startsWith("entr") ? "entree" : code === "bs" || code.startsWith("sort") ? "sortie" : "";
}

export const isStockOrder = record => stockDocumentKind(record) === "commande";
export const canCreateStockInvoice = record => stockDocumentKind(record) === "sortie" && record?.returnContext?.isReturn !== true && record?.canInvoice !== false;

export function previousStockCode(record) {
  const previous=typeof record?.AncienCodeCmd === "string" ? record.AncienCodeCmd.trim() : "";
  return previous && previous !== String(record?.CodeCmd ?? "").trim() ? previous : "";
}
