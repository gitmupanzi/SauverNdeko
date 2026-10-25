const PATH_MODULES = {"/catalogue":"catalogue","/produits":"produits","/pharmacies":"structures","/experts":"professionnels","/maladies":"sante","/discussions":"discussions","/logistique":"logistique","/territoires":"territoires","/admin":"administration"};
export function moduleForPath(pathname) { return PATH_MODULES[pathname.replace(/\/$/,"")]; }
export function moduleRights(user, key) { return user?.moduleAccess?.modules?.[key] || {canRead:false,canManage:false,canExport:false}; }
export function mayOpen(user, pathname) {
  if (pathname === "/referentiels") return Object.values(user?.moduleAccess?.modules || {}).some(item => item.canRead);
  const key = moduleForPath(pathname);
  return !key || moduleRights(user,key).canRead;
}
export function accessSignature(user) { return JSON.stringify(user?.moduleAccess || null); }
