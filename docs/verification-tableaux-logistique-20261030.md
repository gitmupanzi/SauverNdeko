# Vérification des tableaux Logistique — 30 octobre 2026

Les registres Articles, Tiers, Immobilisations, Lots, Bons de stock, Lignes des bons, Mouvements, Inventaires, Factures et Règlements réutilisent `SimpleTable`. Les tableaux de Dossiers de suivi, consultations 360, avoirs, coûts, retours et éditeurs de bons utilisent également ce composant commun, directement ou via un composant partagé. Aucune table HTML distincte n’a été trouvée dans les pages du module.

La présentation commune reprend les Bons de stock : en-têtes thématiques sobres, séparateurs fins, lignes alternées, survol/sélection, colonnes fixes opaques, actions sans cache blanc et pagination partagée. Elle s’applique dans les pages et les fenêtres détachées, avec ou sans barre d’outils. La référence visuelle reste [TailAdmin Data Tables](https://demo.tailadmin.com/data-tables).

## Anomalie corrigée

La ligne de filtres par colonne héritait de la même position verticale que les titres. Lors du défilement, elle pouvait recouvrir l’en-tête. `SimpleTable` mesure maintenant la première ligne et place les filtres juste dessous. La mesure suit le retour à la ligne d’un titre, le redimensionnement et l’activation/désactivation des filtres. Les observateurs et écouteurs sont retirés à la fermeture. Les couleurs des champs de filtre ne dépendent plus d’un parent de registre absent de certaines fenêtres.

## Vérifications exécutées

- `frontend/scripts/tests/table_theme.py` : **1 080 contrôles réussis** de cascade CSS réelle avec `tinycss2` et `cssselect2`, deux ordres de feuilles, pages et fenêtres sans ancêtre de registre, thèmes clair/sombre/contraste, états normal/alterné/survol/sélection, colonnes fixes et actions. Vérification des filtres sous un titre standard ou plus haut, des fonds et d’un contraste de texte d’au moins 4,5.
- `frontend/scripts/tests/table-layout.cjs` : **14 contrôles réussis** sur les hooks du vrai `SimpleTable`, avec dimensions DOM simulées : mesure initiale, changement de hauteur, redimensionnement, désactivation/réactivation des filtres, nettoyage et repli sans `ResizeObserver`.
- `frontend/scripts/tests/logistics-draft-editors.cjs` : **63 contrôles réussis** sur les vrais handlers des éditeurs Tiers, Article et Immobilisation : validation d’une ligne du panier avant tout appel d’écriture, conservation des champs, photo et lots initiaux, affectations explicites, motif commun ou propre à une ligne, erreurs de validation et permissions. Le formulaire individuel « Nouvel article » conserve son appel de création. Les transports et le DOM de ces contrôles sont simulés.
- Ces changements ne modifient aucune route, permission, donnée, clé d’enregistrement ni règle de stock. Aucune écriture de test n’a été effectuée dans la base de l’application.

L’accès navigateur à localhost est bloqué pour l’agent : ces preuves ne remplacent pas une vérification visuelle, un défilement réel ni des essais de largeur mobile. Les résultats de compilation et de saisie multiple sont recensés dans le bilan de leur implémentation.
