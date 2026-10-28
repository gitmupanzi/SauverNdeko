---
name: develop-sauverndeko-frontend
description: Faire évoluer les interfaces React de SauverNdeko vers des parcours ERP modernes, avec tableaux cohérents, indicateurs consultables et fiches 360 accessibles. Utiliser pour navigation, formulaires, filtres, consultations produit/commande et présentation des données API.
---

# Frontend SauverNdeko

Lire les [consignes du projet](../../../skills/AGENTS.md) avant une intervention.

## Références

- [Architecture existante](references/architecture.md) pour les composants, routes, helpers et limites du code actuel.
- [Référence visuelle](references/design-reference.md) pour l’accueil, le login, les blocs du tableau de bord et les tableaux inspirés de TailAdmin.
- [Champs, filtres métier et CRUD Articles](references/formulaires-crud.md) pour le standard SearchSelect, les fenêtres latérales, photos, poids et lots : base des futurs onglets.
- [Contrats d’interface](references/contrats-interface.md) pour tableaux, indicateurs, fenêtres 360, filtres, exports et recette.
- [Entités, tiers et stock](../../../skills/sauverndeko-erp/references/entites-tiers-et-stock.md) pour le partage par entreprise/rôle, le futur contexte global, Clients et fournisseurs et la simplicité des lots facultatifs. Distinguer cette cible des écrans installés.
- [Skill transverse ERP](../../../skills/sauverndeko-erp/SKILL.md) pour un changement entre plusieurs domaines.
- [Skill backend](../../../backend/skills/develop-sauverndeko-backend/SKILL.md) dès qu’un nouveau filtre, calcul ou détail API est requis.

- Pour les exports Excel, Word et PDF : [skill documentaire SauverNdeko](../../../skills/document-mise-en-forme/SKILL.md). Réutiliser la charte et le contrat de parité sans recalcul métier propre au format.

## Entrée de l’application

Le propriétaire demande le login comme écran d’entrée. App.jsx attend la restauration de session, présente /login aux visiteurs sans session et conserve les destinations internes pour le retour après connexion. Le shell et le catalogue se chargent après authentification ; l’inscription libre est fermée. Ne pas rétablir une page d’accueil anonyme par défaut. Django impose aussi l’authentification sur le catalogue et fournit les modules autorisés par /api/workspace/modules. Conserver les contrôles d’objet et de périmètre sur chaque route.

## Profil et récupération d’accès

Conserver /reset-password hors de ModuleGate et accessible sans session : cette exception ouvre uniquement la récupération, aucun module métier. Le parcours retenu est adresse e-mail, lien à usage unique, puis nouveau mot de passe confirmé. Réutiliser le style du login, ThemePicker et les champs masqués avec commande d’affichage. Une indisponibilité du service ne doit jamais annoncer un envoi réussi.

Le lien de récupération arrive dans le fragment ; conserver uid/token seulement en mémoire, nettoyer immédiatement l’URL et transmettre les vérifications par POST. Prendre en compte un nouveau lien reçu sur la page déjà ouverte sans mélanger les brouillons ni appliquer une ancienne réponse. Les mots de passe ne sont ni normalisés ni conservés dans le stockage du navigateur.

Dans Mon profil, la rubrique Sécurité utilise PasswordEditor et les protections communes de RecordEditorFrame. Le changement personnel exige le mot de passe actuel et reste indépendant des licences métier. Après réussite, fermer la session locale puis demander une reconnexion ; une réponse de restauration tardive ne doit pas rétablir l’ancienne session.

Administration → Messagerie utilise AdminMailSettings, réservé aux administrateurs de plateforme. Il modifie le nom et l’adresse expéditrice, jamais le secret Google. Le défaut demandé est SauverNdeko <benjaminmupanzi@gmail.com>. Pour le transport et les contrats serveur, lire [la référence backend de messagerie](../../../backend/skills/develop-sauverndeko-backend/references/messagerie-reinitialisation.md).

## Pile et responsabilités

Conserver React 19 en JSX, React Router, Vite, Bootstrap et Bootstrap Icons présents dans le projet. Les principes d’imf_BB sont à reproduire dans cette pile ; ne pas imposer sa migration TypeScript. Le backend est Django/DRF avec les JWT existants ; ne pas remplacer la session React par des cookies Django sans décision dédiée. Ajouter une dépendance seulement pour un besoin réel.

React présente les données autorisées et pilote les interactions. Les mesures métier, droits, recherches exhaustives, totaux et exports complets viennent du serveur. Le nouveau dashboard et les registres Articles/Bons de stock utilisent les lectures paginées et agrégats de apps/logistique/reads.py. Les autres registres historiques restent à contrôler avant de promettre une recherche exhaustive.

## Parcours attendus

- Le code/nom d’un objet et son bouton Consulter ouvrent la même fiche 360 depuis liste, recherche ou détail lié.
- Une valeur d’indicateur ayant un détail ouvre cette population exacte, ou son registre avec un filtre visible et effaçable. La carte et le lien de détail partagent le même contrat.
- ConsultationProvider fournit Produit 360 et Bon de stock 360, avec rubriques liées à la demande. Une facture ouvre directement la rubrique Facturation de Bon de stock 360 ; ReglementEditor fournit la consultation et le formulaire commun des paiements. La fiche Tiers 360 utilise le même principe de parent autorisé et de rubriques liées.
- Toute fenêtre latérale métier de ce type utilise DrawerDialog et propose les commandes communes Réduire, Élargir, Rétablir la largeur et Fermer, avec les mêmes icônes. Conserver poignée, clavier, adaptation mobile et retour au contexte, conformément à la référence. Cette règle couvre aussi les réglages, pas seulement les consultations 360.
- La consultation charge uniquement l’objet sélectionné, puis ses rubriques à la demande si volumineuses. Ne pas lancer une requête 360 pour chaque ligne du tableau.

## Invariants d’interface

1. Conserver filtres appliqués, page, sélection et position lors de l’ouverture/fermeture d’une fiche. Restituer le focus au déclencheur.
2. Distinguer saisie et filtres appliqués. Le compteur et l’export décrivent les critères effectivement envoyés au serveur.
3. Préserver recherche, tri, pagination, colonnes visibles/gelées/redimensionnables et sélection déjà disponibles ; mutualiser leur comportement avant d’ajouter des variantes.
4. Placer la taille de page et les commandes d’affichage au-dessus du tableau. Les totaux viennent dessous. Les actions principales et exports restent alignés aux filtres quand la largeur le permet.
5. Garder les groupes d’indicateurs analytiques repliés par défaut dans les registres ; un affichage ou repli ne change aucun filtre ni montant. Les cartes du tableau de bord principal restent selon le parcours de pilotage retenu. L’en-tête du tableau de bord ne présente ni Actualiser ni Nouveau bon de stock ; les créations se font dans les registres.
6. Valeur inconnue = — ou Non déterminable ; zéro seulement s’il vient de la source. Devise, unité, période et réserves indispensables restent visibles.
7. Les prix et montants logistiques portent la devise du référentiel reçue par l’API (ID_DeviseFk, DeviseCode). Le défaut USD des créations est résolu par defaultCurrencyId, sans identifiant numérique encodé. Utiliser formatCurrency avec le code de la ligne et conserver les chaînes décimales exactes ; aucune conversion de change implicite. Les totaux et détails monétaires se regroupent par devise ; une devise absente reste distincte de zéro. La reprise des anciens montants en USD résulte d’une migration explicitement autorisée, jamais d’un fallback d’affichage.
8. Menus et boutons suivent les permissions reçues ; le backend reste responsable du refus effectif. Traiter 401, 403, indisponibilité et conflit avec un état explicite.
9. Aucun bouton fictif ou sélecteur sans effet réel : raccorder l’action ou rendre son indisponibilité compréhensible. Les chiffres de démonstration restent identifiés et fictifs.
10. Les aides, cases de sélection et actions d’une ligne arrêtent la propagation quand elle ouvrirait une autre consultation. Utiliser de vrais liens/boutons avec focus visible.
11. Tout filtre métier catégoriel et toute référence à choix simple réutilisent SearchSelect, comme Licence et Article. Appliquer le [contrat des sélecteurs](references/formulaires-crud.md#sélecteurs-des-filtres-métier-et-références) ; conserver les contrôles adaptés aux réglages techniques et à la multisélection.
12. Afficher la date et l’heure des événements horodatés, sans ajouter d’heure aux dates seules ; appliquer le [contrat des dates et heures](references/contrats-interface.md#dates-et-heures).

## Navigation logistique livrée

Conserver la colonne de gauche sur toute la hauteur : logo, menus à icônes regroupés en Pilotage/Stocks/Finances, rubrique active visible, deux entrées Finances distinctes Factures et Règlements, retour aux applications, repli sur ordinateur et rail compact sur mobile. Le propriétaire demande le parcours Numérique–M-PESA : blocs Articles/Bons de stock/Factures/Alertes avec mini-indicateurs compacts (éviter les grandes tuiles), clic sur un KPI, détail dans une liste sous la synthèse, recherche validée, pagination serveur, puis Revenir à l’indicateur ou fermeture avec défilement/focus au déclencheur. Une fiche 360 consulte uniquement un enregistrement précis depuis ce détail ou un autre onglet.

Lire [la terminologie du stock](references/terminologie-stock.md) pour les noms de menus, documents, tiers et mouvements. Les noms techniques T_Commande et /commandes restent internes.

## Présentation

TailAdmin React est la référence visuelle demandée par le propriétaire pour le login, Vos applications et les modules. Conserver les principes d’interaction d’imf_BB : indicateurs vers liste intégrée, puis fiche 360 d’un enregistrement. Préserver la marque SauverNdeko, les mini-indicateurs compacts, le menu bleu ardoise et les styles partagés. Lire la référence visuelle avant une évolution de présentation.

La charte commune couvre Connexion, Vos applications, Découvrir les applications, Licences et applications, Tableau de bord logistique, Articles, Dossiers de suivi, Bons de stock, Lignes des bons, Mouvements de stock, Factures et règlements et les consultations 360. Les futurs écrans reprennent leurs composants, tokens, états et interactions ; éviter une variante de présentation propre à chaque onglet.

Les sous-onglets de consultation utilisent [ConsultationTabs](../../src/components/ConsultationTabs.jsx), partagé entre profil et fiches métier : barre compacte, icônes communes, onglet actif visible et navigation au clavier. La modernité comprend le contenu lié à l’objet sélectionné, le chargement à la demande et la conservation du contexte, au-delà du seul style. Voir les [références et le contrat des onglets](references/design-reference.md#sous-onglets-de-consultation).

Le propriétaire demande de retirer Sources et calcul du tableau de bord et de ses listes détaillées. Conserver les définitions et la traçabilité côté serveur et dans les exports, sans afficher les noms SQL dans le parcours métier. AppIcon et ActionButton centralisent les icônes et boutons : Réinitialiser utilise reset, tous les téléchargements utilisent download. Un bouton de format apparaît uniquement si son export est réellement raccordé.

## Vérification

Le package frontend déclare build, dev et preview, sans script test. Pour une modification réelle, npm run build vérifie le bundling ; compléter par les interactions utiles à la tâche sur données fictives. Vérifier ordinateur, largeur intermédiaire et mobile, clavier, zoom réel, retour au focus, annulation, erreur et parité des filtres/détails/exports. Une compilation seule ne valide pas les droits, la précision d’un KPI ou l’ergonomie d’une fenêtre.

## Ton des interfaces

Le propriétaire a validé l’accueil par applications, inspiré d’Odoo. Préserver cette présentation et employer des libellés courts, humains et professionnels. Retirer les textes qui ressemblent à des consignes de conception, les mentions de backend/JWT et les explications techniques inutiles. Les descriptions utiles restent brèves ; les explications de calcul sont repliées.

## Thèmes

ThemeContext fournit Clair, Sombre, Contraste élevé et Système. ThemePicker est présent à la connexion, sur l’accueil et dans ModuleHeader. La préférence sauverndeko.theme est locale au navigateur ; aucun appel métier ni écriture PostgreSQL n’est associé à un changement de thème. Le thème Système suit prefers-color-scheme. Conserver le menu bleu ardoise contrasté dans la présentation claire par défaut. Centraliser les couleurs dans theme.css et vérifier tableaux, formulaires et fiches 360 dans les modes proposés.

ThemePicker affiche uniquement l’icône du choix : soleil pour Clair, lune pour Sombre, demi-cercle pour Contraste élevé et écran pour Système. Le bouton rond (40 px, 34 px sur mobile) ouvre un menu personnalisé compact utilisant les tokens de thème. Chaque choix porte son icône et un libellé ; le choix actif est coché et exposé comme sélection radio. Conserver le titre actualisé, le focus visible, les flèches haut/bas, Début/Fin et Échap. Un choix ou Échap restitue le focus au bouton ; le clic extérieur ferme le menu. Adapter son positionnement au mobile ; aucun texte ni flèche ne reste affiché sur le bouton.

## Outils et relevés historiques

Les anciennes références [frontend-architecture.md](references/frontend-architecture.md), [api-and-ui-contracts.md](references/api-and-ui-contracts.md) et [validation.md](references/validation.md) conservent le relevé antérieur à la conversion Django. Les références précédentes décrivent les conventions actuelles. L’[inspecteur statique](scripts/inspect_frontend.py) peut aider à repérer composants et services ; son inventaire partiel des routes ne valide ni les ModuleGate conditionnels ni les permissions.

## Documents métier et avoirs

Réutiliser BusinessDocuments pour PDF et justificatifs privés ; conserver les états de chargement, reprise du téléchargement échoué et protection des réponses obsolètes après changement d’entreprise. Utiliser le formulaire CreditNotes partagé pour émission, imputation et remboursement ; la consultation reste en lecture avec un bouton Fermer. Une réponse incertaine conserve le même identifiant et le même contenu pour vérification. Afficher les montants exacts fournis par le serveur et distinguer encaissements, avoirs imputés, remboursements et solde disponible. Aucun transfert bancaire n’est exécuté par l’enregistrement d’un remboursement.

## Paramétrage documentaire et livraison

Administration → Entreprises et EntityDocumentIdentity réutilisent EntityProfileEditor : mêmes rubriques Coordonnées, Identifiants légaux et Documents, mêmes validations et protection des modifications non enregistrées. Les types d’entreprise viennent des références de l’API, sans catégorie numérique figée. Seule l’administration de plateforme peut créer une entreprise ou modifier son type et son état ; l’identité documentaire respecte les droits de l’entreprise choisie. Réutiliser la révision figée et le même UUID/contenu lors d’une réponse incertaine ; rafraîchir le sélecteur d’entreprise après sauvegarde, sans recharger la page.

Dans ce formulaire, une modification autorisée active Enregistrer. Un champ obligatoire manquant, dont le motif conservé dans l’historique, produit un message explicite et reçoit le focus à la soumission ; ne pas laisser le bouton silencieusement désactivé pour cette raison. Le motif ne change pas le sous-onglet courant. Conserver les blocages de permissions, de chargement et de double soumission, ainsi que le rejeu identique d’une demande incertaine.

Les coordonnées proposent un téléphone principal et un téléphone secondaire facultatif (`PhoneSecondaireEntite`, 20 caractères maximum), sans numéro inventé. Ils suivent le même formulaire partagé et sont présentés depuis le profil reçu du serveur.

Le logo est une image privée téléversée (PNG, JPEG ou WebP, 2 Mo maximum), avec aperçu authentifié, remplacement et retrait explicites. Le profil complet et le logo sont sauvegardés atomiquement ; aucun contenu binaire ni secret n’est placé dans le JSON, une URL distante ou le stockage du navigateur. Les identifiants légaux sont des couples libelle/valeur facultatifs, indépendants du pays : proposer RCCM, ID national et N° d’impôt comme libellés assistés, jamais comme valeurs inventées.

Afficher l’en-tête et Afficher le pied de page sont deux options indépendantes, vraies par défaut ; conserver explicitement une valeur false reçue. L’identité actuelle de l’entreprise est reprise lors de chaque impression et réimpression, tandis que les données financières historiques restent protégées côté serveur. Ne pas préremplir de coordonnées, références légales ou mentions fictives.

AdminMailSettings distingue configuration présente et connexion prouvée. Tester la connexion appelle un POST réservé à l’administration de plateforme, sans destinataire ni e-mail envoyé. Les valeurs par défaut viennent du compte d’envoi configuré, pas du compte utilisateur connecté. Une réussite du test ne prouve pas la réception d’un message.
