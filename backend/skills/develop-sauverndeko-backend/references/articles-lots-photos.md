# Contrat Articles, photos et lots

Évolution autorisée le 25/10/2026 : CRUD Article, poids, lots à réception, capture photo et informations complémentaires. Source : SQL/migrations/20261025_03_articles_poids_lots.sql. Les modèles restent unmanaged.

## Écritures Article

article_rules.py valide identité, références actives et catégorie attendue, prix, quantités, dates et poids. GET /api/logistique/articles/<id> fournit une révision ; PUT/DELETE doivent envoyer _version. Verrou et comparaison partagent la transaction. La révision exclut le stock courant pour distinguer mouvement et modification des caractéristiques.

Une modification ne change ni créateur ni directement stock. Une unité ayant des mouvements/lignes ne change plus. La suppression physique exige un administrateur global, un article inactif à stock nul et aucune référence métier ; sinon proposer la désactivation. L’audit partage la transaction. Ne pas traiter un conflit comme un succès.

InformationArticle est un texte complémentaire (limite applicative 20 000 caractères), distinct de ObsArticle. Le poids numeric(14,6) est indépendant des quantités : poids et unité vides ensemble ou renseignés ensemble. Les unités de masse sont les références mg/g/kg/t de catégorie 34. Les quantités exactes suivent `logistique.T_PrecisionStock`, lié à l’unité de `referentiel.T_Generique` : zéro décimale par défaut, jusqu’à trois selon le paramétrage autorisé. Ne pas rétablir la contrainte ancienne « entier uniquement » pour toutes les unités.

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

GET /api/logistique/articles/<id>/receptions prépare une réception sans écriture : article autorisé, prix d’achat et devise du catalogue, date/heure du bon dans le fuseau configuré, type Entrée actif résolu du référentiel. Le prix est une suggestion dans la même devise ; le frontend l’efface si la devise change. La préparation exige le périmètre de l’article et l’entreprise active autorisée. Le compte global choisit explicitement cette entreprise ; son entreprise de rattachement personnelle ne remplace pas le contexte vérifié.

POST sur cette route reçoit requestId (UUID conservé jusqu’au succès), QteCmdDetail, PUCmdDetail, ID_DeviseFk, DateCmd, et les champs facultatifs RefCmd, ID_ClientFk, NomClientSaisi, ObsCmd, ObsCmdDetail et Lots. Le service receipts.receive_article valide puis crée un bon d’entrée avec mutate et une seule ligne avec mutate_line, dans la même transaction. Propriétaire, article et type proviennent du compte, de l’URL et du référentiel ; aucun champ client ne peut les détourner. Les triggers existants appliquent l’unique effet de stock et le mouvement, puis la ventilation de lots reprend ce mouvement. Aucun UPDATE de stock, INSERT de mouvement ou mise à jour du prix de catalogue n’est réalisé en Python.

La quantité est strictement positive, exacte et compatible avec la précision de son unité et les limites numériques de la source. Le prix reçu est obligatoire, positif ou nul, respecte numeric(12,2), et le produit quantité × prix doit aussi tenir dans MontantTTC avant toute création. Référence, nom de tiers et observations restent dans leurs limites PostgreSQL de 255 caractères. Maximum 50 lots, numéros uniques par ligne, dates de péremption valides et somme exacte des quantités. Une erreur de ligne ou de lot annule également le bon.

DateCmd est actuellement horodatée avec fuseau : un datetime-local sans offset est interprété explicitement dans settings.TIME_ZONE (Africa/Kinshasa localement), un ISO avec offset conserve son instant. La date du bon saisie est distincte de l’horodatage de création du mouvement généré par la procédure. Ne pas promettre un mouvement antidaté sans évolution SQL dédiée.

Un verrou transactionnel par acteur/UUID et une preuve RECEIVE dans le journal existant protègent les reprises réseau. La preuve conserve l’UUID complet et l’empreinte du payload normalisé ; CodeCmd reste dans sa limite de vingt caractères. Un replay identique retourne le bon existant sans nouveau stock ; un changement de quantité, prix, devise, date, tiers, observations ou lots avec le même UUID renvoie 409. Une nouvelle demande utilise un nouvel UUID. Le mode lecture seule et les droits de gestion logistique sont vérifiés avant toute création. Le diagnostic verifier_backend ne teste que la préparation GET, jamais le POST applicatif.


Avant de rendre une mutation de ligne, contrôler les soldes de lots sous le verrou article, après la mise à jour du mouvement et de sa ventilation. Retourner une erreur Lots ciblée avant le commit ; la composition conserve l’indice original de la ligne et annule tout le panier. Les contraintes différées PostgreSQL restent la protection finale. Les métadonnées lotStock exposent stockTotal, stockAllocated et stockWithoutLot sur l’ensemble de l’article, indépendamment de la pagination et des filtres ; un stock inconnu reste inconnu. En édition, prendre en compte le mouvement existant pour calculer le disponible propre à cette ligne.

Une ventilation historique explicitement inchangée, avec la même quantité source, peut être conservée sans réécrire ses lots, y compris archivés. Cette conservation ne permet pas une nouvelle ventilation partielle d’entrée ni une consommation supplémentaire d’un lot archivé.


## Péremption exhaustive — 26 octobre 2026

Réutiliser V_ArticlePeremption et les flags de V_Article pour alertes, dossiers, listes et exports. Seules les quantités encore en stock comptent ; conserver le stock archivé restant et distinguer les lots sans date. La date générale de l’article concerne le stock sans lot. Une référence peut avoir simultanément du stock périmé et proche ; ne pas exclure implicitement l’une des populations de l’autre.

Les réglages T_Entite.AlertePeremptionJours et BloquerLotsPerimes appartiennent à l’entreprise active. Le délai article explicite prime, même sans date générale. Le blocage initial est désactivé ; sa modification exige le compte global, l’entreprise cible et la révision. Les dérogations de lot sont des motifs globaux nominatifs horodatés sur T_MouvementLot, jamais un simple drapeau envoyé par le navigateur. Le trigger PostgreSQL garde le contrôle final et le mouvement source reste unique. Pour l’annulation d’une entrée d’inventaire sur un lot périmé bloqué, transmettre le motif d’annulation et l’acteur global au mouvement inverse ; refuser atomiquement aux autres comptes et conserver le rejeu.

Voir SQL/documentation/Peremption_Lots_20261026.md et la recette isolée SQL/tests/test_peremption_lots.py.

## Registre transversal des lots

Pour consulter tous les lots, utiliser `V_RegistreLots` et `/api/logistique/registre/lots`, défaut sans filtre d’activité ou de solde. Le journal `V_RegistreMouvementLot` se consulte par `/api/logistique/lots/{id}/mouvements`, avec filtre serveur obligatoire sur l’identifiant du lot et contrôle de son entreprise avant lecture, même si le journal est vide. Ne pas charger le journal entier pour filtrer côté React. Le registre et l’export partagent les mêmes critères ; une quantité est accompagnée de l’abréviation de son unité. Les compteurs sont des nombres de lots/articles : ne pas sommer des quantités d’unités différentes. Les écritures passent par les bons et les triggers existants. Voir SQL/documentation/Registre_Lots_20261026.md.

## Socle vérifié et évolutions du 28 octobre 2026

Les migrations `20261028_01_stock_initial_documents.sql`, `20261028_02_preferences_tableaux.sql` et `20261028_03_tracabilite_logistique.sql` sont les sources versionnées de ces règles. Leur présence dans le dépôt ne prouve pas leur application dans une base cliente : contrôler les objets installés et les preuves de recette avant de s’en prévaloir.

Un article créé sans stock initial ne produit aucun mouvement. Avec une quantité initiale positive, le trigger Article appelle `fn_materialiser_stock_initial` : un bon d’entrée interne, sa ligne et un seul mouvement sont liés durablement à l’article dans la même transaction. L’origine `stock_initial` et le lien `ID_ArticleInitialFk` distinguent cette ouverture d’une réception commerciale. Ne pas créer de fournisseur fictif, de commande d’achat ni de deuxième mouvement dans Django. Une modification descriptive ne réexécute pas l’ouverture ; un ajustement ultérieur utilise un bon ou un inventaire justifié.

Le formulaire de création conserve son UUID `requestId` jusqu’au succès confirmé. `CreationRequestId` et `CreationPayloadHash` sont renseignés uniquement par le service, avec l’acteur et l’entreprise ; un rejeu identique retrouve le même article. Un contenu différent sous le même UUID est refusé. Le calcul inclut les lots et l’empreinte de la photo normalisée ; ne pas recréer un UUID à chaque nouvelle tentative réseau. Les modifications conservent la révision existante et n’envoient pas de nouvel identifiant de création.

Les mouvements historiques orphelins prouvés peuvent être rattachés à un bon d’origine `reprise_mouvement` par la routine SQL dédiée, sans changer leur quantité, prix, date ou devise ni rejouer le stock. Une absence d’auteur reste inconnue. Ne pas inventer un coût d’ouverture ou attribuer l’auteur historique au compte exécutant la reprise. Les bons initiaux et leurs lignes sont protégés ; ils ne sont ni facturables commercialement ni restituables comme une vente.

Les nouveaux bons utilisent `BE-<id>` pour une entrée et `BS-<id>` pour une sortie ; les autres commandes utilisent `cmd-<id>`. Les factures conservent `fac-<id>`. La réservation d’identité, les contraintes et l’audit gardent l’unicité en concurrence et les numéros déjà utilisés. Les codes historiques restent inchangés. Ne pas déterminer l’origine à partir du préfixe : type et origine sont deux données distinctes.

Les codes internes d’article sont uniques dans l’entreprise propriétaire, pas dans toute la plateforme. Les prix et documents restent dans leur périmètre autorisé. `V_QuantitesBonUnite` ventile les quantités par unité réelle ; le registre ne propose pas un total scalaire mêlant kilogrammes et pièces. Les quantités JSON restent des chaînes décimales exactes.

Les règlements portent `CreeParUserFk`, `ModifieParUserFk`, `CreeLe` et `ModifieLe`. Les dates techniques SQL sont distinctes de `DateReglement` ; auteur/date de création sont immuables. Les historiques sans preuve ne sont pas complétés par déduction. Le service définit `systeme.actor_user_id` avec `SET LOCAL` dans sa transaction, puis les triggers réalisent l’image avant/après nettoyée une seule fois. Les événements applicatifs `PAYMENT_*` restent des preuves idempotentes distinctes ; ne pas rajouter un second audit de détail dans Python.

Une GUC d’acteur est une métadonnée de traçabilité, jamais une preuve d’autorisation SQL. Le serveur revalide compte actif, entreprise, rôle, droit et parent. Les gardes SQL vérifient aussi les règles financières lors d’une modification : facture/devise/tiers immuables, montant positif, mode actif, clôture, avoirs et solde net. Un excédent historique peut seulement être réduit. L’entreprise de l’audit documentaire est celle du document, indépendamment du rattachement actuel de son créateur.

Les justificatifs conservent leur contenu binaire et leur empreinte en base ; la contrainte SQL exige que le SHA-256 corresponde au contenu. Les photos Article restent dans le stockage privé existant avec leur chemin en base et leur sauvegarde média associée. Ajouter une colonne seulement pour une information métier manquante démontrée ; ne pas dupliquer des identités, soldes ou versions déjà prouvés par les structures existantes.

Les réglages de correspondances FK viennent du serveur. Le navigateur ne conserve plus de cache de remplacement pour les catégories métier : un échec de chargement ne doit pas réactiver une ancienne configuration ou une ancienne entreprise. Pour les préférences personnelles de colonnes et les exports indépendants, lire [la règle transverse de tableaux et exports](../../../../SQL/documentation/Preferences_Tableaux_Exports_20261028.md). Les choix visuels facultatifs, tels que thème et largeur de menu, peuvent rester locaux ; les références métier et droits n’y sont jamais décidés.
