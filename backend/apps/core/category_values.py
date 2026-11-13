"""Comparaison des libellés catégoriels en conservant leur forme enregistrée."""


from unicodedata import normalize


def category_key(value):
    """Retourne une clé temporaire sans modifier les accents ni les identifiants."""
    return normalize("NFC", value.strip()).lower() if isinstance(value, str) else ""
