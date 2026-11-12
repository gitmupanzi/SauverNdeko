-- Rattachement manquant du type de site au référentiel physique.
-- Inspection du 30/10 : les 21 949 références de sites, 28 valeurs distinctes,
-- appartiennent toutes à la famille « Type de site » ; aucun ID orphelin.
-- Le défaut se déduit du champ Type d'aire déjà catalogué. Aucun ID de famille
-- n'est codé ici. L'ancienne correspondance niveau5Types reste lue par alias.
-- Ni donnée géographique ni réglage existant n'est réécrit.
BEGIN;
SET LOCAL lock_timeout='3s';
SET LOCAL statement_timeout='30s';
SELECT pg_advisory_xact_lock(hashtextextended('geolocalisation:hierarchy-writes',0));

DO $migration$
DECLARE family integer;
BEGIN
 SELECT "ID_CategorieDefautFk" INTO family FROM referentiel."T_ChampReferentiel"
 WHERE "SchemaName"='geolocalisation' AND "TableName"='T_Niveau_4' AND "ColumnName"='ID_TypeNiveau_4_Fk';
 IF family IS NULL THEN RAISE EXCEPTION 'Le défaut prouvé du type d''aire est indisponible ; migration interrompue.'; END IF;
 IF EXISTS(SELECT 1 FROM geolocalisation."T_Niveau_5" n LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=n."ID_TypeNiveau_5_Fk"
           WHERE n."ID_TypeNiveau_5_Fk" IS NOT NULL AND g."ID_Generique" IS NULL) THEN
   RAISE EXCEPTION 'Des types de sites sont orphelins ; migration interrompue sans réécriture.';
 END IF;
 -- Cette preuve est nécessaire lors de l'installation initiale du champ.
 -- Un rejeu ne contredit pas un changement ultérieur légitime de catégorie.
 IF NOT EXISTS(SELECT 1 FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"='geolocalisation'
               AND "TableName"='T_Niveau_5' AND "ColumnName"='ID_TypeNiveau_5_Fk') AND EXISTS(
    SELECT 1 FROM geolocalisation."T_Niveau_5" n JOIN referentiel."T_Generique" g ON g."ID_Generique"=n."ID_TypeNiveau_5_Fk"
    WHERE g."ID_CategorieGeneriqueFk" IS DISTINCT FROM family) THEN
   RAISE EXCEPTION 'Les familles historiques des types de sites ne sont pas unanimes ; intervention requise.';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint c JOIN pg_attribute a ON a.attrelid=c.conrelid AND a.attnum=c.conkey[1]
               JOIN pg_attribute b ON b.attrelid=c.confrelid AND b.attnum=c.confkey[1]
               WHERE c.contype='f' AND c.conrelid='geolocalisation."T_Niveau_5"'::regclass
               AND c.confrelid='referentiel."T_Generique"'::regclass AND cardinality(c.conkey)=1
               AND a.attname='ID_TypeNiveau_5_Fk' AND b.attname='ID_Generique') THEN
   ALTER TABLE geolocalisation."T_Niveau_5" ADD CONSTRAINT "Fk_TypeNiveau_5_Generique"
     FOREIGN KEY("ID_TypeNiveau_5_Fk") REFERENCES referentiel."T_Generique"("ID_Generique") NOT VALID;
 END IF;
 IF EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='geolocalisation."T_Niveau_5"'::regclass
           AND conname='Fk_TypeNiveau_5_Generique' AND NOT convalidated) THEN
   ALTER TABLE geolocalisation."T_Niveau_5" VALIDATE CONSTRAINT "Fk_TypeNiveau_5_Generique";
 END IF;
 INSERT INTO referentiel."T_ChampReferentiel"("SchemaName","TableName","ColumnName","ChampLabel","ModuleName",
      "ID_CategorieDefautFk","AliasSourceKeys","CanConfigure","SupportsEntityScope")
 VALUES('geolocalisation','T_Niveau_5','ID_TypeNiveau_5_Fk','Type de structure ou site','geolocalisation',family,
        ARRAY['niveau5Types']::text[],true,false)
 ON CONFLICT("SchemaName","TableName","ColumnName") DO NOTHING;
END
$migration$;

CREATE INDEX IF NOT EXISTS ix_niveau5_type_reference ON geolocalisation."T_Niveau_5"("ID_TypeNiveau_5_Fk");
COMMENT ON INDEX geolocalisation.ix_niveau5_type_reference IS 'Recherche, filtrage et contrôle des sites par valeur du référentiel partagé.';
COMMENT ON COLUMN geolocalisation."T_Niveau_5"."ID_TypeNiveau_5_Fk" IS 'Type de structure ou site : identifiant de T_Generique. La famille des nouveaux choix est résolue par le référencement physique commun ; les valeurs historiques inchangées sont conservées.';
DO $comment$
DECLARE cname text;
BEGIN
 FOR cname IN SELECT c.conname FROM pg_constraint c JOIN pg_attribute a ON a.attrelid=c.conrelid AND a.attnum=c.conkey[1]
   WHERE c.contype='f' AND c.conrelid='geolocalisation."T_Niveau_5"'::regclass AND c.confrelid='referentiel."T_Generique"'::regclass
   AND cardinality(c.conkey)=1 AND a.attname='ID_TypeNiveau_5_Fk'
 LOOP
  EXECUTE format('COMMENT ON CONSTRAINT %I ON geolocalisation."T_Niveau_5" IS %L',cname,
    'Référence physique du type de site vers T_Generique, contrôlée sans réaffectation des sites existants.');
 END LOOP;
END
$comment$;
COMMIT;
