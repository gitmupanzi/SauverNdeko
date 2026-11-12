# Support — prise en main et validation

Le module est accessible à `/support` depuis Vos applications lorsque la licence et les droits du compte l’autorisent. La barre latérale présente le **Tableau de bord**, les **Modèles de suivi** selon les droits, les **Tickets** et le **Suivi des étapes** selon les droits. Un ticket peut être une réclamation, une demande, une intervention ou un autre dossier. Son parcours décrit ses étapes de traitement.

## Configurer et suivre un parcours

1. Dans **Pilotage → Modèles de suivi**, choisissez une entreprise puis créez un modèle. Renseignez ses étapes dans l’ordre de traitement, les affectations, les validations et les pièces ou informations attendues. Le registre propose la recherche, les filtres par type et état, les réglages de colonnes et les exports Excel et CSV. Pour créer plusieurs modèles, téléchargez le modèle Excel, puis importez le fichier et vérifiez les lignes dans le panier avant de les enregistrer.
2. Dans **Tickets → Nouveau dossier**, choisissez le type de demande puis, si nécessaire, un **Modèle de suivi** actif pour ce type. Le ticket et sa première étape sont enregistrés ensemble. Pour un dossier existant encore ouvert, utilisez **Parcours → Associer un modèle de suivi**. Le dossier conserve la version du modèle utilisée au démarrage.
3. Utilisez les actions proposées dans la fiche pour réceptionner ou transmettre le dossier, le bloquer avec un motif, demander un retour ou le valider. L’historique conserve chaque passage, y compris après un retour. L’état du ticket et la vérification de sa clôture suivent le circuit Support.
4. Dans **Traitement → Suivi des étapes**, la recherche et les filtres permettent de retrouver les dossiers par étape, service, responsable, état ou retard. Les pièces restent accessibles dans **Documents** selon leur visibilité.

Les délais sont saisis en minutes calendaires. Le délai global court depuis le démarrage jusqu’à la fin du parcours. Chaque passage dans une étape déclenche son propre délai, arrêté à la sortie de l’étape. Un blocage laisse courir les deux délais. La relance, si définie, est espacée du nombre de minutes choisi et calculée depuis la dernière tentative. Le traitement se lance avec `python manage.py traiter_alertes_support` sur le backend. Planifier cette commande selon la cadence de notification attendue. Elle adresse les alertes au responsable habilité de l’étape ou du dossier et enregistre les échecs. `--dry-run` compte les alertes à traiter sans écriture.

Exemple de configuration à valider dans l’entreprise. Pour une demande liée à un décaissement, prévoir une réception, un contrôle, une validation et une transmission, avec 120 minutes par étape et un délai global choisi de 24 ou 48 heures. Le paiement et sa décision restent dans leur module métier.

### Installation des parcours

La migration additive `20261112_01_support_processus` crée les modèles, versions, parcours, passages, événements, alertes et la vue de suivi. `20261112_02_droits_processus_support` rend l’accès au suivi des étapes configurable dans les restrictions par utilisateur. Les deux migrations conservent les tickets et leurs relations existantes. Le catalogue de référencement réutilise les valeurs génériques. Les [migrations métier](mises-a-jour-base.md) définissent la procédure générale de livraison.

1. Inventorier toutes les migrations en attente et identifier la base cible. Effectuer une sauvegarde PostgreSQL et des médias privés, puis vérifier la restauration sur une base isolée.
2. Rejouer les migrations en attente sur cette copie et vérifier les totaux historiques, les contrôles métier, les droits et les accès aux pièces. Recueillir l’autorisation de production avant application.
3. Sous maintenance, appliquer avec le compte prévu pour les migrations, contrôler les droits du compte applicatif et le résultat de `migrer_metier --check`, puis publier ensemble l’API et le frontend. Vérifier les tickets existants et un parcours de recette avant d’activer la tâche d’alertes.
4. En cas de retour à la version précédente, suspendre la tâche d’alertes et garder le service en maintenance le temps de traiter les parcours engagés. Une restauration revient à la date de la sauvegarde. Après ouverture aux utilisateurs, relever et conserver les données créées depuis la sauvegarde avant toute restauration.

Les entreprises doivent confirmer leurs délais, calendriers de travail, rôles de validation et motifs avant d’activer un modèle. Les heures ouvrées, la suspension des délais et les branches parallèles demandent une décision de conception dédiée.

### Vérifications des parcours du 12 novembre 2026

- Sur une copie PostgreSQL, les deux migrations s’appliquent et une nouvelle exécution les laisse en place sans les rejouer. L’empreinte du dossier historique est identique. Les contrôles PostgreSQL (334 assertions) et API (40 tests) passent.
- Le paquet d’installation a été restauré dans une base vide. Le circuit Support standard est disponible et les données des entreprises de la base source ne sont pas reprises.
- Dans Edge avec Django et PostgreSQL sur la copie, la liste de suivi ouvre le bon dossier. La réception et la transmission passent sur ordinateur. La fiche s’ouvre à 390 px sans défilement horizontal de la page.
- La compilation Vite, le contrôle Django, les tests d’interface Support (243 assertions) et la suite des composants transversaux passent.

Les migrations des parcours ont été vérifiées sur des bases isolées. L’installation en production et la planification des alertes restent à faire.

## Créer et retrouver un dossier

Choisir l’entreprise dans l’en-tête, puis **Nouveau dossier** dans Tickets. Renseigner la demande, son objet et sa description, ses références et, si nécessaire, un responsable, un service et une échéance. Les rubriques Affectation et Objets liés permettent de compléter le contexte. Le demandeur est un tiers de l’entreprise ; il peut ne pas avoir de compte de connexion.

Les liens facultatifs vers un article, un bon de stock et une immobilisation sont contrôlés dans l’entreprise du dossier. Le numéro `SUP-…` est attribué automatiquement et ne peut pas être modifié. Depuis le menu ⋯ ou la fiche, **Modifier le ticket** permet de corriger la demande et les objets liés. **Modifier le suivi** permet de changer le responsable, le service, la priorité ou l’échéance. Les étapes se traitent dans **Parcours**.

La liste propose recherche, filtres, tri, pagination, colonnes personnalisées et exports Excel/CSV. Dans le tableau de bord, les indicateurs **Tickets** et **Suivi des étapes** ouvrent leur liste sous la synthèse. Les graphiques par statut et priorité ouvrent également leurs dossiers. **Revenir à l’indicateur** ramène à la carte ou à la ligne du graphique. Les listes de parcours ouvrent directement l’onglet **Parcours** du dossier. La vue Kanban classe les dossiers selon leur circuit et chaque colonne permet d’ouvrir sa liste complète.

Pour préparer plusieurs dossiers, utiliser **Télécharger le modèle Excel**, compléter la feuille **Tickets**, puis **Importer un fichier Excel**. Le fichier `.xlsx` est limité à 4 Mo et 100 dossiers. Les choix proposés dans le modèle correspondent à l’entreprise autorisée ; les listes acceptent leur identifiant ou un libellé exact non ambigu. L’import remplit seulement un panier : sélectionner chaque dossier pour vérifier les rubriques Demande, Affectation et Objets liés, corriger les erreurs ou retirer une ligne. Un autre fichier ajoute ses lignes au panier sans remplacer les corrections. **Enregistrer le panier** valide l’ensemble dans une seule transaction ; un dossier invalide annule les créations et leurs audits pour tout le lot. Les dossiers individuels restent accessibles par **Nouveau dossier**. Les pièces justificatives s’ajoutent après la création, dans la fiche du dossier.

## Traiter une demande

1. **Affecter** un responsable avant de prendre en charge le dossier.
2. **Prendre en charge** pour passer de Nouveau à En cours.
3. **Mettre en attente** avec un motif si le traitement est suspendu, puis **Reprendre** quand il peut continuer.
4. **Résoudre** en documentant la cause identifiée et la solution appliquée.
5. Faire **vérifier** la solution par une autre personne habilitée, avec un résultat et un commentaire.
6. **Clôturer** après une vérification conforme. Une solution refusée doit être reprise et faire l’objet d’une nouvelle tentative.

Les actions disponibles dépendent des droits et de l’état du dossier. La réouverture exige un motif et conserve les anciennes solutions. Un dossier clôturé peut être archivé puis restauré avec un motif ; sa restauration ne le rouvre pas automatiquement.

## Échanges, documents et historique

La fiche contient Synthèse, Parcours selon les droits, Échanges, Résolutions, Documents et Historique. Les échanges et pièces peuvent être publics ou internes. **Public** signifie visible des personnes autorisées à consulter le dossier ; il ne rend rien accessible sur Internet. Les notes et pièces internes sont réservées aux gestionnaires habilités.

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
