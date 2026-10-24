# Examen DBA — schémas systeme et public

24/10/2026. Le propriétaire a demandé si leur fusion était judicieuse. Recommandation : conserver les deux schémas et préparer séparément le rapprochement des identités. Aucune fusion, aucun déplacement et aucune suppression de table n’ont été exécutés pour cet examen.

## Constat installé

| Schéma | Contenu | Rôle |
|---|---|---|
| public | 10 tables natives Django | Utilisateurs/groupes/permissions Django, sessions, contenttypes, journal d’administration et historique des migrations |
| systeme | 8 tables métier | Utilisateurs/profils ERP, entités, localisations, licences, connexions, audit et paramétrage |

systeme.T_Entite et systeme.T_Utilisateurs sont chacune référencées par 11 clés étrangères, soit 22 références entrantes. La base possède actuellement trois comptes métier et aucun compte auth_user. Les tables natives ont été créées sans recopier les comptes ou mots de passe métier.

Les noms systeme.* sont qualifiés dans les modèles Django, requêtes, vues et routines. Un déplacement physique demanderait une reprise coordonnée de ces consommateurs, particulièrement les noms SQL contenus dans les fonctions ou chaînes de requêtes. Il ne rapprocherait pas automatiquement les comptes ni leurs permissions.

## Pourquoi conserver la séparation

- public porte le cycle de migration standard Django ; systeme garde les conventions et dépendances de l’ERP.
- PostgreSQL autorise les relations entre schémas de la même base. Une clé étrangère peut relier un profil systeme au compte Django public sans déplacement de table.
- Un changement de schéma ne constitue pas en soi une optimisation de requêtes. Les plans, index, filtres et volumes doivent être mesurés séparément.
- Le problème à résoudre est l’existence de deux modèles d’identité, et non la présence de deux espaces de noms.

Le search_path applicatif est exactement public pour les objets natifs. Les objets métier utilisent des noms qualifiés. Le droit CREATE dans public n’est pas accordé au rôle PUBLIC sur cette base ; aucune permission existante n’a été modifiée pendant l’examen. Une séparation de schémas n’assure pas, seule, l’isolation entre organisations : les droits et critères serveur restent nécessaires.

## Évolution d’identité proposée, non appliquée

Utiliser auth_user comme identité de connexion de référence, et conserver T_Utilisateurs comme profil métier avec ses identifiants historiques et relations ERP. Ajouter ensuite un lien un-à-un explicite vers auth_user.id, après définition du rapprochement et contrôle des doublons.

La reprise doit traiter les mots de passe compatibles, comptes inactifs, rôles, groupes, droits locaux/globaux et sessions. Les FK métier existantes restent attachées aux identifiants historiques ; le contrat JWT/React doit être adapté sans confusion entre les deux types d’identifiant. Les anciens champs d’authentification métier ne sont dépréciés qu’après bascule et vérification. Aucune de ces transformations n’a été exécutée sur la seule question de fusion.

Il faut aussi traiter séparément la propriété immuable des articles/commandes : elle est actuellement déduite du créateur et peut évoluer si celui-ci change d’organisation. Le rapprochement des comptes ne résout pas ce point.

## Références primaires

- [PostgreSQL — schémas, accès et search_path](https://www.postgresql.org/docs/current/ddl-schemas.html).
- [Django — extension du modèle User par un profil lié](https://docs.djangoproject.com/en/5.2/topics/auth/customizing/#extending-the-existing-user-model).

La recommandation d’architecture découle des dépendances relevées dans SauverNdeko ; les sources documentent les possibilités techniques.
