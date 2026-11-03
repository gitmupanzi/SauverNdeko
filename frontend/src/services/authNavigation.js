const INTERNAL_ORIGIN = "https://sauverndeko.invalid";

export function normalizeAuthRedirect(rawValue, fallbackPath = "/espace") {
  if (
    typeof rawValue !== "string" ||
    !rawValue.startsWith("/") ||
    rawValue.startsWith("//") ||
    /[\\\u0000-\u001f\u007f]/.test(rawValue)
  ) {
    return fallbackPath;
  }

  try {
    const target = new URL(rawValue, INTERNAL_ORIGIN);
    const decodedPath = decodeURIComponent(target.pathname);
    if (
      target.origin !== INTERNAL_ORIGIN ||
      decodedPath.startsWith("//") ||
      /[\\\u0000-\u001f\u007f]/.test(decodedPath) ||
      /^\/(login|register)(\/|$)/i.test(decodedPath)
    ) {
      return fallbackPath;
    }
    return target.pathname + target.search + target.hash;
  } catch {
    return fallbackPath;
  }
}

export function loginPathFor(location) {
  const destination = normalizeAuthRedirect(
    (location.pathname || "/espace") + (location.search || "") + (location.hash || "")
  );
  return destination === "/espace" ? "/login" : "/login?redirect=" + encodeURIComponent(destination);
}
