const PATH_MODULES = {"/catalogue":"catalogue","/produits":"produits","/pharmacies":"structures","/experts":"professionnels","/maladies":"sante","/discussions":"discussions","/logistique":"logistique","/caisse":"caisse","/territoires":"territoires","/support":"support","/data-science":"data-science","/parametres":"parametres","/guide":"guide","/admin":"administration","/abonnements":"administration"};
export function moduleForPath(pathname) { return PATH_MODULES[pathname.replace(/\/$/,"")]; }
export function moduleRights(user, key) { return user?.moduleAccess?.modules?.[key] || {canRead:false,canManage:false,canExport:false}; }
export function tabRights(user, key, tab) {
  return user?.moduleAccess?.tabs?.[key]?.[tab] || moduleRights(user, key);
}
export function mayOpen(user, pathname) {
  if (pathname === "/referentiels") return Object.values(user?.moduleAccess?.modules || {}).some(item => item.canRead);
  const key = moduleForPath(pathname);
  if (key === "territoires" && user?.moduleAccess?.platformAdmin !== true) return false;
  return !key || moduleRights(user,key).canRead;
}
export function accessSignature(user) { return JSON.stringify(user?.moduleAccess || null); }
