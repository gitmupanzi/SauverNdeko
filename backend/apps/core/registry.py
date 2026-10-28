import json
from pathlib import Path
from .responses import APIError

DATA = json.loads(Path(__file__).with_name("registry.json").read_text(encoding="utf8"))
MODELS = DATA["models"]
VIEWS = DATA["views"]


def model(name):
    if name == 'T_BonCodeHistorique':
        raise APIError('Le journal des références est conservé par la base de données.', 'HISTORY_READ_ONLY', 403)
    if name in {"T_InterfaceTableau", "T_PreferenceTableau"}:
        raise APIError("Ces réglages personnels utilisent leur interface dédiée.", "DEDICATED_SETTINGS_REQUIRED", 403)
    if name not in MODELS:
        raise APIError("Modèle non disponible dans PostgreSQL.", "NOT_FOUND", 404)
    return MODELS[name]


def view(schema, name):
    result = VIEWS.get(schema + "." + name)
    if result is None:
        raise APIError("Vue non autorisée ou absente.", "NOT_FOUND", 404)
    return result
