-- Choix explicite de publication des articles, sans ouverture anonyme des API.
-- Les données historiques restent privées ; aucun stock, lot ou prix n'est modifié.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='120s';
DO $$ BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN
  RAISE EXCEPTION 'Base non autorisée';
 END IF;
 IF to_regclass('logistique."V_Article"') IS NULL OR to_regclass('systeme."T_Entite"') IS NULL THEN
  RAISE EXCEPTION 'Socle ERP Logistique requis.';
 END IF;
END $$;

-- Un défaut constant renseigne les anciennes lignes sans UPDATE métier : les
-- triggers de mouvements, de stock initial et d'audit ne sont pas sollicités.
ALTER TABLE systeme."T_Entite" ADD COLUMN IF NOT EXISTS "PartageArticlesPublicParDefaut" boolean NOT NULL DEFAULT true;
ALTER TABLE logistique."T_Article" ADD COLUMN IF NOT EXISTS "VisibleCatalogue" boolean NOT NULL DEFAULT false;
-- Le seul défaut des nouvelles lignes est déterminé par leur propriétaire.
-- NULL est le marqueur d'une valeur non fournie avant la garde BEFORE INSERT.
ALTER TABLE logistique."T_Article" ALTER COLUMN "VisibleCatalogue" DROP DEFAULT;

COMMENT ON COLUMN systeme."T_Entite"."PartageArticlesPublicParDefaut" IS 'Choix proposé uniquement à la création d’un nouvel article de cette entreprise. Vrai par défaut ; une modification ne republie ni ne retire aucun article existant. Ne donne aucun droit de lecture anonyme.';
COMMENT ON COLUMN logistique."T_Article"."VisibleCatalogue" IS 'Publication volontaire dans le catalogue partagé autorisé. Faux pour les articles antérieurs à 20261103_01. À la création, une valeur omise hérite du choix de l’entreprise ; un choix explicite le remplace. L’activité du propriétaire et de l’article reste obligatoire. Ce drapeau n’atteste ni disponibilité vendable ni fraîcheur du stock.';

CREATE OR REPLACE FUNCTION logistique.tr_publication_article_defaut() RETURNS trigger
 LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 IF NEW."VisibleCatalogue" IS NULL THEN
  SELECT e."PartageArticlesPublicParDefaut" INTO NEW."VisibleCatalogue"
  FROM systeme."T_Entite" e WHERE e."IdEntite"=NEW."IdEntiteFk";
  IF NOT FOUND THEN
   RAISE EXCEPTION 'Entreprise propriétaire introuvable pour le choix de publication.' USING ERRCODE='23503';
  END IF;
 END IF;
 RETURN NEW;
END $$;
COMMENT ON FUNCTION logistique.tr_publication_article_defaut() IS 'Détermine uniquement le choix de publication omis lors d’un INSERT après la garde de propriété. Conserve tout booléen explicite, ne touche aucun stock, lot, mouvement, prix ou enregistrement existant.';
DROP TRIGGER IF EXISTS ab_publication_article ON logistique."T_Article";
CREATE TRIGGER ab_publication_article BEFORE INSERT ON logistique."T_Article"
 FOR EACH ROW EXECUTE FUNCTION logistique.tr_publication_article_defaut();
COMMENT ON TRIGGER ab_publication_article ON logistique."T_Article" IS 'Héritage du choix de publication après les gardes aa_* de propriété/référence et avant les contrôles de stock. Aucun effet sur une mise à jour du défaut de l’entreprise.';

-- Ajouter le champ en dernière position conserve noms, types et ordre des
-- colonnes déjà utilisées par les autres vues et les registres logistiques.
DO $$ DECLARE definition text; BEGIN
 IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='logistique' AND table_name='V_Article' AND column_name='VisibleCatalogue') THEN
  SELECT rtrim(pg_get_viewdef('logistique."V_Article"'::regclass,true),E';\n\r ') INTO definition;
  EXECUTE 'CREATE OR REPLACE VIEW logistique."V_Article" AS SELECT source_publication.*,article_publication."VisibleCatalogue" FROM ('||definition||') source_publication JOIN logistique."T_Article" article_publication ON article_publication."ID_Article"=source_publication."ID_Article"';
 END IF;
END $$;
COMMENT ON COLUMN logistique."V_Article"."VisibleCatalogue" IS 'Choix de publication du catalogue partagé porté par l’article ; affichable et modifiable selon les droits du propriétaire. Les autres colonnes de gestion conservent leur contrat et leur ordre.';

CREATE OR REPLACE VIEW logistique."V_OffreArticle" AS
 SELECT a."ID_Article",a."NomArticle",a."RefArticle",a."PVArticle",a."ID_DeviseFk",
        logistique.fn_code_devise(d."AbrGenerique"::text) AS "DeviseCode",
        d."NomGenerique"::text AS "DeviseLibelle",
        coalesce(nullif(u."AbrGenerique",''),u."NomGenerique")::text AS "Unite",
        CASE WHEN a."QteArticle">0 THEN 'Stock déclaré' ELSE 'Stock nul déclaré' END::text AS "EtatDisponibilite",
        a."PhotoArticle",e."IdEntite",e."NomEntite",e."AdresseEntite",e."PhoneEntite"
 FROM logistique."T_Article" a
 JOIN systeme."T_Entite" e ON e."IdEntite"=a."IdEntiteFk"
 LEFT JOIN referentiel."T_Generique" d ON d."ID_Generique"=a."ID_DeviseFk"
 LEFT JOIN referentiel."T_Generique" u ON u."ID_Generique"=a."ID_UniteFk"
 WHERE a."VisibleCatalogue" IS TRUE AND a."ValideArticle" IS TRUE AND e."ValideEntite" IS TRUE;
COMMENT ON VIEW logistique."V_OffreArticle" IS 'Projection minimale des seuls articles publiés et actifs de propriétaires actifs, au grain article local. Le choix par défaut du propriétaire ne filtre jamais les décisions individuelles existantes. Exclut coût d’achat, quantités exactes, notes, informations internes et compte auteur. Stock déclaré n’atteste ni disponibilité vendable, péremption vérifiée ni heure de confirmation. Les API conservent authentification, permissions et licences ; aucune collecte de recherche n’est activée.';
COMMENT ON COLUMN logistique."V_OffreArticle"."ID_Article" IS 'Identifiant de l’article local publié, clé du grain de l’offre ; ne constitue pas encore un produit normalisé entre entreprises.';
COMMENT ON COLUMN logistique."V_OffreArticle"."NomArticle" IS 'Désignation courante déclarée par l’entreprise propriétaire.';
COMMENT ON COLUMN logistique."V_OffreArticle"."RefArticle" IS 'Référence externe facultative de l’article publiée avec son choix individuel.';
COMMENT ON COLUMN logistique."V_OffreArticle"."PVArticle" IS 'Prix de vente déclaré, associé à la devise de la même ligne ; aucun coût d’achat n’est exposé.';
COMMENT ON COLUMN logistique."V_OffreArticle"."ID_DeviseFk" IS 'Identifiant de la devise centrale stockée sur l’article ; aucun taux ni conversion implicite.';
COMMENT ON COLUMN logistique."V_OffreArticle"."DeviseCode" IS 'Code monétaire normalisé par la fonction logistique existante à partir du référentiel.';
COMMENT ON COLUMN logistique."V_OffreArticle"."DeviseLibelle" IS 'Libellé courant de la devise centrale, sans valeur de remplacement inventée.';
COMMENT ON COLUMN logistique."V_OffreArticle"."Unite" IS 'Abréviation courante de l’unité centrale, ou son libellé si l’abréviation est absente.';
COMMENT ON COLUMN logistique."V_OffreArticle"."EtatDisponibilite" IS 'Indication prudente de stock déclaré positif ou nul ; ne garantit ni stock réellement vendable ni qualité/péremption des lots et ne fournit aucune date de fraîcheur fictive.';
COMMENT ON COLUMN logistique."V_OffreArticle"."PhotoArticle" IS 'Référence privée de la photo ; le service transforme la valeur en route contrôlée par cette même publication, jamais en chemin de téléchargement public.';
COMMENT ON COLUMN logistique."V_OffreArticle"."IdEntite" IS 'Identifiant durable de l’entreprise propriétaire de l’offre.';
COMMENT ON COLUMN logistique."V_OffreArticle"."NomEntite" IS 'Nom courant de l’entreprise propriétaire publié avec l’offre.';
COMMENT ON COLUMN logistique."V_OffreArticle"."AdresseEntite" IS 'Adresse de structure déclarée dans la fiche entreprise ; aucune localisation ne se déduit d’un compte utilisateur.';
COMMENT ON COLUMN logistique."V_OffreArticle"."PhoneEntite" IS 'Téléphone de structure déclaré, distinct des coordonnées personnelles de l’auteur.';
COMMIT;
