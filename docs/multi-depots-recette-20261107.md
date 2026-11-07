# Multi-dépôts : livraison locale et recette

Date : 7 novembre 2026. Instance concernée : PostgreSQL **local**, base `sauver_ndeko_pro`. Le modèle et la migration sécurisée ont été autorisés dans la conversation. Ce bilan distingue les contrôles exécutés des vérifications restantes.

## Fonctionnement livré

- Dépôts appartenant à une entreprise, dépôt principal initial, création, modification et désactivation contrôlée. Un dépôt ne peut être désactivé lorsqu’il porte du stock, des réservations, du transit ou des opérations qui le nécessitent.
- Stocks physiques, quantités réservées, disponible et transit distingués ; consultation par dépôt ou pour toute l’entreprise. Les lots et le stock sans lot sont contrôlés séparément.
- Transferts internes : préparation, validation/réservation, expédition, réceptions partielles, traitement motivé des écarts et annulation selon l’état. Les BS/BE liés restent consultables avec leurs justificatifs. Les actions sont journalisées, protégées par révision et identifiant de répétition.
- Entrées, sorties, stock initial individuel ou multiple, bons, inventaires, annulations, restitutions, propositions de lots, alertes et réapprovisionnement réutilisent le dépôt concerné. La quantité totale de l’article demeure le stock physique présent ; le transit est affiché séparément.
- Conservation du coût de la sortie source lors des réceptions et retours internes. Le transfert ne crée ni vente, ni facture, ni paiement de Caisse. Les bons commerciaux conservent leur liaison existante à la Caisse.
- Menu Stocks : Dépôts, Articles, Lots de stock, Stocks par dépôt, Bons de stock, Lignes des bons, Transferts internes, Mouvements de stock, Inventaires. Des icônes SVG du système existant identifient les nouvelles rubriques.
- Dans Paramètres → Présentation → Logistique, les trois nouveaux onglets sont renommables et masquables par entreprise. Les personnalisations antérieures sont conservées ; les nouveaux onglets sont visibles par défaut. La restauration des noms et de la visibilité standard reste disponible. Ce réglage de présentation ne remplace pas les permissions.
- Colonne N° dans les bons, les paniers et les documents concernés. Les PDF de transfert indiquent les dépôts source/destination et les lots réellement mouvementés.
- Guide utilisateur et skills backend/frontend/ERP mis à jour.

## Installation locale exécutée

1. Précontrôle en lecture seule : aucune absence d’entreprise propriétaire, incohérence du journal de stock, quantité négative de lot ou relation interentreprises détectée dans le périmètre contrôlé.
2. Arrêt des services locaux pendant la sauvegarde et l’installation.
3. Sauvegarde fraîche de **88 tables et 6 fichiers médias**. Restauration dans `sauverndeko_test_depots_local_20261107` ; égalité des tables, médias et commentaires de triggers de contrainte vérifiée.
4. Installation sur cette copie fraîche, contrôle du journal, rejeu sans nouvelle application et **7 tests SQL réussis**.
5. Installation réelle locale de `20261107_02_multi_depots` par le moteur `migrer_metier`. Aucune migration restante après contrôle.
6. Comparaison des colonnes historiques de **87 tables** : **84 tables strictement inchangées**. Seules trois tables du référentiel ont été enrichies : une catégorie, six états et deux associations de champs. Les nouvelles colonnes de dépôt ne changent ni les anciennes quantités, ni les mouvements, ni les documents financiers.
7. Après migration : **2 dépôts principaux**, un par entreprise ; zéro document historique sans dépôt ; zéro différence entre stock article et somme physique des dépôts ; zéro stock négatif de dépôt/lot ; zéro différence de ventilation des lots.
8. **20 lectures API réussies sur les deux entreprises**, avec le véritable contrôle de permissions local : dépôts, stocks, transferts, articles, bons, lots, synthèse, références, présentation et guide. Ces contrôles n’ont créé aucune donnée métier dans l’instance réelle.
9. Redémarrage effectué par le lanceur sécurisé : backend actif sur 5000, frontend actif sur 5174. Contrôles HTTP après redémarrage : `/health` et `/catalogue` répondent 200 ; `/api/logistique/depots` sans authentification répond 401, comme attendu.

La sauvegarde, les empreintes et les rapports détaillés sont privés dans `.runtime/multi-depots-20261107/local-installation/`. Ils ne doivent pas être publiés avec le code. Aucune modification ni migration Render n’a été effectuée pour cette livraison.

## Tests exécutés

| Périmètre | Résultat et portée réelle |
|---|---|
| SQL multi-dépôts | 7 tests réussis sur copies locales, installation et rejeu journalisés. |
| Rôle HTTP | 3 tests réussis avec un rôle limité sur copie : consultation et journal autorisés, altération du journal interdite. |
| API multi-dépôts | 18 tests réussis sur copie, y compris après le dernier ajustement des prix internes : dépôts, isolation, disponibilité par lot, fractions, réservations, transfert complet/partiel, écarts, annulation, répétition, inventaire, réapprovisionnement et valorisation. Le cas CUMP vérifie aussi un prix catalogue de 999 et un coût source de 15 : les bons internes reprennent 15, et la valeur présent + transit est conservée. |
| Concurrence PostgreSQL | Connexions distinctes : réservations concurrentes refusées au-delà du stock ; double expédition identique sans doublon ; réception/annulation concurrentes avec un seul résultat validé. |
| Caisse existante | 9 tests de régression réussis : une seule écriture après règlement commercial et rejeu, refus atomiques des cas non autorisés ou incohérents. |
| Bons de commande existants | 10 tests de régression réussis sur copie. |
| Paniers existants | 20 cas réussis ; le cas d’import de 600 lignes a été relancé isolément pour éviter l’interférence d’un compteur global entre suites. |
| PDF multi-dépôts | 4 tests réussis ; document fictif de 45 lignes/lots et quatre combinaisons en-tête/pied. Contrôle d’un PDF rendu : N° et alignements lisibles, sans chevauchement d’en-têtes. |
| PDF existants | 191 vérifications réussies sur 13 PDF, 50 pages. |
| Frontend multi-dépôts | 37 vérifications réussies. Éditeurs de brouillons : 70 ; paniers : 231 ; composants UX partagés : 384. |
| Présentation par entreprise | 130 assertions frontend et 5 tests Python isolés réussis : catalogue, masquage, noms, restauration et conservation des personnalisations. Les lectures API réelles confirment les nouvelles rubriques. |
| Construction et démarrage | Build Vite réussi, compilation Python et contrôle Django sans anomalie. Les tests du lanceur local comptent 49 cas réussis. |

Le script historique d’annulation d’inventaire n’est pas déclaré réussi : sa préparation de données rencontre un doublon de référentiel `pcs`. La validation et l’annulation d’inventaire dans un dépôt sont néanmoins exercées par la nouvelle recette API, sur copie.

## Principaux fichiers

- Socle SQL : `SQL/migrations/20261107_02_multi_depots.sql`, `SQL/releases/manifest.json`, `SQL/documentation/Multi_Depots_Precontrole.sql` et `SQL/3. Schema logistique/Logistique_MultiDepots.md`.
- Droits : `deploy/production/role-runtime.sql`.
- Services : `backend/apps/logistique/depots.py`, `transfers.py`, puis adaptation des services et lectures existants des bons, stocks, lots, inventaires, retours et documents.
- Interface : `frontend/src/contexts/DepotScopeContext.jsx`, `frontend/src/pages/logistique/Depots.jsx`, `StocksDepots.jsx`, `Transferts.jsx`, services API et adaptation des éditeurs et consultations existants.
- Présentation : `backend/apps/core/module_presentation.py`, `frontend/src/pages/PresentationSettings.jsx` et `frontend/src/hooks/useModulePresentation.js`.
- Recette : `SQL/tests/test_multi_depots_sql.py`, `test_multi_depots_runtime.py`, `test_multi_depots_api.py`, `test_documents_multi_depots.py`, `frontend/scripts/tests/multi-depots.cjs` et `scripts/tests/test_module_presentation_catalogue.py`.

## Vérifications restantes et limites

- **Recette visuelle ordinateur/téléphone non exécutée** : le navigateur intégré refuse encore l’accès à localhost par sa permission enregistrée, malgré l’autorisation donnée dans la conversation. Les contrôles frontend ci-dessus sont techniques ; ils ne remplacent pas l’observation dans le navigateur.
- Quarantaines opérationnelles et campagnes de rappel ne sont pas livrées comme nouvelles fonctionnalités. Les blocages de lots inactifs/périmés et dérogations existantes sont conservés. Les recommandations OMS/GS1 du plan orientent la conception sans constituer une certification.
- Aucun transfert entre entreprises. Une annulation après expédition restitue uniquement le reliquat en transit ; pour les quantités déjà reçues, créer un transfert inverse.
- Une donnée historique avec propriété ou quantité incohérente doit bloquer l’installation et faire l’objet d’une correction documentée ; la migration n’invente pas son affectation.

## Déploiement d’une autre instance

Exécuter à nouveau le précontrôle et une sauvegarde fraîche restaurée de cette instance. Installer la migration avec le compte de maintenance, appliquer/vérifier les droits runtime, livrer le backend et le frontend compatibles, puis contrôler stocks, lots, documents, permissions et parcours avant réouverture. Ne pas envoyer le SQL brut deux fois ; utiliser le journal du moteur de migration. Après de nouvelles opérations, préférer une correction versionnée ou des mouvements compensateurs à une restauration ancienne qui les ferait perdre.

## Retouches communes et contrôle final — 8 novembre 2026

- Les cases « Dépôt principal » et « Dépôt actif » réutilisent `record-editor-check` : taille compacte de 17 pixels, libellé associé et indication conservée. Les règles métier ne changent pas.
- `AppIcon` utilise maintenant 93 pictogrammes SVG locaux **Icons8 Line Awesome**, sous licence MIT. Les sources, empreintes et notice sont conservées dans le projet et la distribution. Aucun CDN, nouvelle dépendance ou changement des API n'est nécessaire.
- Les menus latéraux, sous-onglets et fiches 360 utilisant `AppIcon` bénéficient de cette collection. Les anciens rendus Bootstrap des tuiles, du guide, du thème, de la connexion/réinitialisation, des métriques et du tri passent aussi par ce composant. Les noms historiques reçus du serveur restent compatibles ; logos, photos et avatars sont conservés.
- Contrôles : 507 assertions de rendu des icônes ; `npm run test:ux` compte désormais 891 assertions réussies. Les suites CSS de navigation, catalogue, guide et formulaires ont validé 2 627 contrôles. Le test de contexte d'entreprise a été adapté à l'en-tête imbriqué et compte 80 contrôles réussis, incluant la possibilité de masquer le sélecteur.
- Build Vite final réussi : 374 modules. Services locaux redémarrés par le lanceur sécurisé ; page `/catalogue` et santé Django répondent 200, et les nouvelles routes de préférences et d'export refusent les requêtes anonymes avec 401. Le frontend demeure sur le port 5174 ; le lanceur a choisi le port backend libre 5001.

Un aperçu vectoriel statique des pictogrammes a été inspecté sur fond clair et sombre. Ce contrôle d'assets et les tests CSS/React ne constituent pas une recette visuelle des pages dans le navigateur. Aucun déploiement Render ni push réalisé pour ces retouches.

## Réglages des quatre registres de dépôt

Les registres Dépôts, Stocks par dépôt, Transferts internes et Inventaires reprennent maintenant le bouton **Réglages** dans l’en-tête, comme Articles et Bons de stock. Le panneau commun permet de choisir et organiser les colonnes et de préparer les exports. Les préférences sont enregistrées côté serveur par compte et contexte d’entreprise. Le registre embarqué dans Produit 360 conserve les mêmes réglages.

Le hook commun `useLogisticsRegisterSettings` transmet les filtres, le dépôt et le tri à l’export serveur de tous les résultats autorisés ; il ne transmet pas la limite de page. Les téléchargements obsolètes sont annulés lors d’un changement de contexte. Les permissions, les colonnes exportables et les erreurs de chargement sont prises en compte avant l’export. La barre de recherche ne répète pas le bouton Réglages de l’en-tête.

Contrôles frontend réellement exécutés : **63** nouveaux contrôles des réglages et exports de ces quatre registres, **37** contrôles multi-dépôts, **130** contrôles de réglages partagés et **384** contrôles UX partagés réussis. Construction Vite réussie. Ces contrôles sont des tests de composants/services ; la limite de recette visuelle indiquée plus haut reste applicable.

La migration additive `20261107_03_registres_depots_tableaux` déclare uniquement les quatre catalogues de tableaux dans le référentiel. Elle ne modifie pas les quantités, les mouvements ni les préférences personnelles déjà enregistrées. Elle a été vérifiée sur copie privée, avec restauration des métadonnées et rejeu sans effet, puis installée localement par `migrer_metier` après sauvegarde ciblée du catalogue et de son journal. Le contrôle ne trouve aucune migration en attente et le rejeu n’applique rien. Les **516 articles, 536 mouvements et 24 bons**, ainsi que leurs totaux de quantités, sont strictement inchangés.

**6 nouveaux tests backend sur copie** réussis : les quatre catalogues, modification/restauration des préférences et conflits de révision, isolation entre entreprises, exports CSV dépassant la page affichée, vrais XLSX filtrés et sans filtre pour les quatre registres, permissions d’export, colonnes interdites et lecture seule. Les **18 tests API multi-dépôts existants** passent également. Un cas réel XLSX a révélé un libellé de filtre absent ; le writer commun accepte désormais les libellés de contexte fournis par le registre, tout en conservant les anciens libellés.

Fichiers complémentaires : `backend/apps/logistique/depot_registers.py`, les routes et le raccordement aux préférences partagées, `SQL/tests/test_registres_depots_tableaux.py`, `frontend/src/hooks/useLogisticsRegisterSettings.js` et `frontend/scripts/tests/warehouse-register-settings.cjs`. Les sauvegardes et preuves restent privées sous `.runtime/multi-depots-20261107/register-settings/`. Aucun accès à Render pour cette correction.
