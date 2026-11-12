-- Catalogue de présentation du registre de comptage physique.
-- Les données métier restent dans les vues V_Inventaire et V_InventaireLigne.
SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '120s';

INSERT INTO referentiel."T_InterfaceTableau" ("CleInterface", "Module", "Colonnes")
SELECT 'logistique.lignes-inventaires', 'logistique',
       jsonb_agg(jsonb_build_object(
           'id', id, 'label', label, 'type', data_type,
           'exportable', id <> 'actions', 'defaultVisible', visible,
           'defaultExport', visible AND id <> 'actions', 'tableAvailable', true,
           'defaultOrder', position, 'defaultExportOrder', position
       ) ORDER BY position)
FROM (VALUES
    (0, 'CodeInventaire', 'Inventaire', 'text', true),
    (1, 'DateInventaire', 'Date et heure', 'date', true),
    (2, 'NomDepot', 'Dépôt', 'text', true),
    (3, 'NomArticle', 'Article', 'text', true),
    (4, 'QteTheorique', 'Quantité théorique', 'number', true),
    (5, 'QteComptee', 'Quantité physique', 'number', true),
    (6, 'Unite', 'Unité', 'text', true),
    (7, 'Ecart', 'Écart', 'number', true),
    (8, 'Justification', 'Justification', 'text', true),
    (9, 'EtatInventaire', 'État de l’inventaire', 'text', true),
    (10, 'actions', 'Actions', 'text', true),
    (11, 'CodeArticleInterne', 'Code article', 'text', false),
    (12, 'Motif', 'Motif', 'text', false),
    (13, 'CodeCorrection', 'Bon de correction', 'text', false),
    (14, 'CodeAnnulation', 'Bon d’annulation', 'text', false)
) AS columns(position, id, label, data_type, visible)
ON CONFLICT ("CleInterface") DO NOTHING;
