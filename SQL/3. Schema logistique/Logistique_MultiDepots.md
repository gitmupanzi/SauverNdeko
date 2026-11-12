# Extension multi-dépôts — contrat canonique

La définition SQL maintenue de cette extension est la migration
[`20261107_02_multi_depots.sql`](../../backend/database/migrations/20261107_02_multi_depots.sql).
Les exports historiques `Logistique_Tables.sql` et `Logistique_View.sql` restent
le socle publié ; ils ne doivent pas être rejoués sur une base cliente.

Le paquet d’installation neuve est généré depuis une base de maintenance à jour
par `preparer_installation`. Il capture les nouvelles tables, vues, fonctions,
contraintes, commentaires et le catalogue fermé `T_ChampReferentiel`. Les six
états communs sont exportés avec le dictionnaire commun. Aucun dépôt,
transfert, utilisateur, bon, préférence privée ou donnée cliente n’est exporté.
Le trigger de création d’entreprise crée son dépôt principal sans stock.

- `T_Depot` appartient durablement à une entreprise et possède un code unique
  dans cette entreprise ; son historique est désactivable, sans suppression.
- `T_Commande`, `T_Mouvement`, `T_Inventaire` portent le dépôt ; les mouvements
  héritent du dépôt du bon. Le rattachement initial ne crée aucun mouvement.
- `V_StockDepot` et `V_StockLotDepot` proviennent des mouvements existants.
  `QteArticle` reste la somme physique des dépôts ; le transit est séparé.
- `V_ReservationLotDepot` engage les lots et la part sans lot à la validation.
  Deux transferts ne peuvent réserver ni le même solde de lot, ni le même
  stock sans lot au-delà de sa quantité réelle. Les lots inactifs ou périmés
  bloqués sont soustraits du disponible, selon la date métier de Kinshasa.
- Les contrôles, consommations, couvertures et alertes de péremption disposent
  de vues au grain dépôt. `V_ArticlePeremptionDepot` prend les lots du dépôt
  et son seul stock sans lot, avec les délais article/entreprise existants.
- `T_TransfertDepot` et ses lignes décrivent la demande ; les quantités exécutées
  sont dérivées des BS/BE liés, jamais des compteurs modifiables.
- Le journal `T_TransfertDepotAction` conserve acteur, UUID, empreinte et motif.
  Une expédition produit un BS unique. Chaque réception partielle ou retour
  du transit produit son propre BE, via la chaîne de triggers existante.
- Une annulation après expédition conserve la sortie et crée la compensation
  du seul transit restant. Les biens déjà reçus exigent un nouveau transfert
  inverse. Un écart motivé soldé ne crée pas une seconde sortie.
- La réception reprend le coût CUMP exact de la sortie source. Le transit
  appartient encore à l’entreprise et possède sa valorisation séparée.
- Les transferts sont exclus de la consommation, facturation, restitutions
  commerciales, corrections d’inventaire et encaissements automatiques.
- Les transactions verrouillent les parents puis les articles par identifiant
  croissant ; les contrôles différés refusent un dépôt/lot négatif, une
  réservation excessive ou un dépassement du transit.

Les validations de licence, permission, entreprise active et révision restent
dans les services Django ; les contrôles de conservation restent aussi en SQL.
Les interfaces ne sont jamais une autorisation d’écriture.

Avant une mise à jour cliente : sauvegarde restaurée, précontrôle en lecture
seule, recette sur copie, maintenance courte, migration journalisée puis
comparaison des anciennes colonnes et quantités. Avant toute opération nouvelle,
un échec peut être traité par restauration vérifiée. Après opérations nouvelles,
ne pas supprimer les tables/colonnes : conserver les écritures et préparer une
migration corrective ou des compensations métier. Une restauration ancienne
perdrait ces opérations et exige une décision explicite.

Le rejeu est celui du moteur `migrer_metier` : l’empreinte du fichier publié et
le journal empêchent toute nouvelle application. Ne pas lancer deux fois le
SQL brut dans un éditeur : une table déjà présente provoque un refus atomique,
sans duplication. Les cinq vues historiques sont enrichies en conservant leurs
définitions du socle attesté et l’ordre exact de leurs anciennes colonnes.

Le compte HTTP garde `SELECT` et `INSERT` sur `T_TransfertDepotAction` ;
`UPDATE` et `DELETE` y sont révoqués, en complément des triggers d’immutabilité.
Le script `deploy/production/role-runtime.sql` conserve cette restriction lors
de sa réapplication. Aucun mot de passe ni rôle propriétaire n’est livré.

Les contrats en lecture seule sont vérifiés par
`SQL/tests/test_multi_depots_sql.py`. Les trois vérifications de rôle dans
`SQL/tests/test_multi_depots_runtime.py` exigent une copie locale privée et un
rôle HTTP préalablement préparé ; elles ne créent aucun rôle ni enregistrement.
La recette API séparée exerce les opérations et la concurrence sur une copie.

Les mécanismes existants de lots, péremption et dérogations sont conservés.
Une quarantaine par statut métier et les campagnes de rappel ne sont pas
inventées par le dépôt ; leur procédure et leur périmètre restent à cadrer.
