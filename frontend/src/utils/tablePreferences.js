// A column ID is a stable server contract, never its label or physical SQL position.
export function preferenceIds(catalogue, requested, usage = "table") {
  const allowed = new Set((catalogue || []).filter(column => usage === "export" ? column.exportable === true : column.tableAvailable !== false).map(column => column.id));
  return [...new Set((Array.isArray(requested) ? requested : []).filter(id => typeof id === "string" && allowed.has(id)))];
}

export function preferenceReference(catalogue, usage = "table") {
  const order = column => Number((usage === "export" ? column.defaultExportOrder : column.defaultOrder) ?? column.defaultOrder ?? 0);
  return [...(catalogue || [])].sort((a, b) => order(a) - order(b))
    .filter(column => usage === "export" ? column.exportable === true && column.defaultExport === true : column.tableAvailable !== false && column.defaultVisible === true)
    .map(column => column.id);
}

export function preferenceChoices(catalogue, selected, usage = "table") {
  const allowed = (catalogue || []).filter(column => usage === "export" ? column.exportable === true : column.tableAvailable !== false);
  const byId = new Map(allowed.map(column => [column.id, column]));
  const chosen = preferenceIds(catalogue, selected, usage);
  return [...chosen.map(id => byId.get(id)), ...allowed.filter(column => !chosen.includes(column.id))];
}

export function movePreference(ids, source, destination) {
  const next = [...ids], from = next.indexOf(source), to = next.indexOf(destination);
  if (from < 0 || to < 0 || from === to) return next;
  next.splice(from, 1); next.splice(to, 0, source);
  return next;
}

export const samePreference = (a, b) => Array.isArray(a) && Array.isArray(b) && a.length === b.length && a.every((id, index) => id === b[index]);
