-- Registre transversal des lots : lectures communes, aucune écriture de stock.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';
CREATE OR REPLACE VIEW logistique."V_RegistreLots" AS
SELECT l.*, a."CodeArticleInterne", a."RefArticle", a."PhotoArticle",
 a."ID_CategorieArticleFk", cat."NomGenerique" AS "CategorieArticle",
 a."ID_TypeArticleFk", typ."NomGenerique" AS "TypeArticle",
 a."ValideArticle", a."QteArticle" AS "StockArticle", l."Unite" AS "AbrUnite",
 e."NomEntite",
 CASE WHEN l."StockLot"<0 THEN 'Stock négatif' WHEN l."StockLot"=0 THEN 'Épuisé' ELSE 'Disponible' END AS "EtatStockLot"
FROM logistique."V_LotDisponibilite" l
JOIN logistique."T_Article" a ON a."ID_Article"=l."ID_ArticleFk"
LEFT JOIN referentiel."T_Generique" cat ON cat."ID_Generique"=a."ID_CategorieArticleFk"
LEFT JOIN referentiel."T_Generique" typ ON typ."ID_Generique"=a."ID_TypeArticleFk"
LEFT JOIN systeme."T_Entite" e ON e."IdEntite"=l."IdEntiteFk";
COMMENT ON VIEW logistique."V_RegistreLots" IS 'Registre de tous les lots, y compris épuisés ou archivés. Solde réel, péremption en date métier Kinshasa, unité de stock et propriétaire durable de l’article. Source commune écran, fiche et export ; aucun effet de stock.';
CREATE OR REPLACE VIEW logistique."V_RegistreMouvementLot" AS
SELECT l.*, a."IdEntiteFk", a."CodeArticleInterne", a."RefArticle",
 u."AbrGenerique" AS "AbrUnite", u."AbrGenerique" AS "Unite",
 t."NomGenerique" AS "NomTypeMvt",
 CASE WHEN l."SigneStock"=1 THEN 'Entrée' WHEN l."SigneStock"=-1 THEN 'Sortie' ELSE 'Sans effet' END AS "SensMouvement"
FROM logistique."V_MouvementLot" l
JOIN logistique."T_Article" a ON a."ID_Article"=l."ID_ArticleFk"
JOIN logistique."T_Mouvement" m ON m."ID_Mvt"=l."ID_MvtFk"
LEFT JOIN referentiel."T_Generique" u ON u."ID_Generique"=a."ID_UniteFk"
LEFT JOIN referentiel."T_Generique" t ON t."ID_Generique"=m."ID_TypeMvtFk";
COMMENT ON VIEW logistique."V_RegistreMouvementLot" IS 'Journal des ventilations de mouvements par lot avec quantité, signe, unité et entreprise. Une ligne par mouvement et lot ; consulter et exporter en filtrant ID_LotArticleFk. Les mouvements d’origine et leurs compensations restent distincts.';
DO $comments$
DECLARE item record; description text;
BEGIN
 FOR item IN SELECT table_name,column_name FROM information_schema.columns WHERE table_schema='logistique' AND table_name IN ('V_RegistreLots','V_RegistreMouvementLot') LOOP
 description:=CASE item.column_name
 WHEN 'ID_LotArticle' THEN 'Identifiant interne unique du lot dans le registre.'
 WHEN 'ID_LotArticleFk' THEN 'Lot dont cette écriture ventile une partie du mouvement.'
 WHEN 'ID_ArticleFk' THEN 'Article auquel appartient exclusivement le lot.'
 WHEN 'NumeroLot' THEN 'Numéro de lot du produit, conservé en texte.'
 WHEN 'DatePeremptionLot' THEN 'Date civile de péremption propre au lot ; une absence reste inconnue.'
 WHEN 'Actif' THEN 'Lot actif. Un lot archivé reste visible et ses mouvements sont conservés.'
 WHEN 'CreeLe' THEN 'Horodatage de création du lot.'
 WHEN 'StockLot' THEN 'Solde réel du lot : entrées moins sorties dans son unité de stock.'
 WHEN 'QuantiteEntree' THEN 'Quantité cumulée des entrées ventilées sur ce lot, dans son unité.'
 WHEN 'QuantiteSortie' THEN 'Quantité cumulée des sorties ventilées sur ce lot, dans son unité.'
 WHEN 'IdEntiteFk' THEN 'Entreprise propriétaire durable de l’article ; clé du périmètre de consultation.'
 WHEN 'NomEntite' THEN 'Nom de l’entreprise propriétaire de l’article.'
 WHEN 'NomArticle' THEN 'Désignation actuelle de l’article du lot.'
 WHEN 'Unite' THEN 'Abréviation de l’unité de stock associée aux quantités du lot ou de son mouvement.'
 WHEN 'AbrUnite' THEN 'Abréviation de l’unité de stock, exportée avec toute quantité.'
 WHEN 'ID_UniteFk' THEN 'Unité de stock définie dans le référentiel générique.'
 WHEN 'ID_DeviseFk' THEN 'Devise de référence du mouvement ou de l’article ; aucun total entre devises.'
 WHEN 'DeviseCode' THEN 'Code de la devise de référence.'
 WHEN 'DeviseLibelle' THEN 'Libellé de la devise de référence.'
 WHEN 'EtatPeremptionLot' THEN 'Conservation du lot selon sa date et le seuil article ou entreprise ; indépendante du solde.'
 WHEN 'EstPerime' THEN 'Date du lot antérieure au jour métier Africa/Kinshasa ; inclut les lots épuisés dans ce registre historique.'
 WHEN 'EstProche' THEN 'Date du lot entre le jour métier et le seuil d’alerte inclus.'
 WHEN 'SeuilAlerteJours' THEN 'Délai d’alerte effectif en jours : article, sinon entreprise, sinon 30.'
 WHEN 'BloquerLotsPerimes' THEN 'Politique de blocage des sorties de lots périmés pour cette entreprise.'
 WHEN 'CodeArticleInterne' THEN 'Code interne actuel de l’article.'
 WHEN 'RefArticle' THEN 'Référence actuelle de l’article.'
 WHEN 'PhotoArticle' THEN 'Photo actuelle de l’article.'
 WHEN 'ID_CategorieArticleFk' THEN 'Catégorie d’article dans le référentiel générique.'
 WHEN 'CategorieArticle' THEN 'Libellé de la catégorie d’article.'
 WHEN 'ID_TypeArticleFk' THEN 'Type d’article dans le référentiel générique.'
 WHEN 'TypeArticle' THEN 'Libellé du type d’article.'
 WHEN 'ValideArticle' THEN 'État actif de l’article. Ne modifie pas le solde historique du lot.'
 WHEN 'StockArticle' THEN 'Stock courant total de l’article, lots et stock sans lot compris ; non sommable entre unités.'
 WHEN 'EtatStockLot' THEN 'État du solde du lot : Disponible, Épuisé ou Stock négatif.'
 WHEN 'ID_MvtFk' THEN 'Identifiant du mouvement source de cette ventilation de lot.'
 WHEN 'Quantite' THEN 'Quantité absolue de cette ventilation, dans l’unité de stock de l’article.'
 WHEN 'DateMvt' THEN 'Date et heure métier du mouvement source.'
 WHEN 'ID_cmdFk' THEN 'Bon de stock source, si présent.'
 WHEN 'SigneStock' THEN 'Effet de stock de la ventilation : 1 entrée, -1 sortie, 0 neutre.'
 WHEN 'QuantiteSignee' THEN 'Quantité de ventilation multipliée par son signe de stock.'
 WHEN 'CodeCmd' THEN 'Code automatique du bon source, si présent.'
 WHEN 'MotifDerogationPeremption' THEN 'Motif obligatoire d’une dérogation autorisée au blocage des lots périmés.'
 WHEN 'ID_DerogationUserFk' THEN 'Administrateur global ayant autorisé la dérogation de péremption.'
 WHEN 'DateDerogationPeremption' THEN 'Horodatage de l’autorisation de dérogation.'
 WHEN 'NomTypeMvt' THEN 'Type du mouvement source issu du référentiel générique.'
 WHEN 'SensMouvement' THEN 'Sens lisible de l’écriture, dérivé du signe de stock.'
 ELSE 'Donnée de traçabilité issue de la source commune des lots.' END;
 EXECUTE format('COMMENT ON COLUMN logistique.%I.%I IS %L',item.table_name,item.column_name,description);
 END LOOP;
END $comments$;
COMMIT;
