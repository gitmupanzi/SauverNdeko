# Logistique — travaux restants

État au 26 octobre 2026. Ce relevé distingue les développements encore nécessaires des vérifications de livraison. Il complète la [trajectoire ERP](../skills/sauverndeko-erp/references/trajectoire-erp.md).

## Déjà livré

- Articles : formulaire commun ajout/modification, Produit 360, photo, informations complémentaires, poids/unité, devise du référentiel et réception préremplie.
- Bons de stock et lignes : composition depuis le catalogue, codes automatiques, édition commune, consultations liées, réceptions, sorties et restitutions partielles avec un seul effet sur le stock.
- Factures et règlements séparés : instantanés de facturation, paiements et préparation groupée, avoirs après retour facturé, imputations et remboursements enregistrés.
- PDF des bons d’entrée/sortie/livraison, factures, reçus et avoirs ; justificatifs privés ; identités des documents financiers conservées.
- Clients et fournisseurs via T_Client et Type de personne du référentiel, Tiers 360, référence du tiers dans les bons, destinations géographiques normalisées.
- Propriété durable par Entité, contexte d’entreprise du compte global, droits serveur et dossiers personnalisés privés.
- Inventaires physiques, écarts justifiés, validation et annulation motivée avec mouvements compensateurs ; quantités fractionnaires selon la précision de l’unité dans le référentiel générique.
- Lots facultatifs, contrôle des budgets et proposition de sortie par péremption ; tableaux, exports et filtres catégoriels recherchables communs.

## Développements prioritaires

| Priorité | Travail | Résultat attendu pour clôturer |
|---|---|---|
| P1 | Valorisation CUMP | Valider la méthode avec le responsable comptable et les coûts d’ouverture ; calculer le coût moyen après réception et la valeur des sorties/retours/corrections, par article, entreprise et devise. Traiter les corrections rétroactives et l’arrondi, conserver les coûts justifiables et vérifier la concordance des vues, documents et exports. Le prix catalogue actuellement utilisé ne constitue pas un coût moyen comptable. |
| P1 | Péremption exhaustive par lot | Faire reposer les alertes, dossiers, détails et exports sur les lots disposant réellement de stock ; conserver le traitement du stock sans lot. Définir seuils, blocage éventuel des lots périmés et dérogations motivées selon le secteur et les droits. La proposition par péremption existe déjà ; la colonne de date générale de l’article ne suffit pas au suivi exhaustif. |
| P2 | Performance de l’interface | Réduire le chargement initial par découpage des pages et consultations ; mesurer les listes, indicateurs et exports sur un volume représentatif. La compilation passe, avec un avertissement sur un fichier JavaScript d’environ 1 Mo avant compression. |

## Vérifications avant livraison client

| Priorité | Vérification ouverte | Critère de clôture |
|---|---|---|
| P1 | Envoi Gmail et récupération du mot de passe | Réussir un envoi réel autorisé et recevoir le lien sur une boîte de recette ; vérifier expiration et usage unique. Les derniers essais documentés ont été interrompus pendant le dialogue SMTP ; configuration présente ne signifie pas délivrance validée. |
| P1 | Installation et déploiement | Tester une installation vierge et une mise à jour avec les migrations requises ; formaliser leur ordre et les prérequis. Préparer un serveur de production, HTTPS, paramètres privés et journalisation ; les lanceurs Django/Vite actuels servent au développement local. |
| P1 | Sauvegarde et restauration | Restaurer une sauvegarde dans un environnement isolé et vérifier stock, documents, identités et justificatifs. Sauvegarder également les fichiers media des photos ; la lecture du catalogue d’une sauvegarde ne suffit pas à prouver une restauration complète. |
| P1 | Paramétrage de l’entreprise cliente | Renseigner l’identité réelle de l’Entité, ses coordonnées, utilisateurs, licences et droits. Valider les données de reprise et les règles fiscales applicables sans inventer un taux ou une mention légale. |
| P1 | Recette utilisateur de la chaîne complète | Faire valider réception → sortie → restitution → facture → règlement → avoir → imputation/remboursement, avec quantités fractionnaires et lots lorsque pertinents. Inclure deux entreprises, accès global, permissions, doubles clics et erreurs réseau, sans utiliser de données fictives dans la base réelle. |
| P2 | Recette visuelle et accessibilité | Contrôler les filtres catégoriels récemment harmonisés et les autres parcours sur ordinateur/mobile, thèmes, clavier et retour au contexte. Vérifier les PDF avec l’identité cliente et des tableaux longs. |

## Extensions à cadrer séparément

La modernisation des autres modules (Administration, Référentiels, Organisation territoriale, catalogue santé et discussions) et les fonctions de multi-dépôts/transferts, cycle achats/ventes complet ou comptabilité générale relèvent d’une phase ERP à cadrer avec le client. Leur présence dans la trajectoire ne signifie pas qu’elles sont livrées. Le suivi des règlements ne remplace pas une comptabilité générale.

## Vérifications déjà obtenues

Les documents et avoirs ont passé 102 contrôles métier sur des données fictives dans une base privée, dont rejeu et remboursements concurrents. Après installation, 174 routes existantes et 24 contrôles réels des nouvelles fonctions ont réussi en lecture seule. Les quantités et le journal de stock sont restés inchangés lors des migrations. Les PDF ont été rendus et inspectés, dont un tableau de cinq pages. La dernière harmonisation des filtres catégoriels a compilé avec succès. Ces preuves ne remplacent pas la recette de livraison ci-dessus.

Le 26 octobre : centralisation des précisions dans T_Generique, destinations préfixées par leur type, ordres de colonnes harmonisés et annulation traçable des inventaires. Les 31 contrôles dédiés à l’annulation ont passé sur une base privée ; 176 routes GET ont passé sur SauverNdeko en lecture seule. Les 22 tables métier contrôlées sont restées identiques pendant les migrations. La recette utilisateur de livraison reste à réaliser.

Sources locales : [documents et avoirs](../SQL/documentation/Documents_Avoirs_20261025.md), [Entités, tiers et stock](../skills/sauverndeko-erp/references/entites-tiers-et-stock.md), [lancement et messagerie](lancement-local.md), [règles frontend](../frontend/skills/develop-sauverndeko-frontend/references/formulaires-crud.md).
