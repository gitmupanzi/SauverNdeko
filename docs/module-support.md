# Support — prise en main et validation

Le module est accessible à `/support` depuis Vos applications lorsque la licence et les droits du compte l’autorisent. Il regroupe les incidents, demandes d’assistance et réclamations. Les deux onglets sont **Tableau de bord** et **Tickets**.

## Créer et retrouver un dossier

Choisir l’entreprise dans l’en-tête, puis **Nouveau dossier** dans Tickets. Renseigner la demande, son objet et sa description, ses références et, si nécessaire, un responsable, un service et une échéance. Les rubriques Affectation et Objets liés permettent de compléter le contexte. Le demandeur est un tiers de l’entreprise ; il peut ne pas avoir de compte de connexion.

Les liens facultatifs vers un article, un bon de stock et une immobilisation sont contrôlés dans l’entreprise du dossier. Le numéro `SUP-…` est attribué automatiquement et ne peut pas être modifié. L’ajout et la modification utilisent le même formulaire.

La liste propose recherche, filtres, tri, pagination, colonnes personnalisées et exports Excel/CSV. Le tableau de bord ouvre les populations correspondant aux indicateurs. La vue Kanban classe les dossiers selon leur circuit ; chaque colonne indique son effectif total et permet d’ouvrir la liste complète. Consulter un numéro ou une carte ouvre la même fiche.

## Traiter une demande

1. **Affecter** un responsable avant de prendre en charge le dossier.
2. **Prendre en charge** pour passer de Nouveau à En cours.
3. **Mettre en attente** avec un motif si le traitement est suspendu, puis **Reprendre** quand il peut continuer.
4. **Résoudre** en documentant la cause identifiée et la solution appliquée.
5. Faire **vérifier** la solution par une autre personne habilitée, avec un résultat et un commentaire.
6. **Clôturer** après une vérification conforme. Une solution refusée doit être reprise et faire l’objet d’une nouvelle tentative.

Les actions disponibles dépendent des droits et de l’état du dossier. La réouverture exige un motif et conserve les anciennes solutions. Un dossier clôturé peut être archivé puis restauré avec un motif ; sa restauration ne le rouvre pas automatiquement.

## Échanges, documents et historique

La fiche contient Synthèse, Échanges, Résolutions, Documents et Historique. Les échanges et pièces peuvent être publics ou internes. **Public** signifie visible des personnes autorisées à consulter le dossier ; il ne rend rien accessible sur Internet. Les notes et pièces internes sont réservées aux gestionnaires habilités.

Les pièces acceptées sont les PDF et images PNG/JPEG/WebP dans la limite de 8 Mo. Elles sont stockées de manière privée, avec contrôle au téléversement et au téléchargement. Une pièce peut être rattachée à un commentaire du même dossier. Les échanges, tentatives de résolution et événements antérieurs restent conservés.

## Droits et réglages

Les comptes d’entreprise consultent leurs données autorisées. Les mutations exigent les droits de gestion du module et un compte administrateur habilité. L’administrateur global peut consulter toutes les entreprises ; il sélectionne une entreprise pour effectuer une modification. Support a sa propre activation de licence : la licence Logistique seule n’accorde pas automatiquement cet accès.

**Réglages → Références** présente l’identité physique du champ, l’ID et le libellé de sa catégorie, sa valeur par défaut et ses choix. Le paramétrage se gère dans Référentiels → Référencement des champs. Les valeurs anciennes devenues incompatibles restent conservées et signalées.

La définition du circuit se trouve dans Administration → Paramètres UI, clé `support.workflow`. Ce paramétrage technique est réservé aux personnes habilitées. Le circuit est capturé lors de la création du dossier : changer le réglage ne transforme pas silencieusement les dossiers déjà ouverts.

En cas de modification concurrente, recharger la fiche avant de poursuivre. Si une réponse réseau est incertaine, utiliser **Vérifier l’enregistrement** : l’application rejoue la même demande et évite un second enregistrement.

## Livraison du 31 octobre 2026

La migration Support a été installée dans SauverNdeko après sauvegarde et restauration de contrôle. Les anciennes données sont préservées. Aucun ticket fictif n’a été créé dans cette base. Le module a été activé sur la licence existante de COUSP sans modifier sa date d’expiration.

Vérifications exécutées :

- 221 assertions PostgreSQL sur copie privée : intégrité, circuit complet, tentatives successives, références, pièces et refus.
- 33 tests API Support et 18 tests de régression Administration sur copie privée : permissions, entreprises, transactions, concurrence, rejeu, exports et confidentialité.
- 155 assertions d’interface avec API/DOM simulés, dont le rendu du véritable tableau et les 17 colonnes du catalogue.
- 68 assertions sur le contexte d’entreprise partagé, notamment un compte autorisé à Support sans licence Logistique.
- 1 364 assertions de styles sur fixtures pour les thèmes clair, sombre et contraste élevé ; elles ne remplacent pas un examen visuel.
- 318 contrôles GET avec résultats attendus sur SauverNdeko en transaction de lecture seule, dont les routes Support.
- Restauration des structures SQL complètes et métier sur deux bases vides : définitions et commentaires identiques à la source, sans données client.
- Installation réelle du paquet vierge format 3 dans une base privée vide : circuit standard, références et migrations Django chargés ; aucun compte, entreprise ou dossier client copié. Un circuit invalide est refusé et le seed ne remplace pas un réglage existant.
- Compilation Vite et contrôle Django réussis. Après redémarrage, les deux routes de santé répondent 200 et la nouvelle API Support refuse bien une consultation sans connexion (401).

Les preuves détaillées sont conservées dans le dossier local privé `.runtime`, exclu de Git. Les contrats techniques sont dans [la documentation PostgreSQL](../SQL/documentation/Support_20261030.md), [le skill backend](../backend/skills/develop-sauverndeko-backend/references/support.md) et [le skill frontend](../frontend/skills/develop-sauverndeko-frontend/references/support.md).

**Limite de validation :** l’accès du navigateur automatisé à localhost est bloqué par une permission enregistrée. La recette visuelle réelle, la connexion interactive et la manipulation dans le navigateur ne sont donc pas attestées par cette livraison. Les contrôles techniques ne doivent pas être présentés comme cette recette.
