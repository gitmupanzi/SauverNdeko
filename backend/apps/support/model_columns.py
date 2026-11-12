"""Colonnes publiques du registre des modèles de suivi."""

LABELS = {
    "name": "Modèle",
    "type": "Type de dossier",
    "version": "Version",
    "stageCount": "Étapes",
    "active": "État",
    "entityName": "Entreprise",
    "description": "Description",
}


def table_source():
    return {"schema": "support", "name": "T_ModeleProcessus", "primaryKey": ["id"],
            "columns": [{"column_name": key} for key in LABELS]}
