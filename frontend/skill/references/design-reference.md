# Référence visuelle SauverNdeko

Le propriétaire retient [TailAdmin React](https://react-demo.tailadmin.com/) comme référence de modernité, le 25 octobre 2026. S’en inspirer pour la cohérence, la lisibilité et les interactions ; conserver les contenus métier et la marque SauverNdeko dans la pile React JSX/Vite/Bootstrap existante.

## Références ciblées

- [Tableaux de données](https://react-demo.tailadmin.com/data-tables) : en-têtes sobres, séparateurs fins, recherche, pagination et actions alignées.
- [Tableau de bord](https://nextjs-demo.tailadmin.com/) : hiérarchie des cartes et densité maîtrisée.
- [Onglets](https://nextjs-demo.tailadmin.com/tabs) : rubrique active et groupes cohérents.
- [Profil](https://nextjs-demo.tailadmin.com/profile) : identité et informations structurées.
- [Formulaires](https://react-demo.tailadmin.com/form-layout) : libellés courts, champs lisibles, validation près du champ.
- [Fichiers](https://react-demo.tailadmin.com/file-manager) : présentation des pièces jointes lorsqu’un parcours réel de documents sera raccordé. Cette référence n’atteste pas un gestionnaire de fichiers livré.

## Application au projet

Le login utilise un formulaire compact et un panneau d’identité bleu ardoise sur ordinateur ; le formulaire reste seul sur mobile. Garder les contrôles d’authentification, le retour vers la destination autorisée, les états d’erreur et le support des gestionnaires de mots de passe. Ne pas ajouter de connexion sociale ou d’inscription sans parcours autorisé.

Vos applications garde la grille validée : icônes colorées, carte de module cliquable, recherche immédiate et modules reçus du serveur selon les autorisations. Le dashboard conserve quatre blocs repliables Articles, Bons de stock, Factures et Alertes, avec mini-indicateurs compacts. Le clic ouvre la liste en dessous et le retour restitue défilement et focus. Une fiche 360 concerne un enregistrement, pas la population du KPI.

Les tables privilégient des en-têtes clairs, texte contrasté, lignes séparées, valeurs numériques alignées à droite et statuts en pastilles avec leur libellé. Regrouper recherche, lignes, filtres, réinitialisation, densité, colonnes et export raccordé dans une barre. Sur petite largeur, les outils reviennent à la ligne et seul le tableau défile horizontalement.

Centraliser les couleurs dans les variables erp de theme.css. Vérifier Clair, Sombre, Contraste élevé, mobile et largeur intermédiaire. Une variation de thème ou de densité n’altère ni la requête, ni la sélection métier. Ne pas copier les données de démonstration, les logos, les textes commerciaux ou les contrôles sans effet de la référence.

## Correction demandée par le propriétaire

Le tableau de bord n’affiche pas Sources et calcul, y compris dans la liste sous un indicateur. La traçabilité reste disponible dans le contrat serveur et les métadonnées de l’export. Les quatre blocs sont disposés sur deux colonnes sur ordinateur puis une colonne sur petite largeur ; les mini-indicateurs ouvrent leur liste par un bouton unique qui occupe toute la carte.

La référence fournie pour les actions utilise Rechercher en vert, Réinitialiser et les formats en contour fin, avec une icône de réinitialisation et une même icône de téléchargement pour Excel, Word et PDF. AppIcon et ActionButton portent ce vocabulaire partagé pour éviter des variantes par écran. Conserver les formats réellement disponibles ; cette règle visuelle n’autorise pas à afficher des exports fictifs.
