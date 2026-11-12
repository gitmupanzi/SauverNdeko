-- Catalogues fermés des quatre registres multi-dépôts.
-- Ajoute uniquement des métadonnées de présentation ; aucun stock, bon,
-- transfert, inventaire ou choix personnel existant n'est modifié.
SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '120s';
INSERT INTO referentiel."T_InterfaceTableau" ("CleInterface","Module","Colonnes")
SELECT key,'logistique',value FROM jsonb_each($catalogues$
{
  "logistique.depots": [
    {
      "id": "CodeDepot",
      "label": "Code",
      "type": "text",
      "exportable": true,
      "defaultVisible": true,
      "defaultExport": true,
      "defaultOrder": 0,
      "defaultExportOrder": 0,
      "tableAvailable": true
    },
    {
      "id": "NomDepot",
      "label": "Dépôt",
      "type": "text",
      "exportable": true,
      "defaultVisible": true,
      "defaultExport": true,
      "defaultOrder": 1,
      "defaultExportOrder": 1,
      "tableAvailable": true
    },
    {
      "id": "AdresseDepot",
      "label": "Adresse",
      "type": "text",
      "exportable": true,
      "defaultVisible": true,
      "defaultExport": true,
      "defaultOrder": 2,
      "defaultExportOrder": 2,
      "tableAvailable": true
    },
    {
      "id": "Principal",
      "label": "Principal",
      "type": "boolean",
      "exportable": true,
      "defaultVisible": true,
      "defaultExport": true,
      "defaultOrder": 3,
      "defaultExportOrder": 3,
      "tableAvailable": true
    },
    {
      "id": "Actif",
      "label": "État",
      "type": "boolean",
      "exportable": true,
      "defaultVisible": true,
      "defaultExport": true,
      "defaultOrder": 4,
      "defaultExportOrder": 4,
      "tableAvailable": true
    },
    {
      "id": "actions",
      "label": "Actions",
      "type": "text",
      "exportable": false,
      "defaultVisible": true,
      "defaultExport": false,
      "defaultOrder": 5,
      "defaultExportOrder": 5,
      "tableAvailable": true
    },
    {
      "id": "ID_Depot",
      "label": "N° dépôt",
      "type": "number",
      "exportable": true,
      "defaultVisible": false,
      "defaultExport": false,
      "defaultOrder": 6,
      "defaultExportOrder": 6,
      "tableAvailable": false
    },
    {
      "id": "NomEntite",
      "label": "Entreprise",
      "type": "text",
      "exportable": true,
      "defaultVisible": false,
      "defaultExport": false,
      "defaultOrder": 7,
      "defaultExportOrder": 7,
      "tableAvailable": false
    },
    {
      "id": "NbArticles",
      "label": "Articles",
      "type": "number",
      "exportable": true,
      "defaultVisible": false,
      "defaultExport": false,
      "defaultOrder": 8,
      "defaultExportOrder": 8,
      "tableAvailable": false
    },
    {
      "id": "StockPhysique",
      "label": "Stock physique",
      "type": "number",
      "exportable": true,
      "defaultVisible": false,
      "defaultExport": false,
      "defaultOrder": 9,
      "defaultExportOrder": 9,
      "tableAvailable": false
    },
    {
      "id": "StockReserve",
      "label": "Réservé",
      "type": "number",
      "exportable": true,
      "defaultVisible": false,
      "defaultExport": false,
      "defaultOrder": 10,
      "defaultExportOrder": 10,
      "tableAvailable": false
    },
    {
      "id": "CreeLe",
      "label": "Créé le",
      "type": "date",
      "exportable": true,
      "defaultVisible": false,
      "defaultExport": false,
      "defaultOrder": 11,
      "defaultExportOrder": 11,
      "tableAvailable": false
    },
    {
      "id": "ModifieLe",
      "label": "Modifié le",
      "type": "date",
      "exportable": true,
      "defaultVisible": false,
      "defaultExport": false,
      "defaultOrder": 12,
      "defaultExportOrder": 12,
      "tableAvailable": false
    }
  ],
  "logistique.stocks-depots": [
    {
      "id": "NomArticle",
      "label": "Article",
      "type": "text",
      "exportable": true,
      "defaultVisible": true,
      "defaultExport": true,
      "defaultOrder": 0,
      "defaultExportOrder": 0,
      "tableAvailable": true
    },
    {
      "id": "NomDepot",
      "label": "Dépôt",
      "type": "text",
      "exportable": true,
      "defaultVisible": true,
      "defaultExport": true,
      "defaultOrder": 1,
      "defaultExportOrder": 1,
      "tableAvailable": true
    },
    {
      "id": "StockPhysique",
      "label": "Stock physique",
      "type": "number",
      "exportable": true,
      "defaultVisible": true,
      "defaultExport": true,
      "defaultOrder": 2,
      "defaultExportOrder": 2,
      "tableAvailable": true
    },
    {
      "id": "StockDisponible",
      "label": "Disponible",
      "type": "number",
      "exportable": true,
      "defaultVisible": true,
      "defaultExport": true,
      "defaultOrder": 3,
      "defaultExportOrder": 3,
      "tableAvailable": true
    },
    {
      "id": "StockReserve",
      "label": "Réservé",
      "type": "number",
      "exportable": true,
      "defaultVisible": true,
      "defaultExport": true,
      "defaultOrder": 4,
      "defaultExportOrder": 4,
      "tableAvailable": true
    },
    {
      "id": "StockIndisponible",
      "label": "Indisponible",
      "type": "number",
      "exportable": true,
      "defaultVisible": true,
      "defaultExport": true,
      "defaultOrder": 5,
      "defaultExportOrder": 5,
      "tableAvailable": true
    },
    {
      "id": "StockEntreprise",
      "label": "Stock entreprise",
      "type": "number",
      "exportable": true,
      "defaultVisible": true,
      "defaultExport": true,
      "defaultOrder": 6,
      "defaultExportOrder": 6,
      "tableAvailable": true
    },
    {
      "id": "StockSansLot",
      "label": "Sans lot",
      "type": "number",
      "exportable": true,
      "defaultVisible": false,
      "defaultExport": false,
      "defaultOrder": 7,
      "defaultExportOrder": 7,
      "tableAvailable": false
    },
    {
      "id": "CodeDepot",
      "label": "Code",
      "type": "text",
      "exportable": true,
      "defaultVisible": false,
      "defaultExport": false,
      "defaultOrder": 8,
      "defaultExportOrder": 8,
      "tableAvailable": false
    },
    {
      "id": "AbrUnite",
      "label": "Unité",
      "type": "text",
      "exportable": true,
      "defaultVisible": false,
      "defaultExport": false,
      "defaultOrder": 9,
      "defaultExportOrder": 9,
      "tableAvailable": false
    }
  ],
  "logistique.transferts": [
    {
      "id": "CodeTransfert",
      "label": "Transfert",
      "type": "text",
      "exportable": true,
      "defaultVisible": true,
      "defaultExport": true,
      "defaultOrder": 0,
      "defaultExportOrder": 0,
      "tableAvailable": true
    },
    {
      "id": "DateTransfert",
      "label": "Date et heure",
      "type": "date",
      "exportable": true,
      "defaultVisible": true,
      "defaultExport": true,
      "defaultOrder": 1,
      "defaultExportOrder": 1,
      "tableAvailable": true
    },
    {
      "id": "DepotSource",
      "label": "Dépôt source",
      "type": "text",
      "exportable": true,
      "defaultVisible": true,
      "defaultExport": true,
      "defaultOrder": 2,
      "defaultExportOrder": 2,
      "tableAvailable": true
    },
    {
      "id": "DepotDestination",
      "label": "Dépôt destination",
      "type": "text",
      "exportable": true,
      "defaultVisible": true,
      "defaultExport": true,
      "defaultOrder": 3,
      "defaultExportOrder": 3,
      "tableAvailable": true
    },
    {
      "id": "EtatCode",
      "label": "État",
      "type": "text",
      "exportable": true,
      "defaultVisible": true,
      "defaultExport": true,
      "defaultOrder": 4,
      "defaultExportOrder": 4,
      "tableAvailable": true
    },
    {
      "id": "NbLignes",
      "label": "Lignes",
      "type": "number",
      "exportable": true,
      "defaultVisible": true,
      "defaultExport": true,
      "defaultOrder": 5,
      "defaultExportOrder": 5,
      "tableAvailable": true
    },
    {
      "id": "actions",
      "label": "Actions",
      "type": "text",
      "exportable": false,
      "defaultVisible": true,
      "defaultExport": false,
      "defaultOrder": 6,
      "defaultExportOrder": 6,
      "tableAvailable": true
    },
    {
      "id": "Motif",
      "label": "Motif",
      "type": "text",
      "exportable": true,
      "defaultVisible": false,
      "defaultExport": false,
      "defaultOrder": 7,
      "defaultExportOrder": 7,
      "tableAvailable": false
    },
    {
      "id": "ReferenceTransfert",
      "label": "Référence",
      "type": "text",
      "exportable": true,
      "defaultVisible": false,
      "defaultExport": false,
      "defaultOrder": 8,
      "defaultExportOrder": 8,
      "tableAvailable": false
    },
    {
      "id": "QteTransit",
      "label": "En transit",
      "type": "number",
      "exportable": true,
      "defaultVisible": false,
      "defaultExport": false,
      "defaultOrder": 9,
      "defaultExportOrder": 9,
      "tableAvailable": false
    },
    {
      "id": "QteExpediee",
      "label": "Expédié",
      "type": "number",
      "exportable": true,
      "defaultVisible": false,
      "defaultExport": false,
      "defaultOrder": 10,
      "defaultExportOrder": 10,
      "tableAvailable": false
    },
    {
      "id": "QteRecue",
      "label": "Reçu",
      "type": "number",
      "exportable": true,
      "defaultVisible": false,
      "defaultExport": false,
      "defaultOrder": 11,
      "defaultExportOrder": 11,
      "tableAvailable": false
    },
    {
      "id": "QteRetournee",
      "label": "Retourné",
      "type": "number",
      "exportable": true,
      "defaultVisible": false,
      "defaultExport": false,
      "defaultOrder": 12,
      "defaultExportOrder": 12,
      "tableAvailable": false
    },
    {
      "id": "QteEcart",
      "label": "Écart",
      "type": "number",
      "exportable": true,
      "defaultVisible": false,
      "defaultExport": false,
      "defaultOrder": 13,
      "defaultExportOrder": 13,
      "tableAvailable": false
    },
    {
      "id": "CreeLe",
      "label": "Créé le",
      "type": "date",
      "exportable": true,
      "defaultVisible": false,
      "defaultExport": false,
      "defaultOrder": 14,
      "defaultExportOrder": 14,
      "tableAvailable": false
    },
    {
      "id": "ModifieLe",
      "label": "Modifié le",
      "type": "date",
      "exportable": true,
      "defaultVisible": false,
      "defaultExport": false,
      "defaultOrder": 15,
      "defaultExportOrder": 15,
      "tableAvailable": false
    }
  ],
  "logistique.inventaires": [
    {
      "id": "CodeInventaire",
      "label": "Inventaire",
      "type": "text",
      "exportable": true,
      "defaultVisible": true,
      "defaultExport": true,
      "defaultOrder": 0,
      "defaultExportOrder": 0,
      "tableAvailable": true
    },
    {
      "id": "DateInventaire",
      "label": "Date et heure",
      "type": "date",
      "exportable": true,
      "defaultVisible": true,
      "defaultExport": true,
      "defaultOrder": 1,
      "defaultExportOrder": 1,
      "tableAvailable": true
    },
    {
      "id": "Motif",
      "label": "Motif",
      "type": "text",
      "exportable": true,
      "defaultVisible": true,
      "defaultExport": true,
      "defaultOrder": 2,
      "defaultExportOrder": 2,
      "tableAvailable": true
    },
    {
      "id": "NbArticles",
      "label": "Articles",
      "type": "number",
      "exportable": true,
      "defaultVisible": true,
      "defaultExport": true,
      "defaultOrder": 3,
      "defaultExportOrder": 3,
      "tableAvailable": true
    },
    {
      "id": "NbEcarts",
      "label": "Écarts",
      "type": "number",
      "exportable": true,
      "defaultVisible": true,
      "defaultExport": true,
      "defaultOrder": 4,
      "defaultExportOrder": 4,
      "tableAvailable": true
    },
    {
      "id": "Etat",
      "label": "État",
      "type": "text",
      "exportable": true,
      "defaultVisible": true,
      "defaultExport": true,
      "defaultOrder": 5,
      "defaultExportOrder": 5,
      "tableAvailable": true
    },
    {
      "id": "actions",
      "label": "Actions",
      "type": "text",
      "exportable": false,
      "defaultVisible": true,
      "defaultExport": false,
      "defaultOrder": 6,
      "defaultExportOrder": 6,
      "tableAvailable": true
    },
    {
      "id": "ValideLe",
      "label": "Validé le",
      "type": "date",
      "exportable": true,
      "defaultVisible": false,
      "defaultExport": false,
      "defaultOrder": 7,
      "defaultExportOrder": 7,
      "tableAvailable": false
    },
    {
      "id": "AnnuleLe",
      "label": "Annulé le",
      "type": "date",
      "exportable": true,
      "defaultVisible": false,
      "defaultExport": false,
      "defaultOrder": 8,
      "defaultExportOrder": 8,
      "tableAvailable": false
    },
    {
      "id": "MotifAnnulation",
      "label": "Motif d’annulation",
      "type": "text",
      "exportable": true,
      "defaultVisible": false,
      "defaultExport": false,
      "defaultOrder": 9,
      "defaultExportOrder": 9,
      "tableAvailable": false
    },
    {
      "id": "CreeLe",
      "label": "Créé le",
      "type": "date",
      "exportable": true,
      "defaultVisible": false,
      "defaultExport": false,
      "defaultOrder": 10,
      "defaultExportOrder": 10,
      "tableAvailable": false
    },
    {
      "id": "ModifieLe",
      "label": "Modifié le",
      "type": "date",
      "exportable": true,
      "defaultVisible": false,
      "defaultExport": false,
      "defaultOrder": 11,
      "defaultExportOrder": 11,
      "tableAvailable": false
    }
  ]
}
$catalogues$::jsonb)
ON CONFLICT ("CleInterface") DO NOTHING;
