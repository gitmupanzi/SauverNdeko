# Stock initial et numérotation des bons

La migration `20261028_01_stock_initial_documents.sql` centralise le stock initial en PostgreSQL. Le parcours reste une entrée interne de stock, sans commande fournisseur ni tiers inventé.

## Création d'un article

Sans quantité initiale, la fiche ne produit ni bon, ni ligne, ni mouvement. Avec une quantité positive, le trigger de l'article appelle `fn_materialiser_stock_initial` sous verrou article. La routine crée un bon d'entrée et sa ligne. La procédure commune des lignes crée l'unique mouvement, sans réappliquer une quantité déjà portée par l'insertion de l'article. Un échec sur le bon, la ligne ou les lots annule la transaction entière.

`OrigineBon = stock_initial` et `ID_ArticleInitialFk` gardent une provenance durable. Le libellé est « Création depuis Articles / Stock initial ». Le sens Entrée reste déterminé par le référentiel des types de bon. L'entreprise et l'auteur viennent de l'article; les dates métier et techniques sont conservées. Les lots se rattachent au mouvement du bon initial.

Une mise à jour descriptive ne crée aucun mouvement. Un changement direct de `QteArticle` est refusé hors de la procédure des lignes. Les ajustements ultérieurs passent par un nouveau bon ou par un inventaire motivé. Le bon initial et sa ligne restent historiques; ils ne peuvent être supprimés, facturés ni restitués commercialement.

La création API exige `requestId`, UUID stable pendant les nouvelles tentatives. Le serveur conserve `CreationRequestId` et `CreationPayloadHash`, calculé avec le contenu, les lots et la photo normalisée. Verrou de demande et index unique par entreprise/utilisateur empêchent un double article et un double mouvement. Un UUID repris avec un autre contenu est refusé. Ces champs techniques sont produits par le service, jamais modifiables dans le formulaire. La mise à jour utilise toujours la révision existante, sans identifiant de création.

## Reprise historique

L'examen en lecture seule du 28 octobre a trouvé trois articles, tous cohérents entre quantité courante et somme signée des mouvements. « Téléphone » possédait déjà ses mouvements : son entrée initiale n'avait pas de bon source. Quatre mouvements sans bon étaient concernés au total, dont deux sur le même article. Une nouvelle entrée physique aurait doublé le stock.

La migration rattache donc chaque mouvement orphelin prouvé à un bon et une ligne de reprise, avec `OrigineBon = reprise_mouvement`. Elle conserve son identifiant, sa quantité, son prix, sa devise, ses dates et ses lots; seule la FK du bon est ajoutée. Elle ne prétend pas retrouver un auteur historique inconnu. La date technique du nouveau document est celle de la reprise. Un audit explicite et le journal de valorisation gardent les preuves du rattachement. Les arrêtés de coût restent inchangés; l'exception à leur protection n'autorise que ce rattachement strict.

Un deuxième passage de la fonction sur le même mouvement retourne son bon existant. Aucun écart de stock non expliqué n'a été corrigé par une quantité inventée. Une base présentant de tels écarts doit être rapprochée à partir de justificatifs ou par inventaire; ce constat est distinct des quatre mouvements déjà prouvés.

## Numérotation

Les nouveaux bons Entrée portent `BE-ID`, les nouveaux bons Sortie `BS-ID`. L'identité globale provient de la séquence et de la protection d'historique existantes. Les contrôles d'audit reconnaissent aussi les préfixes BE et BS et empêchent leur réutilisation après suppression. Les codes historiques `cmd-...` et les factures `fac-...` restent intacts.

Le préfixe `cmd-` reste réservé aux commandes hors entrée/sortie. Le module actuel gère des bons physiques Entrée/Sortie; cette migration n'ajoute pas artificiellement un parcours d'achat ou une commande commerciale neutre. Le code public d'un bon reste automatique et immuable.

## Recette

`SQL/tests/test_stock_initial_documents.py` refuse toute base autre que `sauverndeko_test_*`. Sur une copie privée de structure, il prépare des antécédents fictifs, teste la reprise sans modification du stock, puis couvre zéro/positif, lots, édition descriptive, refus des ajustements directs, atomicité d'un échec, demande idempotente, quatre créations simultanées, isolation par entreprise et seize numérotations concurrentes. Aucune mutation de recette ne vise SauverNdeko.
