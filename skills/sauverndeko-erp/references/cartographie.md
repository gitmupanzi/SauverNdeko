# Cartographie de SauverNdeko

> Relevé historique de l’architecture Express/Prisma avant conversion. Depuis le choix ultérieur du propriétaire le 24/10/2026, le backend actif est Django ; voir [le bilan actuel](../../../SQL/documentation/Audit_Metier_20261024.md). Les fichiers Node décrits ici ont depuis été supprimés à la demande du propriétaire. Leurs chemins ci-dessous sont historiques ; pour le code actuel, consulter [l’architecture Django](../../../backend/skill/references/architecture.md). La base est restée inchangée pendant la conversion.

Relevé du 24 octobre 2026, à partir de C:/Users/Benjamin-mupanzi/Documents/SauverNdeko. Référence : projet voisin imf_BB, ses skills backend/frontend et l’historique partagé par le propriétaire. Le dépôt était sans modification Git lors du relevé initial.

## Portée des constats

Analyse statique des sources, schéma Prisma, scripts SQL, README et cahier de charge. Les fichiers .env, sauvegardes de base, pièces privées et données clients n’ont pas été lus. Aucun serveur, script de données ou migration n’a été lancé. « Présent » signifie trouvé dans le code ; l’installation SQL, les droits réels et les parcours connectés restent à vérifier sur un environnement de recette.

## Architecture

~~~mermaid
flowchart LR
  Public[Catalogue public] --> React[React 19 / Vite / JSX]
  Prive[Profil, discussions, administration, logistique] --> React
  React --> HTTP[Services API avec JWT pour les accès privés]
  HTTP --> Express[Express : routes historiques et modules REST]
  Express --> Services[Services métier et validation]
  Services --> Vues[Vues PostgreSQL de lecture]
  Services --> Prisma[Prisma : écritures et lectures ciblées]
  Vues --> Tables[Tables par schéma métier]
  Prisma --> Tables
  Tables --> Routines[Triggers et procédures logistiques prévus par SQL]
~~~

Le schéma décrit les couches trouvées, sans certifier que toutes les routes appliquent déjà les droits attendus.

| Couche | Technologie et entrée | Responsabilité actuelle |
|---|---|---|
| Frontend | React 19, Router 7, Vite 6, Bootstrap 5 ; frontend/src/main.jsx et App.jsx | Catalogue public, session, profil, discussions, administration et logistique |
| Backend | Node.js, Express 4 CommonJS ; backend/app.js et server.js | Routes publiques, JWT, CRUD historiques, modules REST, vues |
| Accès SQL | Prisma 6 ; backend/config/db.js et prisma/schema.prisma | 31 modèles dans huit schémas ; client généré dans backend/generated/prisma |
| SQL versionné | SQL/0…7 par domaine | Tables partielles, vues, scripts de test et migration d’alignement logistique |
| Conventions | skills/AGENTS.md et les trois emplacements de skills | Navigation documentaire ajoutée par cette intervention |

Les versions sont celles des manifests locaux, pas une vérification des dernières versions publiées.

## Domaines fonctionnels

| Domaine | Éléments trouvés | Couverture et limites |
|---|---|---|
| Catalogue public | Home, Products, Pharmacies, Experts, Diseases ; public.controller.js ; /api/public | Consultation et recherche présentes. Pas de parcours complet de vente public démontré. |
| Comptes et profils | AuthContext, ProtectedRoute, Profile ; auth.controller.js ; /SauverNdeko/auth | Connexion, inscription, vérification, refresh et profil codés ; recette session à effectuer. |
| Discussions | Discussions.jsx ; discussion.controller.js ; T_Discussion, T_Chat, T_Communication | Création/réutilisation d’échanges et messages ; vérifier l’accès aux seuls participants. |
| Administration | Admin.jsx ; pages/admin/{systeme,referentiel,geolocalisation}.js | Vues, CRUD, recherche, colonnes, sélection et paramètres FK ; composant central volumineux (~4 816 lignes). |
| Paramètres | T_Admin_UI_Setting, audit, correspondances FK | Portées global/country/entity prévues ; elles ne remplacent pas une politique d’accès par organisation. |
| Logistique | Logistique.jsx ; dix vues déclarées dans pages/logistique/views.js | Articles, commandes, lignes, mouvements, règlements, audit, alertes, consommation, couverture, dashboard. |
| Opérations | T_Caisse, T_Paiement, T_Paiement_Archive ; six vues SQL | Socle de données trouvé ; pas de module caisse/trésorerie métier complet trouvé dans les routes et pages dédiées. |
| Professionnels | T_Professionnel, T_Professionnel_Entite ; trois vues | Consultation publique et structures ; pas de gestion RH complète. |
| Analytics | T_Recherche, V_Recherche | Historique de recherche ; pas une plateforme décisionnelle ERP complète. |
| Géolocalisation | Sept modèles de niveaux, hiérarchie et vues | Administration géographique modulaire ; adaptations pays à éprouver. |

## Parcours logistique actuel

| Écran | Route frontend | API privilégiée | Source de lecture |
|---|---|---|---|
| Dashboard | /logistique, onglet dashboard | /api/logistique/dashboard | getDashboardSummary et vues logistiques ; compléments React |
| Articles | onglet articles | /api/logistique/articles | V_Article, enrichissement serveur |
| Commandes | onglet commandes | /api/logistique/commandes | V_Commande, enrichissement serveur |
| Lignes | onglet details | /api/logistique/commande-details | V_CommandeDetail ; clé article + commande |
| Mouvements | onglet mouvements | /api/logistique/mouvements | V_Mouvement, lecture seule |
| Règlements | onglet reglements | /api/logistique/reglements | V_SuiviReglements ; /reglements/entries pour les écritures |
| Audit | onglet audit | /api/logistique/stock/audit | V_AuditStock |
| Alertes | onglet alertes | /api/logistique/stock/alertes | V_AlertStock |
| Consommation | onglet consommation | /api/logistique/stock/consommation | V_ConsoMensuelle |
| Couverture | onglet couverture | /api/logistique/stock/couverture | V_CouvertureStock |

Les sous-vues sont aujourd’hui des états internes de Logistique.jsx ; elles ne sont pas toutes des routes URL indépendantes. Les écrans de consultation 360 partagés restent à créer.

Cycle métier documenté : article → commande d’entrée/sortie → ligne → stock/mouvement → facture → règlement → contrôles. Le scénario SQL précise INSERT = appliquer, UPDATE = annuler l’ancien effet puis appliquer le nouveau, DELETE = annuler. La migration d’alignement contient les routines correspondantes ; leur installation réelle n’a pas été inspectée.

## Écarts observés et preuves

| Réf. | Constat dans les sources | Implication et suite |
|---|---|---|
| SEC-01 | app.js appelle registerModuleRoutes avant les routeurs historiques protégés. register-module-routes.js monte directement les routeurs ; module-kit.js et logistique/article/index.js n’ajoutent pas verifyToken/requireAdmin. | Certaines nouvelles routes de lecture/écriture, dont utilisateurs et logistique, n’ont pas de protection visible dans leur chemin de montage. Corriger et tester accès anonyme, rôle insuffisant et autorisé avant livraison. Le middleware d’un routeur ultérieur ne protège pas un handler antérieur ayant répondu. |
| SEC-02 | requireAdmin accepte notamment Is_staff ; vues et services génériques n’imposent pas systématiquement un contexte d’organisation. | Définir les rôles ERP et le périmètre serveur, y compris détails, FK, compteurs et exports. Multi-organisation reste une cible à valider. |
| DATA-01 | DashboardLogistique appelle audit/alertes avec take:200, consommation/couverture avec take:400 ; logistique.service plafonne à 200. Des reduce/filter React produisent plusieurs synthèses. | Les synthèses locales peuvent être partielles. Passer aux agrégats SQL serveur exhaustifs avec même filtre que le détail. |
| UX-01 | Les sélecteurs période/catégorie/type/statut/paiement du dashboard sont stockés localement ; le chargement dépend de refreshKey et ne les transmet pas. | Raccorder les filtres réellement appliqués et afficher leur état. Une sélection visible doit correspondre au calcul affiché. |
| UX-02 | DashboardKpiCard rend un article sans action. Plusieurs liens onNavigate ouvrent uniquement un onglet, sans filtre associé. | Ajouter détail ou registre filtré avec puce effaçable et conservation du contexte. |
| UX-03 | Les consultations Produit 360 et Commande 360 communes ne sont pas présentes. | Créer une infrastructure commune et raccorder identité/Consulter ; définir l’API avant l’interface. |
| EXPORT-01 | logistiqueShared génère CSV, un tableau HTML téléchargé avec extension .xls et une fenêtre d’impression pour PDF à partir des lignes reçues. | Distinguer export de page et export exhaustif ; ne pas présenter ces helpers comme un moteur XLSX/PDF serveur déjà livré. |
| SQL-01 | Les scripts logistique, système et référentiel n’ont pas de COMMENT ON ; géolocalisation et opérations en contiennent. | Compléter les commentaires versionnés puis contrôler leur présence dans la base. Un fichier SQL sans commentaire ne prouve pas que la base en est dépourvue. |
| SQL-02 | V_Admin_UI_Setting_Audit est définie deux fois dans Systeme_View.sql ; vues logistiques répétées dans la migration d’alignement. | Identifier la définition canonique et l’ordre d’application avant consolidation ; ne pas supprimer automatiquement les doublons historiques. |
| DATA-02 | Quantités article/ligne en Decimal(14,3), QteMvt en Int dans Prisma. | Vérifier la cohérence des unités, fractions et routines sur recette ; préparer une évolution compatible si les quantités fractionnaires sont admises. |
| DATA-03 | Pas de champ devise explicite trouvé sur les cinq modèles logistiques et formatCurrency impose USD dans le frontend ; ID_ClientFk n’a pas de relation Prisma déclarée dans T_Commande/T_Reglements. | Formaliser devise et référentiel des tiers avant de promettre un ERP multidevise ou une fiche Client 360 exhaustive. |
| MAINT-01 | Les deux packages ne déclarent pas de script test ; pas de suite applicative dédiée trouvée dans le périmètre inspecté. Les scripts SQL *_Test existent. | Prévoir une recette et des tests ciblés pour les prochaines modifications ; ne pas lancer les scripts SQL de données sur la base courante. |
| DOC-01 | cahier_charge présente commandes, paiements et dashboard comme futurs alors que la logistique possède du code. | Lire l’addendum daté et distinguer présence de code et validation fonctionnelle. |

## Éléments repris d’imf_BB

Réutilisation prioritaire des vues, calculs serveur, commentaires PostgreSQL, recherche avant pagination, parité écran/détail/export, fenêtres de consultation redimensionnables, liens sur identité, KPI actionnables, groupes masquables et sobriété des textes. La [matrice de transposition](transposition-imf-bb.md) indique les fichiers sources et les adaptations nécessaires.

## Ce que cette intervention livre

La cartographie, un inventaire de sources, trois skills et leurs références, le routage skills/AGENTS.md et des addenda aux deux documents existants. Elle ne modifie pas le code exécuté, le schéma Prisma, les dépendances ou la base ; les écarts ci-dessus restent donc ouverts. La [trajectoire ERP](trajectoire-erp.md) définit la suite.


## Commentaires appliqués en base — 24 octobre 2026

Les huit schémas applicatifs de la base locale SauverNdeko possèdent désormais 1553 commentaires couvrant tables, vues, colonnes, fonctions/procédures, triggers, séquences, contraintes et index. Application, réexécution et retour arrière vérifiés sur une copie isolée sans données ; les textes sont vérifiés après commit dans la base locale et les définitions restent inchangées.

Le relevé statique précédent reste la trace de l’étape de cartographie. L’inspection réelle a trouvé 30 tables et 39 vues installées, contre 31 modèles Prisma et 52 vues déclarées dans les sources. SQL-01 est traité pour les objets installés ; les objets absents ne sont pas créés. Voir le [bilan de cette intervention](../../../SQL/documentation/Commentaires_PostgreSQL_20261024.md). Les autres écarts restent ouverts.


## Fiabilisation logistique — évolution 20261024_02

La migration 02 est appliquée à la base locale : verrouillage des parents, totaux par instruction, clôture normalisée, alertes sans seuil, couverture sans jours futurs et audit SQL filtrable. Les données existantes sont inchangées ; les contrôles ont été exécutés sur une base de recette fictive. Les deux nouvelles fonctions et le remplacement d’un trigger par quatre portent la couverture globale à 1558 objets/colonnes commentés (27 fonctions, six procédures, 27 triggers ; autres familles inchangées).

Consulter le [bilan de fiabilisation](../../../SQL/documentation/Logistique_Fiabilisation_20261024.md). Les écarts de droits API, d’isolation et de calculs du dashboard frontend restent ouverts.
