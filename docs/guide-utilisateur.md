# Guide utilisateur

Le module **Guide utilisateur**, accessible depuis **Vos applications** et le menu du compte, présente les parcours des applications autorisées. Chaque tutoriel contient un objectif, des étapes courtes, un exemple fictif et les points à retenir. Le bouton vers l’application permet de poursuivre dans le bon écran.

## Trouver un parcours

1. Ouvrir **Guide utilisateur**.
2. Choisir une application dans le menu ou les cartes disponibles.
3. Rechercher un sujet par son titre ou son résumé, puis ouvrir le tutoriel.
4. Suivre les étapes et comparer l’exemple à son propre besoin avant d’effectuer une opération réelle.

Un lien de lecture peut être conservé sous la forme `/guide?module=logistique&article=preparer-commande`. Il ne donne aucun droit supplémentaire : le serveur vérifie encore l’accès au module et au tutoriel demandé.

## Accès et licence

Le guide fait partie du socle de l’application. Les chapitres proposés suivent les modules autorisés par la licence de l’entreprise et les droits du compte. L’administrateur global conserve son accès transverse. La consultation d’un tutoriel ne permet pas d’exécuter une action métier interdite ; les formulaires, données et téléchargements gardent leurs propres contrôles.

Les tutoriels n’utilisent aucun enregistrement client pour leurs exemples. Les montants, noms et quantités qui y figurent servent uniquement à expliquer un parcours : ils ne sont pas créés dans la base de l’entreprise.

## Contenu livré

Le catalogue contient **64 tutoriels dans 12 guides** :

| Guide | Tutoriels | Principaux sujets |
|---|---:|---|
| Catalogue | 3 | Orientation, recherche, disponibilité affichée |
| Produits | 3 | Recherche exhaustive, filtres, cartes/tableau, fiche d’offre, disponibilité déclarée et contact |
| Structures | 3 | Annuaire des structures et territoires, filtres, coordonnées publiées et gestion territoriale |
| Professionnels | 5 | Annuaire, besoins, compétences, prestations, rattachements et contact |
| Discussions | 3 | Conversation, message, destinataire |
| Logistique | 14 | Tableau de bord, tiers, articles, BE, BS, CMD, lots, retours, factures, TVA, règlements, avoirs, inventaires, dossiers, immobilisations et exports |
| Caisse | 8 | Solde par devise, ouverture, brouillon, validation, contrepassation, clôture, règlement de facture et exports |
| Organisation territoriale | 5 | Hiérarchie, paniers, rattachements, analyses et contrôles |
| Support | 4 | Dossiers, traitement, vérification, pièces et suivi |
| Paramètres | 4 | Identité, TVA, PDF et localisations |
| Administration | 7 | Comptes, rôles, permissions, entreprises, licences, réglages, audit et messagerie |
| Référentiels | 5 | Catégories, valeurs, portée, référencement des champs, tableaux et exports |

Le catalogue public est décrit comme un outil de consultation et d’orientation. Les tutoriels n’y annoncent pas de réservation, de paiement ou de création de stock. Dans Logistique, les BE/BS constatent une opération physique ; les CMD ne réservent ni ne modifient le stock. Les factures et avoirs conservent leurs montants et taux historiques.

Dans **Produits**, la recherche et les filtres s’appliquent à toutes les offres publiées, avec pagination. Cartes et tableau proposent les mêmes résultats. Un clic ouvre la fiche de l’offre et conserve la recherche au retour. Le prix est accompagné de sa devise et de son unité ; le stock est déclaré, à confirmer auprès de l’entreprise. Le lien **Contacter l’entreprise**, lorsqu’il est autorisé, rejoint Discussions sans envoyer de message. Les notes internes, le stock exact et le prix d’achat restent dans Logistique. La consultation ne publie pas les anciens articles : leur entreprise garde le choix de visibilité.

Dans **Structures**, Annuaire présente les structures et territoires des niveaux 3, 4 et 5 : centres de santé, hôpitaux, pharmacies, zones, districts, secteurs, groupements et autres types territoriaux enregistrés. Les types proposés lors d’une nouvelle saisie suivent les réglages du niveau. Une ancienne affectation reste consultable dans l’annuaire si le type n’est plus proposé à la saisie. Recherche, niveau territorial, type, province et localité filtrent les mêmes résultats en cartes et tableau. La fiche conserve le rattachement territorial et affiche l’adresse, les téléphones, l’e-mail, le site web, l’accueil et les horaires lorsque ces coordonnées sont publiées. Les informations absentes restent non renseignées. Un téléphone ou e-mail publié permet une prise de contact avec les outils habituels de l’utilisateur ; la fiche territoriale n’ouvre pas de conversation d’entreprise.

**Gestion territoriale**, proposée aux administrateurs autorisés, rejoint les registres des niveaux 3, 4 et 5. Une pharmacie se renseigne dans **Structures et sites, niveau 5**. La lecture de l’annuaire nécessite les accès Structures, indépendamment de l’entreprise active et de l’accès à la gestion territoriale. Les fiches d’entreprise ERP restent distinctes de ces territoires.

Si aucun type n’est proposé pour une nouvelle saisie, ouvrir **Réglages des références** pour consulter les valeurs autorisées et les liens de paramétrage. Une valeur déjà enregistrée reste visible et conservée même si elle n’est plus proposée pour ce niveau. Son absence parmi les nouveaux choix ne retire pas automatiquement la fiche de l’annuaire.

Dans **Organisation territoriale**, les provinces, subdivisions, zones, aires et sites disposent d’une rubrique Coordonnées : adresse, téléphones, e-mail, site web, informations d’accueil et horaires d’ouverture déclarés. Elle est accessible dans la fiche individuelle et les détails des lignes du panier, ainsi que par collage Excel. **Publier les coordonnées dans l’annuaire** vaut Non par défaut et porte uniquement sur ces informations. Le nom, le type et le rattachement territorial restent consultables lorsque la structure fait partie de l’annuaire. Les contacts des parents ne sont pas copiés ; les horaires déclarés ne garantissent pas une ouverture actuelle.

Dans **Discussions**, un nouveau contact part d’une offre Produits ou d’un profil Professionnels autorisé, ou d’une entreprise explicitement liée et autorisée par ce parcours. Le destinataire est vérifié avant l’envoi. Une structure de l’annuaire territorial n’est pas un destinataire d’entreprise. Les conversations déjà autorisées restent soumises aux droits de leurs participants.

## Maintenir les tutoriels

Le contenu éditorial est versionné dans `backend/apps/core/guide_content.json`. Les textes sont structurés et rendus comme du texte, sans HTML exécutable. Les liens d’un tutoriel restent dans son module. Le fichier ne constitue pas une seconde source de licences ou de permissions : les règles d’accès proviennent du serveur et du catalogue des applications.

Une évolution de parcours doit mettre à jour le tutoriel correspondant et contrôler ses libellés, ses étapes et ses liens dans l’interface réelle. Les informations techniques d’installation et les preuves de recette restent dans les autres documents du dépôt ; elles ne sont pas affichées comme des instructions métier.

## Vérifications du 2 novembre 2026

La migration `20261102_02_guide_utilisateur.sql` enregistre uniquement l’application socle dans `systeme.T_ModuleApplication`. Elle a été appliquée dans SauverNdeko après sauvegarde et restauration vérifiées des 73 tables. Les enregistrements métier existants sont préservés ; les exemples du guide ne créent aucune donnée.

- 19 tests API sur PostgreSQL privé, dont la consultation des 57 articles : licence absente, expirée, future ou désactivée, restrictions de rôle, accès direct, deux entreprises, session JWT et refus de changement d’entreprise non autorisé. Les réponses sont sans cache et les routes refusent les mutations.
- 16 tests API Paramètres en régression ; 337 routes GET du diagnostic source réussies en lecture seule.
- 152 assertions d’interface Guide et 207 assertions de régression Paramètres, contexte d’entreprise et navigation. Recherche, liens directs, erreurs, ancien contexte, réponses retardées, retour au titre et menu du compte vérifiés sur DOM/API simulés.
- 480 contrôles CSS pour les thèmes clair, sombre et contraste élevé ; compilation Vite réussie.
- Installation complète sur une base privée vierge : module Guide actif et disponible pour une nouvelle entreprise, Paramètres et défaut TVA 0 conservés, aucune donnée client ni référence privée copiée.

Les preuves techniques sont conservées dans `.runtime`, hors Git. Ces tests ne remplacent pas une recette interactive réelle dans le navigateur ; cette dernière n’a pas été effectuée pendant cette intervention.
