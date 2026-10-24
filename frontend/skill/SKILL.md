---
name: sauverndeko-frontend
description: Faire évoluer les interfaces React de SauverNdeko vers des parcours ERP modernes, avec tableaux cohérents, indicateurs consultables et fiches 360 accessibles. Utiliser pour navigation, formulaires, filtres, consultations produit/commande et présentation des données API.
---

# Frontend SauverNdeko

## Références

- [Architecture existante](references/architecture.md) pour les composants, routes, helpers et limites du code actuel.
- [Contrats d’interface](references/contrats-interface.md) pour tableaux, indicateurs, fenêtres 360, filtres, exports et recette.
- [Skill transverse ERP](../../skills/sauverndeko-erp/SKILL.md) pour un changement entre plusieurs domaines.
- [Skill backend](../../backend/skill/SKILL.md) dès qu’un nouveau filtre, calcul ou détail API est requis.

- Pour les exports Excel, Word et PDF : [skill documentaire SauverNdeko](../../skills/document-mise-en-forme/SKILL.md). Réutiliser la charte et le contrat de parité sans recalcul métier propre au format.

## Pile et responsabilités

Conserver React 19 en JSX, React Router, Vite, Bootstrap et Bootstrap Icons présents dans le projet. Les principes d’imf_BB sont à reproduire dans cette pile ; ne pas imposer sa migration TypeScript. Le backend est Django/DRF avec les JWT existants ; ne pas remplacer la session React par des cookies Django sans décision dédiée. Ajouter une dépendance seulement pour un besoin réel.

React présente les données autorisées et pilote les interactions. Les mesures métier, droits, recherches exhaustives, totaux et exports complets viennent du serveur. Le dashboard actuel contient des calculs sur des listes plafonnées : ne pas reprendre ce modèle pour de nouveaux indicateurs.

## Parcours attendus

- Le code/nom d’un objet et son bouton Consulter ouvrent la même fiche 360 depuis liste, recherche ou détail lié.
- Une valeur d’indicateur ayant un détail ouvre cette population exacte, ou son registre avec un filtre visible et effaçable. La carte et le lien de détail partagent le même contrat.
- Produit 360 et Commande 360 sont les premiers parcours cibles ; Facture/Règlement puis Client/Fournisseur suivent le contrat métier disponible. Ne pas présenter un composant cible comme déjà raccordé.
- Les fenêtres partagent réduire/élargir/rétablir/fermer, poignée, clavier, adaptation mobile et retour au contexte, conformément à la référence.
- La consultation charge uniquement l’objet sélectionné, puis ses rubriques à la demande si volumineuses. Ne pas lancer une requête 360 pour chaque ligne du tableau.

## Invariants d’interface

1. Conserver filtres appliqués, page, sélection et position lors de l’ouverture/fermeture d’une fiche. Restituer le focus au déclencheur.
2. Distinguer saisie et filtres appliqués. Le compteur et l’export décrivent les critères effectivement envoyés au serveur.
3. Préserver recherche, tri, pagination, colonnes visibles/gelées/redimensionnables et sélection déjà disponibles ; mutualiser leur comportement avant d’ajouter des variantes.
4. Placer la taille de page et les commandes d’affichage au-dessus du tableau. Les totaux viennent dessous. Les actions principales et exports restent alignés aux filtres quand la largeur le permet.
5. Garder les groupes d’indicateurs analytiques repliés par défaut dans les registres ; un affichage ou repli ne change aucun filtre ni montant. Les cartes du tableau de bord principal restent selon le parcours de pilotage retenu.
6. Valeur inconnue = — ou Non déterminable ; zéro seulement s’il vient de la source. Devise, unité, période et réserves indispensables restent visibles.
7. Ne pas réutiliser le USD codé en dur de formatCurrency comme preuve de la devise d’un objet. Faire évoluer le contrat de données avant de prétendre gérer plusieurs devises.
8. Menus et boutons suivent les permissions reçues ; le backend reste responsable du refus effectif. Traiter 401, 403, indisponibilité et conflit avec un état explicite.
9. Aucun bouton fictif ou sélecteur sans effet réel : raccorder l’action ou rendre son indisponibilité compréhensible. Les chiffres de démonstration restent identifiés et fictifs.
10. Les aides, cases de sélection et actions d’une ligne arrêtent la propagation quand elle ouvrirait une autre consultation. Utiliser de vrais liens/boutons avec focus visible.

## Présentation

Reprendre les repères d’imf_BB : titres courts, hiérarchie claire, bandeaux principaux foncés, sous-blocs vert très clair et texte foncé, tableaux lisibles, détails secondaires repliés. Préserver la marque SauverNdeko et utiliser des styles partagés ; éviter une surcharge locale par écran.

Sources et calcul, replié, précède Voir le détail. Les explications reflètent les colonnes et formules vérifiées côté backend, sans inventer un contrôle ni charger l’écran de commentaires techniques. Les identifiants SQL n’occupent pas le parcours métier ordinaire.

## Vérification

Le package frontend déclare build, dev et preview, sans script test. Pour une modification réelle, npm run build vérifie le bundling ; compléter par les interactions utiles à la tâche sur données fictives. Vérifier ordinateur, largeur intermédiaire et mobile, clavier, zoom réel, retour au focus, annulation, erreur et parité des filtres/détails/exports. Une compilation seule ne valide pas les droits, la précision d’un KPI ou l’ergonomie d’une fenêtre.
