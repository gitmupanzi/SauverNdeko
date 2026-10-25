---
name: sauverndeko-frontend
description: Faire évoluer les interfaces React de SauverNdeko vers des parcours ERP modernes, avec tableaux cohérents, indicateurs consultables et fiches 360 accessibles. Utiliser pour navigation, formulaires, filtres, consultations produit/commande et présentation des données API.
---

# Frontend SauverNdeko

## Références

- [Architecture existante](references/architecture.md) pour les composants, routes, helpers et limites du code actuel.
- [Référence visuelle](references/design-reference.md) pour l’accueil, le login, les blocs du tableau de bord et les tableaux inspirés de TailAdmin.
- [Formulaires et CRUD Articles](references/formulaires-crud.md) pour sélecteurs recherchables, fenêtres latérales, photos, poids et lots : base des futurs onglets.
- [Contrats d’interface](references/contrats-interface.md) pour tableaux, indicateurs, fenêtres 360, filtres, exports et recette.
- [Skill transverse ERP](../../skills/sauverndeko-erp/SKILL.md) pour un changement entre plusieurs domaines.
- [Skill backend](../../backend/skill/SKILL.md) dès qu’un nouveau filtre, calcul ou détail API est requis.

- Pour les exports Excel, Word et PDF : [skill documentaire SauverNdeko](../../skills/document-mise-en-forme/SKILL.md). Réutiliser la charte et le contrat de parité sans recalcul métier propre au format.

## Entrée de l’application

Le propriétaire demande le login comme écran d’entrée. App.jsx attend la restauration de session, présente /login aux visiteurs sans session et conserve les destinations internes pour le retour après connexion. Le shell et le catalogue se chargent après authentification ; l’inscription libre est fermée. Ne pas rétablir une page d’accueil anonyme par défaut. Django impose aussi l’authentification sur le catalogue et fournit les modules autorisés par /api/workspace/modules. Conserver les contrôles d’objet et de périmètre sur chaque route.

## Pile et responsabilités

Conserver React 19 en JSX, React Router, Vite, Bootstrap et Bootstrap Icons présents dans le projet. Les principes d’imf_BB sont à reproduire dans cette pile ; ne pas imposer sa migration TypeScript. Le backend est Django/DRF avec les JWT existants ; ne pas remplacer la session React par des cookies Django sans décision dédiée. Ajouter une dépendance seulement pour un besoin réel.

React présente les données autorisées et pilote les interactions. Les mesures métier, droits, recherches exhaustives, totaux et exports complets viennent du serveur. Le nouveau dashboard et les registres Articles/Bons de stock utilisent les lectures paginées et agrégats de apps/logistique/reads.py. Les autres registres historiques restent à contrôler avant de promettre une recherche exhaustive.

## Parcours attendus

- Le code/nom d’un objet et son bouton Consulter ouvrent la même fiche 360 depuis liste, recherche ou détail lié.
- Une valeur d’indicateur ayant un détail ouvre cette population exacte, ou son registre avec un filtre visible et effaçable. La carte et le lien de détail partagent le même contrat.
- ConsultationProvider fournit Produit 360 et Bon de stock 360, avec rubriques liées à la demande. Les fiches Facture/Règlement et Tiers dédiées restent à construire.
- Toute fenêtre latérale métier de ce type utilise DrawerDialog et propose les commandes communes Réduire, Élargir, Rétablir la largeur et Fermer, avec les mêmes icônes. Conserver poignée, clavier, adaptation mobile et retour au contexte, conformément à la référence. Cette règle couvre aussi les réglages, pas seulement les consultations 360.
- La consultation charge uniquement l’objet sélectionné, puis ses rubriques à la demande si volumineuses. Ne pas lancer une requête 360 pour chaque ligne du tableau.

## Invariants d’interface

1. Conserver filtres appliqués, page, sélection et position lors de l’ouverture/fermeture d’une fiche. Restituer le focus au déclencheur.
2. Distinguer saisie et filtres appliqués. Le compteur et l’export décrivent les critères effectivement envoyés au serveur.
3. Préserver recherche, tri, pagination, colonnes visibles/gelées/redimensionnables et sélection déjà disponibles ; mutualiser leur comportement avant d’ajouter des variantes.
4. Placer la taille de page et les commandes d’affichage au-dessus du tableau. Les totaux viennent dessous. Les actions principales et exports restent alignés aux filtres quand la largeur le permet.
5. Garder les groupes d’indicateurs analytiques repliés par défaut dans les registres ; un affichage ou repli ne change aucun filtre ni montant. Les cartes du tableau de bord principal restent selon le parcours de pilotage retenu. L’en-tête du tableau de bord ne présente ni Actualiser ni Nouveau bon de stock ; les créations se font dans les registres.
6. Valeur inconnue = — ou Non déterminable ; zéro seulement s’il vient de la source. Devise, unité, période et réserves indispensables restent visibles.
7. Ne pas réutiliser le USD codé en dur de formatCurrency comme preuve de la devise d’un objet. Faire évoluer le contrat de données avant de prétendre gérer plusieurs devises.
8. Menus et boutons suivent les permissions reçues ; le backend reste responsable du refus effectif. Traiter 401, 403, indisponibilité et conflit avec un état explicite.
9. Aucun bouton fictif ou sélecteur sans effet réel : raccorder l’action ou rendre son indisponibilité compréhensible. Les chiffres de démonstration restent identifiés et fictifs.
10. Les aides, cases de sélection et actions d’une ligne arrêtent la propagation quand elle ouvrirait une autre consultation. Utiliser de vrais liens/boutons avec focus visible.

## Navigation logistique livrée

Conserver la colonne de gauche sur toute la hauteur : logo, menus à icônes regroupés en Pilotage/Stocks/Finances, rubrique active visible, retour aux applications, repli sur ordinateur et rail compact sur mobile. Le propriétaire demande le parcours Numérique–M-PESA : blocs Articles/Bons de stock/Factures/Alertes avec mini-indicateurs compacts (éviter les grandes tuiles), clic sur un KPI, détail dans une liste sous la synthèse, recherche validée, pagination serveur, puis Revenir à l’indicateur ou fermeture avec défilement/focus au déclencheur. Une fiche 360 consulte uniquement un enregistrement précis depuis ce détail ou un autre onglet.

Lire [la terminologie du stock](references/terminologie-stock.md) pour les noms de menus, documents, tiers et mouvements. Les noms techniques T_Commande et /commandes restent internes.

## Présentation

TailAdmin React est la référence visuelle demandée par le propriétaire pour le login, Vos applications et les modules. Conserver les principes d’interaction d’imf_BB : indicateurs vers liste intégrée, puis fiche 360 d’un enregistrement. Préserver la marque SauverNdeko, les mini-indicateurs compacts, le menu bleu ardoise et les styles partagés. Lire la référence visuelle avant une évolution de présentation.

Le propriétaire demande de retirer Sources et calcul du tableau de bord et de ses listes détaillées. Conserver les définitions et la traçabilité côté serveur et dans les exports, sans afficher les noms SQL dans le parcours métier. AppIcon et ActionButton centralisent les icônes et boutons : Réinitialiser utilise reset, tous les téléchargements utilisent download. Un bouton de format apparaît uniquement si son export est réellement raccordé.

## Vérification

Le package frontend déclare build, dev et preview, sans script test. Pour une modification réelle, npm run build vérifie le bundling ; compléter par les interactions utiles à la tâche sur données fictives. Vérifier ordinateur, largeur intermédiaire et mobile, clavier, zoom réel, retour au focus, annulation, erreur et parité des filtres/détails/exports. Une compilation seule ne valide pas les droits, la précision d’un KPI ou l’ergonomie d’une fenêtre.

## Ton des interfaces

Le propriétaire a validé l’accueil par applications, inspiré d’Odoo. Préserver cette présentation et employer des libellés courts, humains et professionnels. Retirer les textes qui ressemblent à des consignes de conception, les mentions de backend/JWT et les explications techniques inutiles. Les descriptions utiles restent brèves ; les explications de calcul sont repliées.

## Thèmes

ThemeContext fournit Clair, Sombre, Contraste élevé et Système. ThemePicker est présent à la connexion, sur l’accueil et dans ModuleHeader. La préférence sauverndeko.theme est locale au navigateur ; aucun appel métier ni écriture PostgreSQL n’est associé à un changement de thème. Le thème Système suit prefers-color-scheme. Conserver le menu bleu ardoise contrasté dans la présentation claire par défaut. Centraliser les couleurs dans theme.css et vérifier tableaux, formulaires et fiches 360 dans les modes proposés.
