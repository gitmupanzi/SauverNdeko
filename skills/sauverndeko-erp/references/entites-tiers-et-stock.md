# Entités, tiers et stock : règles retenues

Décisions du 25 octobre 2026, après examen des sources. Le propriétaire a demandé de retenir le meilleur usage pour les collaborateurs et de conserver son accès global. Cette référence décrit la cible à implémenter ; sa présence ne signifie pas que les tables, autorisations ou écrans ci-dessous sont installés.

## Visibilité et travail en entreprise

- Les articles, tiers et documents sont partagés dans leur entreprise selon les droits du rôle. Ne pas les rendre privés au seul créateur : la continuité du travail doit rester possible entre magasinier, responsable et comptable habilités.
- Les actions restent distinctes : consulter, créer, modifier, réceptionner, restituer, facturer et régler. Ne pas accorder automatiquement toutes ces actions à un utilisateur parce qu'il appartient à l'entreprise ou voit le module.
- Chaque écriture conserve son auteur réel, sa date et son entreprise. La propriété de l'entreprise ne remplace pas la traçabilité de l'utilisateur.
- Les dossiers de suivi personnalisés restent privés au couple utilisateur–Entité, conformément au parcours existant. Ne pas ouvrir les dossiers personnels par un changement général de portée sur les documents collaboratifs.
- La licence appartient à l'Entité ; les applications effectives restent limitées par la licence et le rôle pour les comptes ordinaires.

## Administrateur global et entreprise active

Le compte de plateforme, identifié par Is_Admin, conserve un seul login et l'accès à toutes les entreprises. Is_staff ou un rôle d'administrateur d'entreprise ne confèrent pas cette portée.

Prévoir Toutes les entreprises pour la consultation globale et une Entreprise active explicite pour une création. Sur un document existant, l'entreprise cible est celle du document. Le serveur valide le contexte et toutes les références ; un identifiant envoyé par le navigateur ne suffit pas à choisir une autre entreprise pour un utilisateur ordinaire.

Le contexte cible est distinct de l'identité authentifiée : ne pas remplacer l'auteur par un utilisateur local, modifier l'Entité du compte de plateforme, ou mélanger les articles de plusieurs entreprises dans un bon. Un changement d'entreprise ne transporte pas un panier ou des sélections dans l'autre contexte ; protéger les saisies en cours et ignorer les réponses de l'ancien contexte.

Le contournement global des filtres de lecture et licences existe déjà. Les services de composition, réception, restitution et facturation contrôlent encore actor.organisation ; ils ne permettent donc pas encore toutes les opérations interentreprises. Remplacer ces contrôles par un contexte cible validé, sans les supprimer simplement.

## Propriété durable

Ajouter une FK d'Entité propriétaire obligatoire et immuable aux racines métier, notamment Article, Commande et Client. Les lignes, lots, mouvements, factures, avoirs et règlements doivent rester cohérents avec leurs parents et l'article concerné. Conserver les protections métier, devises et verrouillages pendant cette évolution.

Actuellement, une partie de la portée Article/Commande est déduite de T_Utilisateurs.IdEntiteFk. Un changement d'affectation du créateur ne doit plus déplacer l'historique. Le trigger de facture doit aussi utiliser l'entreprise du bon plutôt que celle du créateur actuel.

Pour la reprise, analyser les liens existants avant d'attribuer une entreprise ; signaler les objets orphelins ou contradictoires. Ne pas attribuer arbitrairement les cas non résolus à l'entreprise de l'administrateur global. Les PDF et pièces justificatives suivent la même entreprise. Les instantanés d’identité émis, tiers et montants historiques restent conservés ; depuis la demande du 28/10/2026, la présentation de l’émetteur des PDF générés ou régénérés utilise le profil courant. Les fichiers archivés restent inchangés. Appliquer la [charte d’identité PDF](../../document-mise-en-forme/references/charte_documentaire.md).

## Référentiel de clients et fournisseurs

Nom technique demandé : logistique.T_Client. Nom d'interface retenu : Clients et fournisseurs ; une fiche peut jouer les deux rôles. Réutiliser le référentiel générique pour les natures et rôles pertinents, sans identifiants numériques figés ni nouvelle table de catégories propre à chaque écran.

Le modèle doit distinguer :

| Relation | Signification |
|---|---|
| Clé propre du client | Identité stable du tiers dans le référentiel logistique |
| Entité propriétaire obligatoire | Entreprise qui gère cette fiche ; ne désigne pas le client lui-même |
| Auteur de création et de modification | Utilisateur réel ayant effectué l'opération |
| Compte utilisateur facultatif | Compte existant du tiers, s'il possède un accès ; aucun compte ou mot de passe requis pour créer une fiche |
| Professionnel facultatif | Identité professionnelle existante, si pertinente ; ses affiliations ne déterminent pas le propriétaire de la fiche |
| Entité représentée facultative | Autre entreprise déjà enregistrée, lorsque le tiers la représente ; distincte de l'Entité propriétaire |

Prévoir personne physique ou entreprise, nom, contacts, état actif et informations utiles. Si compte et professionnel sont tous deux renseignés, vérifier leur cohérence avec T_Professionnel.IdUserFk. Ne pas imposer une identité sanitaire aux autres secteurs ni une unicité globale de l'e-mail entre entreprises. Une même personne peut être cliente de plusieurs entreprises sans leur partager leurs historiques.

Les anciens ID_ClientFk ne prouvent pas une FK vers T_Entite. Le catalogue actuel rapproche certains nombres d'Entité par égalité d'identifiant. Préparer une correspondance contrôlée par entreprise et ancien identifiant, conserver le nom saisi et les références historiques ; ne pas convertir les liens par simple égalité numérique ou ressemblance de nom.

Le même catalogue alimentera bons, réceptions, factures et règlements. La fiche Tiers 360 présentera identité, bons, factures et règlements par clés vérifiées, jamais par recherche de nom. Réutiliser tableaux, SearchSelect, DrawerDialog et formulaire commun ajout/modification. Une création rapide autorisée conserve le panier du document.

## Numéros de lot

Conserver T_LotArticle et les ventilations de mouvements : un article peut être reçu dans plusieurs lots, et une seule colonne sur Article écraserait ou mélangerait ces identités.

Le parcours reste simple : N° de lot facultatif pour les produits qui n'en nécessitent pas ; saisie lors de la réception, puis sélection des lots réellement disponibles lors de la sortie. La part sans lot reste autorisée lorsqu'elle est couverte par du stock sans lot. Les lots déjà utilisés et leur historique sont conservés.

La gestion de péremption, les propositions par date d'expiration et les éventuels blocages constituent une évolution configurable selon le secteur. Ne pas transformer la simple présence d'un numéro de lot en obligation universelle de péremption. La couverture sans lot et les budgets par lot doivent continuer à empêcher une sortie incohérente ou un double mouvement.

## État et validation de l'implémentation

Au moment de cette décision : T_Client et Tiers 360 restent à construire ; les FK propriétaires durables et le contexte d'écriture global restent à installer. Les lots et la vérification de leurs budgets existent. Ne pas annoncer la cible comme livrée après une seule mise à jour documentaire.

Pour la future migration et son API, vérifier sur données fictives : deux entreprises ne voient pas leurs tiers/documents réciproques ; les collaborateurs habilités partagent les objets de leur entreprise ; les droits d'action restent distincts ; le global consulte et agit dans chaque entreprise sans mélange ; changer l'affectation d'un créateur ne déplace pas les objets ; les FK, pièces et exports respectent le même périmètre. Les scénarios de réception/sortie/retour conservent un seul effet sur le stock.

Sources à relire avant implémentation : backend/apps/accounts/authentication.py, backend/apps/core/permissions.py, backend/apps/core/module_access.py, backend/apps/core/models.py, backend/apps/logistique/order_composer.py, receipts.py, stock_returns.py, invoices.py, services.py, followup_folders.py et backend/database/migrations/20261025_07_factures_snapshots.sql. Toute modification SQL conserve vues communes, contraintes, index et COMMENT ON versionnés.

## Installation vérifiée le 25 octobre 2026

Les migrations 09, 10 et 13 sont installées après sauvegarde : propriété durable des articles et bons, contexte d’entreprise global, T_Client et Tiers 360, Type de client dynamique dans Type de personne, références ID_TiersFk, destinations normalisées et inventaires physiques. Les quantités fractionnaires suivent un réglage explicite de précision par unité ; les lots ont une proposition de sortie par péremption, sans ventilation silencieuse. Le compte global reste sans Entité de compte ; les données existantes sont rattachées à l’Entité initiale 9 conservée sans renommage. Le journal de stock n’a reçu aucun mouvement lors de la migration.

Les sections de conception précédentes restent la justification du choix ; leurs mentions de travaux à construire décrivent le constat avant cette installation. Les migrations 11 et 12 complètent les documents PDF et justificatifs privés, puis les avoirs, imputations et remboursements. Les vérifications couvrent le cycle métier et les doubles demandes ; les soldes nets viennent de V_Facture et sont repris sans seconde déduction dans V_Commande et V_SuiviReglements. La valorisation CUMP reste à construire ; le prix catalogue ne doit pas être annoncé comme un coût moyen comptable.

## Références et inventaires — règles appliquées le 26 octobre 2026

La précision du stock appartient à logistique.T_PrecisionStock : exactement quatre colonnes, ID_PrecisionStock, ID_UniteFk, DecimalesStock et ModifieLe. La FK réelle ID_UniteFk désigne la même valeur de la catégorie Unités de referentiel.T_Generique que T_Article.ID_UniteFk. La vue commune V_PrecisionStock fournit la précision, avec zéro décimale pour une nouvelle unité non paramétrée. Ne pas réintroduire ces paramètres dans T_Generique ni créer une autre nomenclature d’unités. Le réglage est partagé, verrouillé avec les validations de quantités et compatible avec l’historique ; sa modification ne produit aucun effet de stock. La migration 20261026_10 conserve les réglages existants, initialise les unités actives sans réglage explicite à zéro et ne retire les anciennes colonnes qu’après reprise contrôlée ; vérifier son installation avant d’utiliser le nouveau contrat.

Les destinations se lisent dans V_DestinationLogistique : chaque niveau présente son type provenant de la FK réelle vers T_Generique, puis son nom. Ne pas supposer que tous les niveaux sont des AS ou ZS ; conserver les abréviations renseignées et la hiérarchie pour distinguer les homonymes.

Un inventaire validé ne se supprime pas. Annuler la validation exige un motif, les droits de gestion et le périmètre d’entreprise. Les bons compensateurs inversent exactement les mouvements et lots d’origine, avec leur prix et devise ; les triggers existants sont seuls responsables du stock. Refuser atomiquement si les quantités nécessaires ne sont plus disponibles. Préserver l’audit, l’UUID de rejeu, le verrouillage concurrent et l’état Annulé définitif. Le registre et sa consultation exposent les liens d’origine et de compensation.
