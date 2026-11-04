// Un menu mobile et plusieurs fiches peuvent coexister. Chaque surface libère
// uniquement son verrou ; la dernière restaure le défilement d'origine.
const owners = new Set();
let previousOverflow = "";

export function lockBodyScroll(owner) {
  if (owners.has(owner)) return;
  if (!owners.size) previousOverflow = document.body.style.overflow;
  owners.add(owner);
  document.body.style.overflow = "hidden";
}

export function unlockBodyScroll(owner) {
  if (!owners.delete(owner)) return;
  if (!owners.size) document.body.style.overflow = previousOverflow;
}

export function isBodyScrollLocked() {
  return owners.size > 0;
}
