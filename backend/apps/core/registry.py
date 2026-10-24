import json
from pathlib import Path
from .responses import APIError

DATA = json.loads(Path(__file__).with_name("registry.json").read_text(encoding="utf8"))
MODELS = DATA["models"]
VIEWS = DATA["views"]


def model(name):
    if name not in MODELS:
        raise APIError("Modèle non disponible dans PostgreSQL.", "NOT_FOUND", 404)
    return MODELS[name]


def view(schema, name):
    result = VIEWS.get(schema + "." + name)
    if result is None:
        raise APIError("Vue non autorisée ou absente.", "NOT_FOUND", 404)
    return result
