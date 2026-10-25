# Contrat Articles, photos et lots

Évolution autorisée le 25/10/2026 : CRUD Article, poids, lots à réception, capture photo et informations complémentaires. Source : SQL/migrations/20261025_03_articles_poids_lots.sql. Les modèles restent unmanaged.

## Écritures Article

article_rules.py valide identité, références actives et catégorie attendue, prix, quantités, dates et poids. GET /api/logistique/articles/<id> fournit une révision ; PUT/DELETE doivent envoyer _version. Verrou et comparaison partagent la transaction. La révision exclut le stock courant pour distinguer mouvement et modification des caractéristiques.

Une modification ne change ni créateur ni directement stock. Une unité ayant des mouvements/lignes ne change plus. La suppression physique exige un administrateur global, un article inactif à stock nul et aucune référence métier ; sinon proposer la désactivation. L’audit partage la transaction. Ne pas traiter un conflit comme un succès.

InformationArticle est un texte complémentaire (limite applicative 20 000 caractères), distinct de ObsArticle. Le poids numeric(14,6) est indépendant des quantités : poids et unité vides ensemble ou renseignés ensemble. Les unités de masse sont les références mg/g/kg/t de catégorie 34. Les quantités de mouvement restent entières selon le schéma existant.

## Réception depuis un article

Le raccourci Réceptionner stock crée un bon d’entrée et sa ligne pour un article autorisé, avec quantité reçue strictement positive, prix Decimal exact, devise et éventuelle ventilation par lots. Un prix catalogue n’est repris que dans la même devise ; un autre prix est fourni explicitement dans la devise du bon, sans conversion implicite. Vérifier les droits, le périmètre, les références et les verrous métier comme dans le parcours des bons.

Le type du bon provient de la FK existante T_Commande.ID_TypeCmdFk vers le référentiel commun. Exposer les types actifs de sens entrée et leur choix initial dans la préparation ; revalider à l’écriture la référence, la catégorie attendue et le sens entrée du type demandé. Le libellé transmis et le filtrage du navigateur ne remplacent pas ce contrôle serveur ; aucune table de types par écran.

Bon, ligne, lots et audit partagent une transaction : une erreur annule la réception entière. Les triggers existants restent seuls responsables de l’incrément de stock, des mouvements et des totaux ; ne pas doubler ces effets par une mise à jour de QteArticle ou un mouvement manuel dans le service du raccourci. Réutiliser les contrôles de ventilation et l’ordre des verrous décrits ci-dessous.

## Lots

T_LotArticle identifie un numéro par article ; T_MouvementLot ventile un mouvement existant. V_LotArticleStock et V_MouvementLot calculent stock et traçabilité. Les tables, colonnes, vues, fonctions et triggers introduits ont des COMMENT ON.

Une ligne accepte Lots: [{NumeroLot, Quantite, DatePeremptionLot}]. LotsInitiaux est réservé à la création d’un article avec stock positif. Maximum applicatif : 50 lots par ligne. Pour une entrée ou un stock initial, une nouvelle ventilation fournie totalise exactement la quantité source. Une sortie peut être ventilée partiellement : son reliquat explicite sans lot ne doit pas dépasser le stock historique réellement disponible sans lot. Une réception identifie ou crée le lot reçu ; une sortie reprend un lot actif connu. Ne pas corriger une quantité ventilée en supprimant silencieusement ses lots.

Verrouiller parent du bon, article puis lot. Les triggers existants restent seuls responsables du stock global et du mouvement. La ventilation n’applique aucun deuxième effet. Les contrôles différés refusent lot négatif, rattachement à un autre article, somme dépassant le mouvement ou stock ventilé dépassant le stock global. Une annulation ne peut retirer une réception dont les lots sont déjà consommés.

Préserver le stock historique sans numéro de lot. La différence entre stock global et stock identifié représente le stock sans lot ; ne pas attribuer de numéro arbitraire. Les consultations contrôlent le parent puis imposent sa clé aux lots.

## Images privées

photos.py accepte une image multipart et une partie payload JSON exacte. Limites : 8 Mio, JPEG/PNG/WebP, 24 mégapixels. Vérifier le contenu par Pillow, corriger l’orientation, retirer les métadonnées et convertir en JPEG de 1 600 px au plus. Ne pas récupérer une URL fournie par le client.

Stockage : ARTICLE_MEDIA_ROOT/Article/<nom-normalisé>_<suffixe-unique>.jpg, défaut backend/media. Seul un chemin généré est enregistré dans PhotoArticle. Nettoyer le nouveau fichier si la transaction échoue. Les anciens fichiers restent récupérables ; leur purge exige une politique séparée avec sauvegarde et contrôle des références.

L’accès passe par la route logistique avec contrôle d’objet ou la projection catalogue autorisée. Réponses privées sans cache et nosniff. Ne pas servir directement media. Un pg_dump ne contient pas les images : sauvegarder media et vérifier sa restauration séparément.

## Vérification et déploiement

Maintenir les recettes SQL/tests sur une base sauverndeko_test_* indépendante, sans données clients. Tester concurrence, conflits, entrée/sortie multi-lots, correction, annulation, lot épuisé, somme incorrecte, photo invalide et nettoyage sur échec. Les diagnostics manage.py restent en lecture seule sur SauverNdeko.

Avant migration : sauvegarde vérifiée, contrôle que données et quantités existantes restent identiques. Aucun DROP CASCADE pour réordonner les colonnes. La présentation d’InformationArticle avant ObsArticle relève de l’interface ; PostgreSQL ajoute la nouvelle colonne sans reconstruire les tables.


## Réception depuis Articles — 25/10/2026

GET /api/logistique/articles/<id>/receptions prépare une réception sans écriture : article autorisé, prix d’achat et devise du catalogue, date/heure du bon dans le fuseau configuré, type Entrée actif résolu du référentiel. Le prix est une suggestion dans la même devise ; le frontend l’efface si la devise change. La préparation exige le périmètre de l’article et la même organisation que le compte, y compris pour un administrateur de plateforme.

POST sur cette route reçoit requestId (UUID conservé jusqu’au succès), QteCmdDetail, PUCmdDetail, ID_DeviseFk, DateCmd, et les champs facultatifs RefCmd, ID_ClientFk, NomClientSaisi, ObsCmd, ObsCmdDetail et Lots. Le service receipts.receive_article valide puis crée un bon d’entrée avec mutate et une seule ligne avec mutate_line, dans la même transaction. Propriétaire, article et type proviennent du compte, de l’URL et du référentiel ; aucun champ client ne peut les détourner. Les triggers existants appliquent l’unique effet de stock et le mouvement, puis la ventilation de lots reprend ce mouvement. Aucun UPDATE de stock, INSERT de mouvement ou mise à jour du prix de catalogue n’est réalisé en Python.

La quantité est entière, strictement positive et limitée au type integer du mouvement. Le prix reçu est obligatoire, positif ou nul, respecte numeric(12,2), et le produit quantité × prix doit aussi tenir dans MontantTTC avant toute création. Référence, nom de tiers et observations restent dans leurs limites PostgreSQL de 255 caractères. Maximum 50 lots, numéros uniques par ligne, dates de péremption valides et somme exacte des quantités. Une erreur de ligne ou de lot annule également le bon.

DateCmd est actuellement horodatée avec fuseau : un datetime-local sans offset est interprété explicitement dans settings.TIME_ZONE (Africa/Kinshasa localement), un ISO avec offset conserve son instant. La date du bon saisie est distincte de l’horodatage de création du mouvement généré par la procédure. Ne pas promettre un mouvement antidaté sans évolution SQL dédiée.

Un verrou transactionnel par acteur/UUID et une preuve RECEIVE dans le journal existant protègent les reprises réseau. La preuve conserve l’UUID complet et l’empreinte du payload normalisé ; CodeCmd reste dans sa limite de vingt caractères. Un replay identique retourne le bon existant sans nouveau stock ; un changement de quantité, prix, devise, date, tiers, observations ou lots avec le même UUID renvoie 409. Une nouvelle demande utilise un nouvel UUID. Le mode lecture seule et les droits de gestion logistique sont vérifiés avant toute création. Le diagnostic verifier_backend ne teste que la préparation GET, jamais le POST applicatif.


Avant de rendre une mutation de ligne, contrôler les soldes de lots sous le verrou article, après la mise à jour du mouvement et de sa ventilation. Retourner une erreur Lots ciblée avant le commit ; la composition conserve l’indice original de la ligne et annule tout le panier. Les contraintes différées PostgreSQL restent la protection finale. Les métadonnées lotStock exposent stockTotal, stockAllocated et stockWithoutLot sur l’ensemble de l’article, indépendamment de la pagination et des filtres ; un stock inconnu reste inconnu. En édition, prendre en compte le mouvement existant pour calculer le disponible propre à cette ligne.

Une ventilation historique explicitement inchangée, avec la même quantité source, peut être conservée sans réécrire ses lots, y compris archivés. Cette conservation ne permet pas une nouvelle ventilation partielle d’entrée ni une consommation supplémentaire d’un lot archivé.
