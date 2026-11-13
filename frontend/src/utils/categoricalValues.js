/** Comparison key for categorical labels. Keep the original value for display and persistence. */
export function categoricalKey(value) {
  return String(value ?? "").normalize("NFC").trim().toLocaleLowerCase("fr");
}

export function sameCategory(left, right) {
  return categoricalKey(left) === categoricalKey(right);
}
