# Navigation commune — 30 octobre 2026

`ModuleSidebar` remplace les menus dupliqués de Logistique, Référentiels, Organisation territoriale, Administration et du catalogue. Les groupes repliables, chevrons, icônes fines, états actifs et raccourcis du pied s’inspirent de [TailAdmin](https://demo.tailadmin.com/form-elements) dans les couleurs SauverNdeko.

Le panneau permanent et le rail compact sont conservés sur ordinateur. Le rail mobile permet d’ouvrir le menu complet avec masque, Échap, navigation au clavier, confinement et restitution du focus. Le passage à une largeur d’ordinateur ferme cette ouverture temporaire. Les groupes de navigation vides sont supprimés ; les permissions et clés de navigation restent celles des modules.

Le menu du catalogue utilise les droits de module reçus pour Logistique, Organisation territoriale et Référentiels ; un accès Logistique n’est plus subordonné visuellement au droit d’Administration. L’administration garde son propre contrôle. Aucun droit serveur, identifiant métier ni donnée de formulaire n’est modifié par ces menus. Les préférences locales concernent seulement le repli.

## Contrôles exécutés

- `frontend/scripts/tests/module-sidebar.cjs` : **47 contrôles réussis**, vrais handlers React et DOM simulé. Groupes, conservation du repli, clé stable, droits fournis, rail, ouverture mobile, masque, Tabulation/Échap, focus, changement de largeur et nettoyage.
- `frontend/scripts/tests/sidebar_theme.py` : **4 860 contrôles réussis** de cascade des feuilles réelles. Les cinq contextes, thèmes clair/sombre/contraste, largeurs 1 440/900/390, repli/expansion et menu mobile sont évalués dans deux ordres de chargement CSS. Texte et icônes atteignent un contraste d’au moins 4,5 ; les anciens fonds colorés d’icônes ne réapparaissent pas au survol.
- Compilation Vite réussie après intégration du composant et de ses cinq consommateurs, Administration comprise.

L’accès navigateur à localhost est bloqué pour l’agent. Ces résultats techniques ne prouvent pas une capture visuelle, un défilement réel, la largeur physique d’un téléphone ni un parcours métier complet dans le navigateur. Aucune écriture applicative n’est utilisée par ces contrôles.
