-- Catalogue du tableau des modèles de suivi, sans écriture métier.
SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '120s';

INSERT INTO referentiel."T_InterfaceTableau" ("CleInterface", "Module", "Colonnes")
SELECT 'support.modeles', 'support',
       jsonb_agg(jsonb_build_object(
           'id', id, 'label', label, 'type', data_type,
           'exportable', id <> 'actions', 'defaultVisible', visible,
           'defaultExport', visible AND id <> 'actions', 'tableAvailable', true,
           'defaultOrder', position, 'defaultExportOrder', position
       ) ORDER BY position)
FROM (VALUES
    (0, 'name', 'Modèle', 'text', true),
    (1, 'type', 'Type de dossier', 'text', true),
    (2, 'version', 'Version', 'number', true),
    (3, 'stageCount', 'Étapes', 'number', true),
    (4, 'active', 'État', 'text', true),
    (5, 'actions', 'Actions', 'text', true),
    (6, 'entityName', 'Entreprise', 'text', false),
    (7, 'description', 'Description', 'text', false)
) AS columns(position, id, label, data_type, visible)
ON CONFLICT ("CleInterface") DO NOTHING;
