# Multi-dépôts : plan de migration

État : modèle et migration sécurisée validés par l’utilisateur le 7 novembre 2026. Migration `20261107_02_multi_depots` installée dans la base **locale** `sauver_ndeko_pro` après sauvegarde fraîche, restauration contrôlée et recette sur cette copie. Les contrôles après installation et les lectures API sur les deux entreprises sont réussis. La recette visuelle reste à effectuer ; aucune installation Render n’a été réalisée dans ce chantier. Voir le [bilan de recette](multi-depots-recette-20261107.md).

## Modèle et fonctionnement retenus

- Chaque dépôt appartient durablement à une entreprise. Son code est unique dans cette entreprise. Le dépôt principal sert de choix initial aux opérations simples ; l’utilisateur peut choisir un autre dépôt autorisé.
- Le stock physique d’un article reste la somme de ses mouvements signés, ventilés par dépôt. `T_Article.QteArticle` conserve son rôle de total physique contrôlé. Une expédition interne diminue le présent ; une réception augmente le présent. Le transit est affiché séparément. Le total détenu réunit présent et transit non soldé.
- Les bons et inventaires portent leur dépôt. Un document ayant déjà des mouvements ne peut changer de dépôt. Les retours et annulations compensatrices conservent le dépôt d’origine.
- Un transfert relie deux dépôts distincts de la même entreprise : demande, validation et réservation, expédition, réceptions partielles, clôture. Un reliquat reste en transit tant qu’il n’est pas reçu, retourné à la source ou soldé par un écart explicitement justifié. Une annulation après départ ne supprime pas l’historique ; elle documente le retour du reliquat.
- Les mouvements restent produits par les routines de bons existantes. Les entrées de transfert reprennent le coût de la sortie d’origine. Elles ne constituent ni un achat ni une vente. Aucun transfert ne crée de facture, de règlement ou d’écriture de caisse.
- Les lots gardent leur identité article commune ; leur disponibilité est contrôlée par dépôt. Les règles existantes de péremption et d’activation des lots sont conservées. Une réservation n’est pas une sortie physique. Les garanties de concurrence sont vérifiées dans PostgreSQL, sous verrou commun de l’article. Une gestion opérationnelle des quarantaines et des rappels n’existait pas lors de l’audit : elle ne doit pas être annoncée comme disponible sans développement et recette spécifiques.

## Reprise des données existantes

1. Arrêter les écritures pendant l’installation. Identifier explicitement l’instance et le compte propriétaire ; ne pas utiliser le compte HTTP pour migrer.
2. Sauvegarder PostgreSQL et les médias privés. Restaurer cette sauvegarde dans une base de recette et vérifier les empreintes des tables, fichiers et objets de schéma.
3. Contrôler avant installation : propriété des articles/bons/inventaires, cohérence du journal avec les quantités, liens de lots et de Caisse, références orphelines. Un document ambigu arrête la migration ; aucune entreprise n’est déduite arbitrairement.
4. Créer un unique « Dépôt principal » pour chaque entreprise concernée par des stocks ou documents historiques. Affecter à ce dépôt les documents et leurs mouvements existants, sans créer de nouveau mouvement et sans modifier les quantités, prix, dates, références ou auteurs historiques.
5. Installer les tables, vues, contraintes et routines versionnées. Les nouvelles opérations imposent un dépôt cohérent avec leur entreprise ; le choix par défaut sert uniquement à simplifier la saisie.
6. Comparer avant/après : quantités globales identiques, somme physique des dépôts égale au total article, ventilation des lots identique, nombre et identité des anciens mouvements inchangés, documents financiers et liens Caisse préservés. Contrôler les permissions du compte runtime.
7. Relancer le moteur de migration : aucune duplication de dépôt, mouvement ou réservation. Charger le code compatible et exécuter la recette métier avant réouverture.

## Retour arrière

L’installation est transactionnelle : une erreur avant validation annule cette migration. Après installation, garder la maintenance si les vérifications échouent. Ne pas supprimer les colonnes ni revenir au code ancien pendant que des opérations multi-dépôts existent. Préférer une correction progressive. Une restauration de la sauvegarde n’est possible sans perte qu’avant toute nouvelle écriture ; sinon établir une reprise contrôlée des opérations intervenues depuis la sauvegarde.

## Accord reçu

L’utilisateur a validé le modèle présent/transit et l’affectation des historiques au dépôt principal de leur entreprise, ainsi que leur future installation après sauvegarde et recette vérifiées. Une sauvegarde fraîche restaurée et contrôlée reste obligatoire au moment du déploiement. L’instance cible et les résultats des contrôles doivent être consignés dans le bilan d’installation.

## Sources de bonnes pratiques

La séparation des événements d’expédition/réception, l’identification des lots, des lieux, des dates et des acteurs ainsi que le suivi des produits bloqués s’appuient sur les [bonnes pratiques de stockage et distribution de l’OMS](https://www.who.int/publications/m/item/trs-1025-annex-7) et le [standard de traçabilité GS1](https://ref.gs1.org/standards/global-traceability/). Ces références orientent le périmètre ; elles ne prouvent aucune certification. La validation des conditions de conservation, des procédures de rappel, des habilitations et du cadre réglementaire de l’exploitant reste distincte de la recette logicielle.
