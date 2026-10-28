# Logistique — livraison et travaux restants

État de livraison initial au 26 octobre 2026. Les corrections installées le 28 octobre — stock initial documenté, numérotation des nouveaux bons, préférences de tableaux/exports et traçabilité SQL des règlements — sont détaillées dans le [bilan du verdict logistique](verdict-logistique-20261028.md). Ce relevé complète la [trajectoire ERP](../skills/sauverndeko-erp/references/trajectoire-erp.md) et distingue les fonctions exécutées des validations externes encore nécessaires.

## Déjà livré

- Articles : formulaire commun ajout/modification, Produit 360, photo, informations complémentaires, poids/unité, devise du référentiel et réception préremplie.
- Bons de stock et lignes : composition depuis le catalogue, codes automatiques, édition commune, consultations liées, réceptions, sorties et restitutions partielles avec un seul effet sur le stock.
- Factures et règlements séparés : instantanés de facturation, paiements groupés, avoirs après retour facturé, imputations et remboursements enregistrés.
- PDF des bons d’entrée/sortie/livraison, factures, reçus et avoirs ; justificatifs privés ; identités financières conservées.
- Clients et fournisseurs dans T_Client, types issus du référentiel, Tiers 360, tiers référencé dans les bons et destinations géographiques typées.
- Propriété durable par Entité, contexte d’entreprise du compte global, droits serveur et dossiers personnalisés privés.
- Inventaires physiques, écarts justifiés, validation et annulation motivée avec mouvements compensateurs ; quantités fractionnaires selon `logistique.T_PrecisionStock`, liée aux unités du référentiel générique.
- Lots de stock : onglet après Articles, tous les lots y compris épuisés ou archivés, filtres et pagination serveur, export Excel et Lot 360 avec journal propre au lot. Les soldes sont calculés depuis les mouvements, sans saisie directe.
- Identité documentaire : réglage commun en consultation/modification, coordonnées et identifiants légaux facultatifs, motif, révision et rejeu de demande ; les nouveaux documents utilisent le profil confirmé et les instantanés émis restent immuables.
- Diagnostic de livraison en lecture seule : contrôle des licences, identités, stock/lots, CUMP, paramètres de déploiement et sauvegardes, avec actions à effectuer et éléments non vérifiés explicitement indiqués.
- COUSP : Entité créée, licence avec les neuf modules du catalogue actif du 26 octobre 2026 au 26 octobre 2031. Le rejeu du provisionnement ne prolonge pas la licence. Aucun utilisateur ou contact fictif ni transfert de données d’École Pilote Test.

## Développements prioritaires

| Priorité | Travail | État et suite |
|---|---|---|
| P1 | Valorisation CUMP | Calcul PostgreSQL installé par article, entreprise et devise : achats réels, sorties au coût moyen, retours au coût d’origine prouvé, corrections et arrondis. Consultation, réévaluation motivée, historique et Excel disponibles depuis Articles/Produit 360. **Les deux coûts d’ouverture existants restent à confirmer par le responsable comptable** ; les anciens prix de vente ne deviennent pas artificiellement des coûts. Le prix catalogue reste explicitement distinct. |
| P1 | Péremption exhaustive par lot | Installée : alertes, dossiers et détails utilisent les lots ayant réellement du stock et traitent aussi le stock sans lot. Seuils par article/entreprise, politique facultative de blocage des lots périmés et dérogation motivée réservée au compte global. Les lots épuisés restent visibles dans le registre historique sans gonfler les alertes de stock courant. |
| P2 | Performance de l’interface | Pages et consultations chargées à la demande ; shell et espaces de chargement conservés. JavaScript initial réduit d’environ 1 045 Ko à 361 Ko (115 Ko gzip). Recette sur deux entreprises de 5 000 mouvements : médianes locales CUMP 242 ms, Articles 124 ms, Bons 818 ms ; export CUMP complet 1 837 ms. Les limites et conditions sont dans la [recette de volume](recette-volume-logistique-20261026.md). |

## Vérifications avant livraison client

| Priorité | Vérification | État et critère restant |
|---|---|---|
| P1 | Gmail et récupération du mot de passe | Les 27 contrôles isolés de sécurité passent : expiration, usage unique, concurrence, non-divulgation des comptes et révocation des jetons. Le compte et l’expéditeur utilisent sauverndekordc@gmail.com. Le dialogue TLS Google est valide ; le test AUTH LOGIN renvoie **535 : identifiants SMTP refusés**, sans e-mail envoyé. Le bouton Administration → Messagerie → Tester la connexion permet un contrôle sans message (trois demandes par minute, accès global uniquement). Il reste à corriger le secret privé puis vérifier un envoi et sa réception. Aucun mot de passe réel n’a été changé pour la recette. |
| P1 | Installation et déploiement | Installation vierge et mise à jour SQL vérifiées en base privée. Commandes de maintenance, paquet d’installation fermé, paramètres production, Waitress et configuration HTTPS préparés. La mise en service sur le serveur client avec domaine, certificats et secrets réels reste à exécuter ; Docker absent sur ce poste, images non exécutées ici. Voir le [guide de livraison](livraison-logistique.md). |
| P1 | Sauvegarde et restauration | Aller-retour DB et médias vérifié en environnement isolé, avant mise à jour et pour la livraison finale ; les résultats exacts sont consignés dans le guide de livraison. Un essai séparé avec photo fictive contrôle aussi les fichiers privés. Prévoir la planification et la conservation des sauvegardes sur le serveur client. |
| P1 | Paramétrage de l’entreprise cliente | COUSP et sa licence sont créées ; l’isolation a été vérifiée avec École Pilote Test et le compte global. Compléter les vraies coordonnées et identifiants déclaratifs via Logistique → Identité de l’entreprise, puis les utilisateurs et coûts de reprise. Aucun contact, taux fiscal ni mention légale n’a été inventé. |
| P1 | Recette utilisateur de la chaîne complète | La chaîne complète a passé **112 contrôles intégrés** sur installation vierge privée : réception/sortie fractionnaires, retour avant facture, paiements concurrents, retour facturé, avoir, imputation/remboursement et rapprochement final stock/financier. Les deux entreprises restent isolées. Le responsable client doit encore accepter les données de reprise, les documents et son parcours réception → sortie → retour → facture → règlement → avoir → imputation/remboursement. Conserver des essais fictifs hors de SauverNdeko. |
| P2 | Recette visuelle et accessibilité | Build, navigation différée, reprise d’erreur, vues Lots/CUMP et mobilité contrôlés ; les preuves et limites figurent dans le guide frontend. Faire accepter les écrans et documents longs avec l’identité réelle du client. |

## Extensions à cadrer séparément

Le [cadrage ERP](cadrage-extensions-erp.md) définit les parcours, contrats SQL, principes d’interface et critères d’acceptation pour multi-dépôts/transferts, achats/ventes, comptabilité générale et modernisation des autres modules. Ces extensions restent des phases distinctes à réaliser ; elles ne sont pas présentées comme des modules déjà livrés. Le suivi des règlements et la valorisation CUMP ne remplacent pas une comptabilité générale.

## Vérifications déjà obtenues

- Après les migrations du 26 octobre : **24 tables sources métier/audit inchangées**, aucune quantité ni écriture de stock ajoutée pour les essais. Deux ouvertures CUMP restent non confirmées.
- Sur une copie privée fraîche recevant SQL04 → SQL08 : **299 contrôles réussis**, dont CUMP 45, péremption 49, registre Lots 65, annulation d’inventaire 31, protections des bons internes 40, numérotation 22, récupération d’accès 27 et rôle runtime restreint 20.
- Sur SauverNdeko après redémarrage : **187 routes GET réussies**, connexion PostgreSQL réellement en lecture seule, aucune écriture. Django check réussi.
- Pour la clôture : 112 contrôles de chaîne intégrée, 37 d’identité documentaire, 47 de diagnostic de livraison et 21 de connexion mail simulée ont réussi ; les 27 contrôles de récupération ont été rejoués après l’évolution de messagerie. Les six PDF de la chaîne et l’identité multiligne ont été rendus et inspectés.
- SQL09 : 26 tables sources identiques avant/après hors nouvelles colonnes de profil ; aucun instantané documentaire émis n’a été réécrit.
- Les corrections et compensations d’inventaire sont classées par FK dans V_BonInventaire et ne peuvent pas recevoir une facture ou un retour commercial. Leur annulation passe uniquement par le parcours d’inventaire, pour éviter une double restitution.
- Les preuves plus anciennes restent valables : 102 contrôles des documents/avoirs et inspection de PDF longs. Elles ne prouvent pas, à elles seules, l’acceptation client ou la réception d’un e-mail réel.

Sources : [CUMP](../SQL/documentation/Valorisation_CUMP_20261026.md), [péremption](../SQL/documentation/Peremption_Lots_20261026.md), [lots](../SQL/documentation/Registre_Lots_20261026.md), [performance](performance-frontend-20261026.md), [livraison](livraison-logistique.md), [Entités, tiers et stock](../skills/sauverndeko-erp/references/entites-tiers-et-stock.md).

Les points qui dépendent de données réelles du client et du serveur restent ouverts explicitement. Le diagnostic ne remplace ni une acceptation utilisateur ni une connexion Google réellement authentifiée. Le [guide de prise en main](prise-en-main-logistique.md) décrit les parcours quotidiens.
