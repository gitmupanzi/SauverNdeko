# Vues et commentaires PostgreSQL

## Choisir la bonne source

Avant une nouvelle requête, chercher le catalogue dans l’inventaire et les fichiers SQL du domaine. Vérifier définition, grain, clé, date métier, unités, champs de contexte et consommateurs. Un même nom ne suffit pas : V_Mouvement et V_MouvementStock n’ont pas le même rôle ; V_SuiviReglements est une lecture de suivi de facture, pas une écriture unitaire de règlement.

Le catalogue logistique initial comprend V_Article, V_Commande, V_CommandeDetail, V_Mouvement, V_MouvementStock, V_SuiviReglements, V_AuditStock, V_AuditStock_Theorique, V_AlertStock, V_ConsoMensuelle, V_CouvertureStock, V_CommandeOverview et V_CommandesSansDetails.

Pour chaque vue évoluée, documenter :

- sources qualifiées et jointures ;
- grain et clé logique, avec test d’unicité lorsque nécessaire ;
- périmètre organisation/utilisateur et droits imposés par le service ;
- période des flux ou date de situation du stock ;
- formule, unité/devise, gestion des valeurs absentes et exclusions ;
- consommateurs écran/API/export, index utiles et fraîcheur.

Les vues ordinaires lisent les données courantes sans REFRESH. Une vue matérialisée est un cache : ne la choisir que pour un coût mesuré, avec stratégie de rafraîchissement, fraîcheur et invalidation définies. Aucune vue matérialisée applicative n’a été identifiée dans les scripts inspectés.

## Commentaires obligatoires lors des évolutions

Chaque table, vue et colonne métier créée ou modifiée reçoit un commentaire PostgreSQL. Une note dans un fichier Markdown ou un commentaire SQL -- ne remplace pas COMMENT ON. Les objets historiques sans documentation peuvent être repris par lots, sans inventer la sémantique des champs.

Exemple documentaire à adapter à la définition vérifiée, sans l’exécuter automatiquement :

~~~sql
COMMENT ON TABLE logistique."T_Article" IS
  'Article et stock courant officiel. Les lignes de commande produisent les effets de stock ; les mouvements conservent leur historique.';
COMMENT ON COLUMN logistique."T_Article"."QteArticle" IS
  'Quantité courante de cet article, dans son unité de référence. À rapprocher des mouvements ; ne pas la confondre avec une entrée de période.';
COMMENT ON VIEW logistique."V_Commande" IS
  'Lecture de suivi au grain commande : identité, lignes, facturation, règlements et contrôles. Le service impose le périmètre autorisé.';
COMMENT ON COLUMN logistique."V_Commande"."EtatPaiement" IS
  'Qualification calculée par la définition versionnée de V_Commande. Consommée par les listes et leurs détails ; ne pas la recalculer dans React.';
~~~

Écrire des définitions métier précises après vérification des expressions SQL ; éviter « colonne contenant la valeur ». Pour un montant, préciser base HT/TTC, devise et arrondi quand connus. Pour une date, distinguer date métier, horodatage automatique et échéance. Ne pas affirmer une devise ou un filtrage inexistant.

Commenter aussi les fonctions/procédures modifiées avec leur signature qualifiée, leurs paramètres et leurs effets. Conserver les commentaires existants utiles ; ne pas ajouter d’informations personnelles ou d’accès.

## Inspection de recette, en lecture seule

Ce relevé n’a pas interrogé PostgreSQL. Pour une future inspection autorisée, utiliser une transaction de lecture seule et les catalogues PostgreSQL. Exemples sans contenu client :

~~~sql
BEGIN READ ONLY;
SELECT n.nspname AS schema_name, c.relname AS object_name,
       c.relkind, obj_description(c.oid, 'pg_class') AS comment
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('analytics', 'communication', 'geolocalisation',
  'logistique', 'operations', 'professionnel', 'referentiel', 'systeme')
  AND c.relkind IN ('r', 'p', 'v', 'm')
ORDER BY 1, 2;

SELECT n.nspname AS schema_name, c.relname AS object_name,
       a.attname AS column_name,
       col_description(c.oid, a.attnum) AS comment
FROM pg_attribute a
JOIN pg_class c ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'logistique'
  AND c.relkind IN ('r', 'p', 'v', 'm')
  AND a.attnum > 0 AND NOT a.attisdropped
ORDER BY 1, 2, a.attnum;

SELECT pg_get_viewdef('logistique."V_Commande"'::regclass, true);
ROLLBACK;
~~~

L’existence d’un commentaire ne prouve ni sa justesse ni l’isolation des lignes. Comparer aux sources et aux requêtes des consommateurs.

## Évolution contrôlée

Préparer un script daté/ordonné sous le domaine SQL concerné ou une organisation de migrations établie explicitement. Définir son état préalable, les dépendances, les commentaires, les contrôles et un retour arrière adapté. Ne pas supposer qu’un CREATE OR REPLACE VIEW permet tous les changements de type/ordre de colonnes.

Préserver les noms existants et les colonnes consommées ; tester les projections avant/après sur recette, sans DROP CASCADE ni reset de données. Si une définition est répétée dans un script canonique et une migration historique, comprendre l’ordre de livraison avant consolidation.

## Parité et performance

Pour un KPI, définir un seul prédicat serveur pour agrégat, détail et export. Comparer effectifs, sommes, filtres, droits et cas absents, avec un jeu dépassant la limite de page. Prévoir une version/date de calcul si des écritures entre deux requêtes pourraient rendre les résultats incomparables.

Mesurer les plans PostgreSQL et les temps API sur un périmètre représentatif. EXPLAIN ANALYZE exécute la requête : l’utiliser pour SELECT sur recette avec une durée bornée et éviter les fonctions à effets de bord. Un index nouveau, une vue supplémentaire ou un cache demande un besoin démontré ; ne pas recopier une vue par écran React.


## Commentaires appliqués en base — 24 octobre 2026

Les huit schémas applicatifs de la base locale SauverNdeko possèdent désormais 1553 commentaires couvrant tables, vues, colonnes, fonctions/procédures, triggers, séquences, contraintes et index. Application, réexécution et retour arrière vérifiés sur une copie isolée sans données ; les textes sont vérifiés après commit dans la base locale et les définitions restent inchangées.

Lire le [bilan et les précisions sur le catalogue installé](../../../../SQL/documentation/Commentaires_PostgreSQL_20261024.md). La [migration de référence](../../../../SQL/migrations/20261024_01_commentaires_objets_postgresql.sql) documente les objets existants ; pour un objet nouveau ou modifié, adapter son commentaire dans une nouvelle évolution versionnée. Les inspections décrites plus haut restent le modèle des futures interventions.


## Fiabilisation logistique — évolution 20261024_02

La migration 02 est appliquée à la base locale : verrouillage des parents, totaux par instruction, clôture normalisée, alertes sans seuil, couverture sans jours futurs et audit SQL filtrable. Les données existantes sont inchangées ; les contrôles ont été exécutés sur une base de recette fictive. Les deux nouvelles fonctions et le remplacement d’un trigger par quatre portent la couverture globale à 1558 objets/colonnes commentés (27 fonctions, six procédures, 27 triggers ; autres familles inchangées).

Consulter le [bilan de fiabilisation](../../../../SQL/documentation/Logistique_Fiabilisation_20261024.md). Les écarts de droits API, d’isolation et de calculs du dashboard frontend restent ouverts.

## Audit métier et sources canoniques après la migration 04

Le propriétaire a autorisé l’amélioration des schémas métier. La base comporte maintenant 31 tables métier et 48 vues ; les neuf schémas, public inclus, portent 1 893 commentaires sans manque. Les stocks appliquent des deltas nets par article ; ne pas réintroduire une annulation intermédiaire qui rendrait artificiellement le stock négatif. Les agrégats géographiques incluent les sites directement rattachés au niveau 3. Les vues publiques excluent les données privées et les réponses JSON des curseurs bruts sont décodées avant nettoyage.

Lire le [bilan et les limites](../../../../SQL/documentation/Audit_Metier_20261024.md) puis le [guide SQL](../../../../SQL/README.md). Les snapshots canoniques sont destinés aux bases vides ; une base existante reçoit uniquement une migration contrôlée. Les migrations historiques 01 à 03 ne doivent pas être rejouées après la version 04 sans examen de leurs effets.


## Politique de précision des quantités — contrat 20261026_10

Lire `logistique.V_PrecisionStock` pour la précision d’une unité. `logistique.T_PrecisionStock` contient uniquement ID_PrecisionStock, ID_UniteFk, DecimalesStock et ModifieLe ; sa FK désigne la même valeur Unités de referentiel.T_Generique que l’article. Les libellés et abréviations restent dans le référentiel ; aucune précision logistique n’y est dupliquée. Vérifier la migration installée avant d’employer ce contrat.

Le défaut d’une nouvelle unité non configurée est zéro décimale. Le réglage partagé est réservé à l’administrateur global et ne change aucun stock. Les protections PostgreSQL conservent identité, catégorie et historique ; les contrôles de quantité et de configuration verrouillent la même unité. Conserver l’alias API Decimales et l’audit avant/après, y compris la date et l’identité de politique. Ne pas réécrire les migrations historiques qui portaient ce réglage dans le référentiel.
