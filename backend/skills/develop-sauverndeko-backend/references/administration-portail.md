# Portail d’administration — 26 octobre 2026

`apps/core/admin_portal.py` réutilise les vues du schéma `systeme` et le référentiel des rôles. Il ne crée ni objet SQL ni copie des données. Le champ `Role` et sa clé `IdRoleFk` sont une projection fermée de `V_User_profil`, jointe à l’utilisateur et au libellé de référence, avant recherche, filtres, tri et pagination. Aucun mot de passe n’est sélectionné par cette projection.

## Contrats de lecture

- `GET /api/systeme/administration/synthese` calcule les effectifs réels, la répartition des utilisateurs par rôle, sept jours d’événements et les licences actives proches de leur terme. Ne pas remplacer une source indisponible par zéro. Les indicateurs réservés à la plateforme valent `null` pour un gestionnaire local et figurent dans `unavailable`.
- `GET /api/systeme/administration/registres/{kind}` et `/{id}` proposent les listes et la consultation exacte par clé stable.
- `GET /api/systeme/administration/registres/{kind}/export.xlsx` utilise le même objet autorisé et le même prédicat que la liste. L’export couvre tous les résultats filtrés ; `take` et `skip` ne le limitent pas. Les colonnes, tris et types de registre sont fermés côté serveur.

Les types de registre sont `utilisateurs`, `profils`, `entites`, `roles`, `audit`, `correspondances`, `localisations`, `licences`, `connexions`, `parametres` et `audit-parametres`. Les paramètres acceptés sont `q`, `filters` JSON, `sortBy`, `sortDir`, `take`, `skip`, `dateFrom`, `dateTo`, `timeZone` et `columns` pour l’export.

Les filtres de date ciblent la vraie colonne de l’événement. Les horodatages sans fuseau conservent leur heure civile ; les horodatages avec fuseau bornent la journée dans le fuseau demandé. La fin de période est exclusive au début du lendemain. Une date inversée, un tri inconnu ou un filtre sensible est refusé.

## Droits, portée et identités

`IsERPAdmin` et le module `administration` contrôlent chaque lecture et export. Audit, correspondances, connexions et paramètres de plateforme sont réservés au compte global ; leur portée reste celle de la plateforme même lorsqu’il vient d’un module d’entreprise. Utilisateurs, entreprises, licences et localisations conservent le périmètre autorisé de l’entreprise.

Le registre Rôles impose la catégorie 39 avant tout filtre. `V_Entite_Localisation_Detail` contient aussi des entreprises sans point par son LEFT JOIN : le registre des localisations exclut les identifiants de localisation NULL. Il ne remplace jamais `IdEntiteLocalisation` par `IdEntite`.

Les GET d’édition utilisateurs et licences rechargent les tables protégées, nettoyées des secrets, car leurs vues d’affichage ne contiennent pas toutes les clés du formulaire. Les écritures gardent les services existants ; ce portail de lecture n’accorde aucun droit supplémentaire.

## Secrets et paramètres protégés

Le nettoyage du dépôt masque récursivement les mots de passe, jetons, clés et secrets, y compris dans les objets JSON historiques parfois doublement encodés. Un `SettingKey` sensible masque `SettingValue` et `SettingValueJson`. Ce masquage s’applique aussi à l’Excel lorsque la clé n’est pas une colonne visible. Ces valeurs ne sont pas utilisables comme oracle de recherche, filtre ou tri.

Le GET de paramètre expose `meta.sensitive` pour conserver sa fiche en consultation. Une valeur sensible se configure dans le paramétrage privé du serveur. Les lignes `IsEditable=false` restent protégées ; un paramètre système ne peut pas être supprimé ni perdre son identité ou ses protections par la route générique. Les mutations éventuelles de recette ne visent jamais les comptes ou réglages réels.

`/api/systeme/admin-ui-settings` conserve son ancien contrat FK en GET/PUT et son POST de création de paramètre. Son historique `/audit` reste l’historique FK pour la compatibilité des réglages de référence. L’onglet moderne d’historique des paramètres utilise `audit-parametres`, adossé à `V_Admin_UI_Setting_Audit`.

## Recette

`SQL/tests/test_admin_portal.py` teste les contrats avec des mocks et sans écritures PostgreSQL. Le diagnostic privé `.runtime/verify_admin_portal_readonly.py` utilise une connexion SQL réellement en lecture seule, sans HTTP ni compte de test persistant, pour vérifier la synthèse, les registres, les identités et la parité des onze exports Excel. La présence de lignes dans `V_Login_history` ne prouve pas une session encore ouverte ni une révocation de jeton : aucun nouveau mécanisme de session n’a été ajouté par ce chantier.

## Contrôles PostgreSQL des réglages

La migration `20261026_11_controles_administration.sql` renforce les deux tables existantes sans créer de table parallèle et sans réécrire leurs valeurs ou protections. Les clés logiques sont `UNIQUE NULLS NOT DISTINCT`, y compris pour la portée globale dont `ScopeValue` vaut NULL. Les contextes non globaux doivent être renseignés. Respecter les vocabulaires distincts : `global/entite/user/module` pour les paramètres, `global/country/entity` pour les correspondances FK.

`IsEditable=false` protège le paramètre contre les modifications et la suppression. `IsSystem=true` protège son identité, son type, son périmètre et ses protections, ainsi que sa suppression ; **sa valeur reste modifiable si `IsEditable=true`**. Le formulaire ne doit donc pas interdire toutes les modifications des paramètres système éditables.

Avant chaque écriture de ces deux tables, le service lie l’acteur authentifié avec `set_config('systeme.actor_user_id', id, true)` dans la même transaction. Les triggers vérifient qu’il s’agit d’un utilisateur actif existant et imposent l’auteur ainsi que la date. Une écriture directe sans contexte valide porte un auteur NULL, jamais celui transmis dans les données ni l’auteur précédent. Cette GUC est une métadonnée d’audit et ne remplace aucun contrôle d’autorisation. Les droits SQL d’un compte capable d’exécuter librement `SET` restent ceux de ce compte.

Un seul événement SQL par INSERT/UPDATE/DELETE est produit pour `T_Admin_UI_Setting` et `T_Fk_Correspondance` ; ne pas ajouter un second audit Python pour les mêmes écritures. Le remplacement FK historique DELETE/INSERT reste transactionnel et produit un événement pour chaque écriture réelle. La suppression conserve aussi l’auteur de l’opération dans `_actor`, distinct du dernier auteur stocké sur la ligne.

`fn_audit_sans_secrets` nettoie récursivement les objets, listes et anciennes images JSON encodées ; les valeurs des paramètres sensibles sont masquées selon leur `SettingKey`, y compris camelCase historique. Les vues d’audit acceptent PascalCase SQL et camelCase historique et nettoient aussi leurs anciennes images à la lecture. Une nouvelle valeur NULL reste NULL ; ne pas reprendre l’ancienne valeur par COALESCE après une mise à jour.

`SQL/tests/test_controles_administration.py` s’exécute uniquement avec une URL explicite vers une base `sauverndeko_test_*`. La recette privée `.runtime/run_admin_controls_isolated.py` réutilise le cluster de recette, copie seulement la structure et vérifie la conservation intégrale de réglages fictifs préexistants. Ni une recette privée ni un fichier de migration ne prouvent l’application sur une base cliente : inscrire séparément le résultat réel et sa sauvegarde.

La migration 11 a été appliquée à SauverNdeko le 26 octobre 2026 après sauvegarde vérifiée ; les empreintes des 64 tables sont inchangées. Les deux structures canoniques restaurent respectivement 64/54 tables et 79 vues dans des bases isolées. Le parcours privé API vers les triggers vérifie un audit par écriture et aucune fuite d’acteur après COMMIT. Voir `SQL/README.md` pour les preuves et préconditions d’installation.

Les options majeures, licences, modules, droits, portées et correspondances restent en base. Seules les préférences visuelles sans effet sur les droits, comme la densité du tableau et le repli du menu, peuvent rester locales au navigateur.
