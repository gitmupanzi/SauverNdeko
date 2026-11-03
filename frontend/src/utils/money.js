import {referenceLabel} from "./referenceOptions";
// Monetary values stay decimal strings throughout the UI; no implicit conversion.
export function decimalParts(value) {
  if (value == null || String(value).trim() === "") return null;
  const match = /^([+-]?)(\d+)(?:[.,](\d+))?$/.exec(String(value).trim());
  if (!match) return null;
  const fraction = match[3] || "";
  return { units: BigInt((match[1] === "-" ? "-" : "") + match[2] + fraction), scale: fraction.length };
}
function decimalString(units, scale) {
  const negative = units < 0n;
  const digits = (negative ? -units : units).toString().padStart(scale + 1, "0");
  return (negative ? "-" : "") + (scale ? digits.slice(0, -scale) + "." + digits.slice(-scale) : digits);
}
export function compareDecimal(left, right) {
  const a = decimalParts(left), b = decimalParts(right);
  if (!a || !b) return null;
  const scale = Math.max(a.scale, b.scale);
  const difference = a.units * 10n ** BigInt(scale - a.scale) - b.units * 10n ** BigInt(scale - b.scale);
  return difference < 0n ? -1 : difference > 0n ? 1 : 0;
}
export function multiplyDecimal(left, right) {
  const a = decimalParts(left), b = decimalParts(right);
  return a && b ? decimalString(a.units * b.units, a.scale + b.scale) : null;
}
export function currencyCode(value) {
  const code = String(value || "").trim().toUpperCase();
  return code === "EURO" ? "EUR" : code;
}
export function formatCurrency(value, code) {
  const amount = decimalParts(value);
  if (!amount) return "—";
  const parts = decimalString(amount.units, amount.scale).split(".");
  const negative = parts[0].startsWith("-");
  const integer = (negative ? parts[0].slice(1) : parts[0]).replace(/\B(?=(\d{3})+(?!\d))/g, "\u202f");
  const fraction = (parts[1] || "").replace(/0+$/, "").padEnd(2, "0");
  return (negative ? "−" : "") + integer + "," + fraction + (currencyCode(code) ? " " + currencyCode(code) : " · Devise non renseignée");
}
export function currencyOptions(references, unknown = false) {
  const items = (references?.currencies || []).map(item => {
    const generic=["AbrGenerique","abbr","NomGenerique","ID_Generique"].some(key=>Object.prototype.hasOwnProperty.call(item,key)),code=currencyCode(item.code),label=generic?referenceLabel(item):code||referenceLabel(item);
    return {...item,value:String(item.id??item.ID_Generique),label,disabled:item.disabled===true||item.incompatible===true||item.active===false};
  });
  return unknown ? [...items, { value:"sans-devise", label:"Devise non renseignée" }] : items;
}
/** Une liste propre au champ, même vide, prime sur le contrat historique partagé. */
export function fieldCurrencyReferences(references,key) {
 if(!Array.isArray(references?.[key]))return references;
 const currencies=references[key],usd=currencies.filter(item=>currencyCode(item.code||item.abbr)==="USD"&&!item.disabled&&!item.incompatible&&item.active!==false);
 return {...references,currencies,defaultCurrencyId:usd.length===1?usd[0].id:null};
}
export function newCurrencyId(references) {
  const id = references?.defaultCurrencyId;
  return id != null && (references?.currencies || []).some(item => String(item.id) === String(id)&&!item.disabled&&!item.incompatible&&item.active!==false) ? String(id) : "";
}
export function formatCurrencyGroups(groups) {
  return Array.isArray(groups) && groups.length ? groups.map(group => formatCurrency(group.value ?? group.montant, group.code)).join(" · ") : "—";
}
export function formatConsumptionMoney(row) {
  let groups = row.MontantsParDevise;
  if (typeof groups === "string") { try { groups = JSON.parse(groups); } catch { groups = null; } }
  return Array.isArray(groups) && groups.length ? formatCurrencyGroups(groups) : formatCurrency(row.ValeurConsoMensuelle, row.DeviseCode);
}
export function sameCurrency(article, document) {
  return article?.currencyId != null && document?.ID_DeviseFk != null && String(article.currencyId) === String(document.ID_DeviseFk);
}
export function withCurrencyColumn(columns, rows) {
  if (columns.some(column => column.key === "DeviseCode") || !columns.some(column => /^(PU|PV|Montant|TotalRegle|Reste|Valeur|Marge)/.test(column.key))) return columns;
  return [...columns, { key:"DeviseCode",label:"Devise",exportValue:row => currencyCode(row.DeviseCode || row.currencyCode) || "Non renseignée" }];
}
