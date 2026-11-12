-- Annuaire des offres volontairement publiées : enrichissement en lecture seule.
-- Aucun stock, prix, lot, choix de publication ou droit applicatif n'est modifié.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='120s';
DO $$ BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN
  RAISE EXCEPTION 'Base non autorisée';
 END IF;
 IF to_regclass('logistique."V_OffreArticle"') IS NULL
    OR to_regclass('systeme."V_Entite_Localisation_Detail"') IS NULL THEN
  RAISE EXCEPTION 'Publication des articles et localisations déclarées requises.';
 END IF;
END $$;

-- Les quatorze premières colonnes et le périmètre de publication restent
-- identiques à 20261103_01. Les nouvelles clés servent uniquement aux filtres.
CREATE OR REPLACE VIEW logistique."V_OffreArticle" AS
 SELECT a."ID_Article",a."NomArticle",a."RefArticle",a."PVArticle",a."ID_DeviseFk",
        logistique.fn_code_devise(d."AbrGenerique"::text) AS "DeviseCode",
        d."NomGenerique"::text AS "DeviseLibelle",
        coalesce(nullif(u."AbrGenerique",''),u."NomGenerique")::text AS "Unite",
        CASE WHEN a."QteArticle">0 THEN 'Stock déclaré' ELSE 'Stock nul déclaré' END::text AS "EtatDisponibilite",
        a."PhotoArticle",e."IdEntite",e."NomEntite",e."AdresseEntite",e."PhoneEntite",
        a."ID_CategorieArticleFk",
        coalesce(nullif(c."AbrGenerique",''),c."NomGenerique")::text AS "CategorieArticle",
        a."ID_TypeArticleFk",
        coalesce(nullif(t."AbrGenerique",''),t."NomGenerique")::text AS "TypeArticle"
 FROM logistique."T_Article" a
 JOIN systeme."T_Entite" e ON e."IdEntite"=a."IdEntiteFk"
 LEFT JOIN referentiel."T_Generique" d ON d."ID_Generique"=a."ID_DeviseFk"
 LEFT JOIN referentiel."T_Generique" u ON u."ID_Generique"=a."ID_UniteFk"
 LEFT JOIN referentiel."T_Generique" c ON c."ID_Generique"=a."ID_CategorieArticleFk"
 LEFT JOIN referentiel."T_Generique" t ON t."ID_Generique"=a."ID_TypeArticleFk"
 WHERE a."VisibleCatalogue" IS TRUE AND a."ValideArticle" IS TRUE AND e."ValideEntite" IS TRUE;
COMMENT ON VIEW logistique."V_OffreArticle" IS 'Offres locales volontairement publiées d’articles actifs et d’entreprises actives. Grain article local ; catégories et types proviennent des valeurs centrales déjà enregistrées, sans réécriture des anciennes FK. Exclut coût d’achat, quantités exactes, notes et auteur. Stock déclaré ne garantit ni disponibilité vendable ni fraîcheur. Les API conservent authentification, licences et permissions ; aucun classement implicite entre devises ou unités ni collecte de recherche.';
COMMENT ON COLUMN logistique."V_OffreArticle"."ID_CategorieArticleFk" IS 'Valeur centrale de catégorie déjà enregistrée sur l’article, destinée au filtre exact de l’annuaire ; aucune famille codée en dur.';
COMMENT ON COLUMN logistique."V_OffreArticle"."CategorieArticle" IS 'Abréviation courante de la catégorie centrale enregistrée, ou son nom si l’abréviation est absente. Ne normalise pas les produits entre entreprises.';
COMMENT ON COLUMN logistique."V_OffreArticle"."ID_TypeArticleFk" IS 'Valeur centrale de type déjà enregistrée sur l’article, destinée au filtre exact de l’annuaire ; aucune famille codée en dur.';
COMMENT ON COLUMN logistique."V_OffreArticle"."TypeArticle" IS 'Abréviation courante du type central enregistré, ou son nom si l’abréviation est absente. Ne constitue pas une qualification thérapeutique vérifiée.';

CREATE OR REPLACE VIEW logistique."V_OffreArticleLocalisation" AS
 SELECT o."ID_Article",
        coalesce(nullif(l."NomNiveau_5",''),nullif(l."NomNiveau_4",''),
                 nullif(l."NomNiveau_3",''),nullif(l."AdresseDetaillee",''))::text AS label,
        nullif(l."AdresseDetaillee",'')::text AS address,
        nullif(l."NomNiveau_3",'')::text AS zone,
        nullif(l."NomNiveau_4",'')::text AS area,
        nullif(l."NomNiveau_5",'')::text AS site
 FROM logistique."V_OffreArticle" o
 JOIN systeme."V_Entite_Localisation_Detail" l ON l."IdEntite"=o."IdEntite"
 WHERE l."IdEntiteLocalisation" IS NOT NULL
   AND coalesce(nullif(l."NomNiveau_5",''),nullif(l."NomNiveau_4",''),
                nullif(l."NomNiveau_3",''),nullif(l."AdresseDetaillee",'')) IS NOT NULL;
COMMENT ON VIEW logistique."V_OffreArticleLocalisation" IS 'Localisations professionnelles déclarées de l’entreprise d’une offre actuellement publiée. Grain article/localisation existante ; une offre sans localisation ne produit aucune ligne. Liste fermée de libellés et adresse, sans latitude, longitude, identifiant de point, auteur ou historique. Aucune distance, présence physique du stock sur ce site ou correspondance territoriale internationale n’est déduite.';
COMMENT ON COLUMN logistique."V_OffreArticleLocalisation"."ID_Article" IS 'Offre publiée dont l’entreprise porte la localisation. Le retrait de publication retire immédiatement cette projection.';
COMMENT ON COLUMN logistique."V_OffreArticleLocalisation".label IS 'Libellé déclaré le plus précis : niveau 5, sinon 4, sinon 3, sinon adresse détaillée. Aucune localisation automatique.';
COMMENT ON COLUMN logistique."V_OffreArticleLocalisation".address IS 'Adresse détaillée volontairement enregistrée sur ce point professionnel, sans coordonnée personnelle de l’auteur.';
COMMENT ON COLUMN logistique."V_OffreArticleLocalisation".zone IS 'Nom du niveau 3 explicitement rattaché au point ; aucune parenté non renseignée n’est inventée.';
COMMENT ON COLUMN logistique."V_OffreArticleLocalisation".area IS 'Nom du niveau 4 explicitement rattaché au point ; aucune parenté non renseignée n’est inventée.';
COMMENT ON COLUMN logistique."V_OffreArticleLocalisation".site IS 'Nom du niveau 5 explicitement rattaché au point, sans garantie de disponibilité de l’article sur ce site.';
COMMIT;
