# Mise à jour des immobilisations

## Périmètre

Le registre existant conserve ses codes, propriétaires, affectations, prix et références. La livraison ajoute la date de mise en service, un journal des comptages, entretiens et sorties, ainsi que les justificatifs privés. Les affectations et transferts utilisent le formulaire et l’audit existants. Le comptage fige la quantité théorique au moment de la saisie. La sortie concerne un bien individuel ou la totalité d’un lot homogène.

Les plans comptables et fiscaux sont séparés par bien et par entreprise. Le plan initial, les événements constatés et les clôtures restent consultables. Les administrateurs autorisés à gérer la Logistique enregistrent les décisions dans l’entreprise sélectionnée. La validation est documentée par une référence fournie par le gestionnaire et son compte est tracé. Aucun rôle de comptable n’est attribué automatiquement.

## Paramètres à valider avec le comptable

- **SYSCOHADA révisé.** Confirmer son applicabilité, l’entrée à l’actif, le coût, la valeur résiduelle, la durée d’utilité et la date à laquelle le bien est prêt à fonctionner. Examiner les composants significatifs dont les durées diffèrent. [AUDCIF, notamment les articles 38-1 et 45 à 47](https://justice.sec.gouv.sn/wp-content/uploads/textes-reglements/OHADA/Acte-uniforme-relatif-droit-comptable-information-financiere-JAN-2017-JO.pdf)
- **IFRS.** Pour un bien corporel, IAS 16 traite notamment de la disponibilité à l’usage, des composants et de la révision des estimations. Pour un incorporel, IAS 38 distingue les durées finies et indéfinies et impose des critères de comptabilisation. La qualification d’un logiciel dépend des faits et de ces critères. Les pertes de valeur doivent être appréciées selon les règles applicables, dont IAS 36 en IFRS. [IAS 16](https://www.ifrs.org/issued-standards/list-of-standards/ias-16-property-plant-and-equipment/), [IAS 38](https://www.ifrs.org/issued-standards/list-of-standards/ias-38-intangible-assets/), [IAS 36](https://www.ifrs.org/issued-standards/list-of-standards/ias-36-impairment-of-assets/)
- **Fiscalité.** Confirmer séparément les règles fiscales de l’entreprise. Renseigner les paramètres et la devise retenus pour chaque plan. Les totaux du registre restent ventilés par devise. Le système n’effectue aucune conversion implicite.
- **Calcul livré.** Le linéaire est calculé au prorata journalier, avec arrondi du cumul au centime et reliquat réparti sur la durée restante. Le montant constaté dans le journal se distingue de la prévision. La sortie arrête la dotation à la veille de sa date. La méthode « Non amortissable » requiert une décision documentée et permet le suivi des événements de valeur. Avant une clôture, le gestionnaire doit traiter les dotations et les sorties dues.
- **Limites.** Les autres méthodes, les reprises de dépréciation, la révision des durées ou valeurs résiduelles et la décomposition automatisée par composants demandent un parcours dédié. Un ajustement conserve le terme initial du plan. L’application ne décide pas de la capitalisation d’une dépense, ne propose aucun barème fiscal et ne passe aucune écriture en comptabilité générale ni en Caisse. Aucune conformité ou certification n’est attestée par ces calculs.

## Ordre de livraison

1. Confirmer la cible et relever le commit actif, le journal des migrations, le nombre de fiches et les empreintes des données existantes. Prévoir une fenêtre sans écritures.
2. Sauvegarder la base avec ses médias et vérifier la restauration vers une nouvelle base locale isolée. Suivre [la procédure de sauvegarde et de livraison](mises-a-jour-base.md).
3. Vérifier le plan avec `migrer_metier`. Appliquer sur la cible après validation, avec le compte de maintenance et `migrer_metier --apply --release 2026.11.09`. La commande applique toutes les migrations encore en attente du manifeste. Le paramètre `--release` identifie la livraison dans le journal. Pour cette évolution, le manifeste applique d’abord `20261109_01_immobilisations_cycle_vie`, puis `20261109_02_immobilisations_valorisation`. Le premier script ajoute des champs, un registre d’événements et les protections documentaires. Le second crée les plans et les journaux financiers. Aucun amortissement, comptage ou déclassement historique n’est créé lors de la migration.
4. Vérifier le journal avec `migrer_metier --check` et contrôler les droits du rôle applicatif. Comparer les anciennes données patrimoniales, les liens et le stockage des justificatifs. Déployer le code correspondant et effectuer la recette de consultation sous deux entreprises. Réactiver les écritures après validation de ces contrôles.

## Retour arrière

Une migration échouée est annulée dans sa transaction. Si le code échoue après une migration réussie, garder le service en maintenance et privilégier un correctif applicatif compatible avec le schéma livré. Pour revenir au comportement précédent sans restaurer la base, préparer et tester une version de repli qui conserve le manifeste et les scripts SQL à jour. Le contrôle Render d’un ancien commit peut refuser un journal qui contient des migrations absentes de son manifeste. Si une restauration est nécessaire, la faire sur une nouvelle base, vérifier ses empreintes puis basculer la connexion. Si des utilisateurs ont déjà créé des événements, conserver une sauvegarde de l’état après livraison et décider de la reprise de ces écritures avant toute bascule. Conserver la base précédente jusqu’à la validation des contrôles.

## Recette sur copie

Une sauvegarde existante a été restaurée sur PostgreSQL 18. La restauration a vérifié les empreintes de 88 tables, de six médias et des commentaires de contraintes. Après insertion d’un bien fictif dans l’ancien schéma et enregistrement de son affectation, les deux migrations ont conservé les empreintes du registre, des justificatifs, du journal d’audit, des articles, des bons et des mouvements. Le contrôle final ne signale aucune migration en attente. Un second passage n’a réappliqué aucun script.

La base locale de travail et la base Render exigent une décision de livraison distincte.
