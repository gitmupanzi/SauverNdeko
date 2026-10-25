# Architecture backend — Django, 24/10/2026

Le backend actif est Python/Django 5.2 LTS + Django REST Framework. La conversion initiale a conservé PostgreSQL. Le propriétaire a ensuite autorisé les migrations natives Django dans public ; les schémas métier sont conservés. L’audit métier ultérieur a fiabilisé les routines et ajouté le socle analytics dans la migration 04.

| Emplacement | Responsabilité |
|---|---|
| manage.py, start.ps1 | Commandes Django et démarrage local sur 127.0.0.1:5000 |
| config/settings.py | .env existant, connexion unique, lecture seule par défaut, CORS autorisé |
| config/urls.py | Routes React, modules REST et alias historiques |
| apps/accounts | JWT HS256 existants, bcrypt/Django, profil et inscription sans attribution de privilège client |
| apps/core/models.py | 31 modèles managed=False, noms PostgreSQL qualifiés et clés composées |
| apps/core/registry.json | Métadonnées de 31 tables/48 vues ; aucun Prisma à l’exécution |
| apps/core/repository.py | Validation typée, pagination/comptages, écritures, audit transactionnel |
| apps/core/permissions.py | Droits globaux/locaux et refus des objets sans périmètre démontré |
| apps/core/ui_settings.py | Paramétrage T_Fk_Correspondance sans création de stockage au premier appel |
| apps/logistique | Lectures de vues, mutation de lignes, stock PostgreSQL et dashboard |
| apps/catalogue | Projections publiques explicites sans informations de connexion |
| apps/communication | Discussions limitées aux participants et gestionnaires de structure |
| requirements.txt | Dépendances Python verrouillées ; aucun paquet npm backend ni client Prisma conservé |

Les espaces public, connecté, administration et logistique gardent leurs préfixes. Le CRUD générique ne peut pas contourner les routes de stock, journaux ou règlements. L’API privée impose l’authentification puis les droits à chaque requête. L’administration reste celle de React ; les tables natives auth/admin/contenttypes/sessions sont installées dans public et l’administration technique est accessible sur /django-admin/ du backend. Les comptes API métier restent dans systeme en attente d’un rapprochement explicite des identités.

La source analytics.T_Recherche est installée ; son registre GET est réservé à l’administration globale. Les identifiants client des commandes n’ont pas de FK assurant un référentiel tiers universel. L’organisation des objets logistiques est dérivée de l’auteur actuel ; les lignes vérifient commande et article. Le modèle multidevise et la propriété immuable demandent un chantier PostgreSQL distinct, non réalisé ici.

Voir [le bilan métier et technique](../../../../SQL/documentation/Audit_Metier_20261024.md) et [le guide de démarrage](../../../README.md).

Le socle natif est documenté dans [le bilan PostgreSQL](../../../../SQL/documentation/Django_Public_20261024.md). Les migrations du socle sont distinctes des scripts SQL métier.

## Filtres de colonnes et Excel des indicateurs

apps/logistique/table_queries.py valide columnFilters, les types de la vue, le tri et timeZone. Les identifiants SQL restent issus des métadonnées autorisées ; les valeurs sont liées comme paramètres. reads.read_scope et resolve_indicator sont communs aux listes et à excel.IndicatorExcelView. Le nombre de lignes exportées se calcule à partir des lignes réellement écrites, dans une lecture unique de la vue autorisée.

/api/logistique/indicateurs/<clé>/export.xlsx utilise XlsxWriter, déclaré dans l’unique requirements.txt. Les colonnes métier sont en liste blanche ; l’export n’expose pas d’identifiants utilisateur ni d’objets hors périmètre. La limite de 100 000 lignes produit un refus 413 explicite. Les nombres de plus de 15 chiffres significatifs restent en texte pour éviter une perte Excel et sont signalés dans Informations. Les identifiants, références et textes pouvant ressembler à des formules sont écrits comme texte. Les dates natives sont présentées dans le fuseau validé. La devise reste non renseignée si la source ne la porte pas.

Le logo et la charte proviennent de skills/document-mise-en-forme/assets. La recette du 25/10/2026 a contrôlé 26 exports statiques et une catégorie, les compteurs, les refus d’accès, les filtres et la limite ; les classeurs ont été relus avec openpyxl sur des données fictives et une lecture SQL protégée. Cette vérification n’est pas une certification d’affichage dans toutes les versions d’Office. Aucun schéma ni objet PostgreSQL n’a été modifié pour cette évolution.

## Registres et exports — 25 octobre 2026

Les routes GET /api/logistique/registre/articles/export.xlsx et /api/logistique/registre/commandes/export.xlsx réutilisent register_source puis read_scope ; elles partagent les critères métier, le tri et le périmètre des registres. Le générateur XLSX et sa charte restent communs aux indicateurs. L’export complet ignore take/skip, limite explicitement le volume à 100 000 lignes et valide les colonnes autorisées. Les critères du registre sont consignés dans Informations.

Dans les consultations, les clés du parent sont imposées côté serveur. Pour Produit 360, les bons et mouvements sont filtrés par ID_ArticleFk, les consommations/couvertures/contrôles par ID_Article. totalCount décrit aussi ce parent, avant recherche dans la rubrique ; filteredCount décrit sa liste affinée. Les paramètres clients ne peuvent remplacer le parent sélectionné.


## Dossiers de suivi logistiques (25/10/2026)

apps/logistique/followup_folders.py expose /api/logistique/dossiers-suivi : catalogue, liste paginée, aperçu POST sans écriture, export XLSX, catégories et mutations protégées. Les 11 dossiers standards calculent leurs effectifs via V_Article ou V_Commande ; les critères de bons/factures réutilisent INDICATORS. Compteur, détail, aperçu, consultation 360 et Excel passent par folder_scope. Les factures sont, dans le modèle actuel, les bons portant une référence de facture non vide ; leurs dates de filtre sont DateFacture. Les dates des bons restent DateCmd. Ne pas présenter ce modèle comme un nouveau registre comptable indépendant.

Les dossiers personnalisés portent un TypeObjet immuable (article/bon/facture), un mode immuable, une couleur, une catégorie, une version de concurrence et des critères contrôlés. Une catégorie n’est pas la catégorie métier de l’article. Les critères d’un autre type sont refusés. Les rattachements utilisent des FK réelles vers T_Article ou T_Commande, exclusives ; le type du dossier est vérifié avant l’écriture. Les métadonnées sont isolées par propriétaire ET organisation, même pour un administrateur global. Les lectures des objets restent soumises au périmètre ERP.

La migration additive SQL/migrations/20261025_01_dossiers_suivi.sql prépare trois tables, trois vues, leurs commentaires, contraintes et triggers. Elle ne touche pas aux stocks, mouvements, bons ni règlements. Elle est appliquée le 25/10 après sauvegarde et accord explicite du propriétaire. Les trois tables, trois vues, trois triggers et tous leurs commentaires de colonnes ont été vérifiés en base. L’absence de stockage laisse fonctionner les standards et rend customAvailable=false. Toutes les mutations appellent ensure_writable. Sur accord du propriétaire, backend/.env définit localement SAUVERNDEKO_DB_READ_ONLY=0 ; les rôles et périmètres existants restent exigés. Aucun GET ne crée de dossier ou de catégorie.

Contrôles observés : manage.py check ; verifier_backend 142 routes GET ; recette temporaire de 125 assertions sur SauverNdeko en transaction_read_only=on (parité compteurs/listes/aperçus/XLSX, filtres, colonnes et périmètres). SQL et corps PL/pgSQL analysés puis migration installée ; les triggers sont présents et activés. L’aperçu réel de bons non facturés et l’ouverture des formulaires Dossier/Article ont été vérifiés avec le compte administrateur autorisé. Aucune donnée de stock ou de commande n’a été ajoutée, modifiée ou supprimée pour la recette ; ces contrôles ne constituent pas un cycle CRUD réel sur des données clients.


Le classement manuel exige un responsable renseigné sur l’article ou le bon, conformément au trigger installé. L’API retourne OWNER_REQUIRED avant toute écriture si ce responsable manque ; le 360 l’annonce explicitement. Les dossiers automatiques restent des sélections du registre autorisé. Cette règle ne change ni les droits de consultation ni les rôles des comptes.


## Notifications personnelles

[notifications.py](../../../apps/communication/notifications.py) expose GET /api/notifications?read=all|unread&page=1&pageSize=20 depuis communication.V_Communication, sans migration. Les communications doivent être actives, destinées au compte connecté et rattachées à son entité actuelle ou sans entité. Ce périmètre reste imposé à l’administrateur global. La permission explicite IsAuthenticated permet cette fonction personnelle indépendamment des licences métier, sans ouvrir les notifications d’autres comptes.

Chaque élément contient id, title, body, createdAt et read. Le titre vient du type enregistré, avec Notification comme seul repli ; aucune URL de navigation n’est inventée. La pagination est plafonnée à 50. meta contient total, unreadCount, page, pageSize, hasNext, hasPrevious et canMarkRead. total suit le filtre de lecture ; unreadCount compte toutes les communications non lues du même périmètre, indépendamment de la page et du filtre.

PATCH /api/notifications/<id>/read accepte un corps vide ou {"read":true}. Il vérifie de nouveau destinataire et entité, verrouille la ligne et modifie seulement LectureCommunication. L’audit minimal partage la transaction ; une notification déjà lue ne produit pas une seconde écriture. Le PATCH renvoie l’élément et meta.total/unreadCount/canMarkRead. canMarkRead reflète DB_READ_ONLY : le mode lecture seule refuse le PATCH avant tout SQL. Un identifiant d’un autre utilisateur ou d’une autre entité retourne 404, même pour l’administrateur global. Les messages T_Chat et LuChat ne constituent pas ce compteur personnel.


## Photo du compte connecté (25/10/2026)

`POST /SauverNdeko/auth/me/photo` reçoit un formulaire multipart avec `payload` (objet JSON de champs personnels modifiés) et `photo` (fichier facultatif). `_removePhoto: true` dans le payload retire la photo et ne se combine pas avec un nouveau fichier. Le serveur valide tout puis enregistre les champs et la photo ensemble ; une annulation du formulaire ne téléverse aucun fichier. Le retour reste le profil courant, comme `PUT /SauverNdeko/auth/me` en JSON. Ces deux parcours partagent validation, verrouillage du compte personnel, audit transactionnel et compensation des fichiers en cas d’échec. Aucun rôle, licence ni rattachement n’est modifiable dans ce formulaire.

Les fichiers JPEG, PNG et WebP valides sont limités à 8 Mo et 24 millions de pixels, redimensionnés et réencodés en JPEG sans métadonnées avec le normaliseur déjà utilisé pour les articles. Le nom fourni par le navigateur n’est pas utilisé : `UrlPhoto` conserve un chemin `Profils/<IdUser>_<uuid>.jpg` sous `ARTICLE_MEDIA_ROOT`. Les anciennes photos gérées par ce compte sont supprimées après validation de la transaction ; aucun fichier extérieur ni appartenant à un autre compte ne peut être supprimé. Les liens de photos historiques peuvent rester en place tant qu’ils ne sont pas remplacés.

`GET /SauverNdeko/auth/me/photo` exige la session et sert uniquement la photo du compte connecté, sans identifiant utilisateur ni chemin libre dans la requête. Le frontend charge ce binaire avec le jeton habituel puis utilise une URL objet locale ; ne pas rendre le dossier Profils public ni placer de jeton dans une URL. Absence et refus donnent un avatar local à initiales. Le mode lecture seule interdit toute écriture avant SQL ou stockage, y compris le téléversement.


## Devises logistiques — 25/10/2026

Le référentiel Devise est la source des choix de monnaie. currency.py résout sa catégorie active et les références actives, normalise EURO en EUR et exige une entrée USD active unique comme défaut des nouveaux articles et bons. Ne pas figer l’identifiant numérique de USD dans React ou Python. Les montants historiques ne sont rattachés à USD que sur l’instruction explicite du propriétaire ; le défaut de création ne constitue pas une preuve sur une ancienne donnée.

Les champs ID_DeviseFk, DeviseCode et DeviseLibelle accompagnent les projections monétaires. /api/logistique/references fournit currencies [{id,code,label}], defaultCurrencyId et defaultCurrencyCode ; les articles de référence portent currencyId/currencyCode/currencyLabel. Les bons, règlements et mouvements conservent leur propre monnaie historique. Un règlement hérite de la facture et ne peut recevoir une autre devise. Un bon possédant une ligne, un mouvement ou une facture ne change plus de devise ; l’article expose canChangeCurrency et inclut la devise dans sa révision de concurrence.

PUCmdDetail est un prix dans la devise du bon. Si le catalogue de l’article est dans une autre monnaie, une nouvelle ligne exige un prix explicitement fourni : aucun taux ni conversion automatique n’est appliqué. Le frontend ne copie alors pas le prix du catalogue. Les triggers restent responsables des mouvements et totaux ; le backend n’ajoute aucun deuxième effet de stock.

Le critère deviseId, numérique positif ou sans-devise, reste dans le prédicat commun des synthèses, détails, registres et exports. Pour les sorties mensuelles d’un article, V_ConsoMensuelle conserve le grain Article/Mois et fournit MontantsParDevise ; son montant scalaire est absent si plusieurs monnaies sont présentes. V_ConsoMensuelleDevise, grain Article/Mois/Devise, sert la consultation filtrée par devise. Ne pas retirer un mois complet en filtrant sa seule devise scalaire lorsqu’il contient plusieurs monnaies.

Les montants de synthèse sont regroupés côté serveur : data.amountsByCurrency[clé] contient [{id,code,label,value,count}] pour montantBons, montantTotalFacture, montantTotalRegle et montantRestant. Le détail d’indicateur fournit meta.indicator.amountsByCurrency. Le total scalaire reste disponible pour une unique devise connue, vaut zéro pour un ensemble vide et reste absent pour plusieurs monnaies. Les valeurs Decimal demeurent exactes dans JSON. L’ancien endpoint dashboard reprend les mêmes agrégats sans renvoyer une somme de USD et CDF.

Excel ajoute la colonne Devise lorsque des montants sont exportés, même si cette colonne a été masquée à l’écran ; une source sans devise est refusée pour cet export monétaire. Une ventilation MontantsParDevise disponible est conservée. La feuille Informations recense les monnaies des lignes réellement écrites et le filtre appliqué. Les montants restent numériques, sauf précision supérieure à quinze chiffres conservée en texte pour éviter une perte Excel. Les en-têtes restent à la première ligne selon la charte.

## Changement du mot de passe personnel — 25/10/2026

Le parcours /SauverNdeko/auth/me/password concerne uniquement le compte authentifié. POST reçoit currentPassword, newPassword et confirmPassword sans trim ; le nouveau secret comporte 12 à 128 points de code, diffère du secret actuel et passe les validateurs Django de longueur, similarité, mot de passe trop courant et valeur entièrement numérique. Le secret actuel accepte au plus 1 024 caractères. Une validation refusée renvoie 400 PASSWORD_CHANGE_VALIDATION avec les champs concernés ; un secret actuel erroné ne renvoie pas 401. Préserver le refus de lecture seule 503 READ_ONLY et la limitation 429 à cinq tentatives par minute.

Verrouiller le compte personnel et conserver changement, audit minimal PASSWORD_CHANGE et contrôle de concurrence dans la transaction. Aucun mot de passe ni hash de mot de passe, et aucun ancien/nouveau corps de requête dans les réponses ou journaux d’audit. Les jetons d’accès et de renouvellement nouvellement émis portent une version pwdv par HMAC, vérifiée contre le compte courant : une modification invalide les anciens jetons du compte. Les jetons historiques sans version restent acceptés avant le premier changement audité et sont ensuite refusés pour ce compte ; le déploiement seul ne déconnecte pas tous les comptes. Le reset administrateur existant utilise le même marqueur de révocation. Après succès, le client termine sa session locale et demande une nouvelle connexion.

## Bons de stock et lignes

GET /api/logistique/registre/lignes et /export.xlsx réutilisent V_CommandeDetail, read_scope et les mêmes filtres autorisés (bon, article, type, statut, devise, période et état). La recherche et le comptage précèdent la pagination. Ne pas additionner les quantités d’articles d’unités différentes. L’export conserve unité et devise avec les cellules typées et les en-têtes en première ligne.

Document_rules fournit la révision des bons et lignes. Les GET d’édition projettent les colonnes brutes de T_Commande/T_CommandeDetail avec l’enrichissement de leur vue dans un même instantané SQL ; les lots appartiennent à celui de la ligne. Ne pas calculer une révision d’édition sur un COALESCE d’affichage. PUT/DELETE exigent _version. Les conflits renvoient ORDER_CONFLICT ou LINE_CONFLICT (409), sans écriture partielle.

La mutation d’une ligne verrouille le parent puis les articles, valide un prix explicite (zéro autorisé), les références actives à la création/changement, les lots et la capacité numeric(12,2) du total avant l’écriture. L’identité composée d’une ligne existante est conservée. Aucun mouvement de stock n’est ajouté en Python ; l’audit partage la transaction.

Un bon clôturé est protégé selon fn_commande_cloturee ; « facturée » ne signifie pas à elle seule « clôturée ». Le type et la devise ne changent plus après les écritures liées, et le code de facture est conservé après un règlement. Supprimer un bon exige qu’il soit vide, sans facture, historique, règlement ou classement ; le verrou fort avant ce contrôle empêche un rattachement concurrent. Les auteurs et dates automatiques restent contrôlés par le serveur.

### Création atomique du bon et du panier

POST /api/logistique/commandes/composees reçoit requestId UUID, bon et lignes (1 à 50 articles distincts). order_composer réutilise mutate(T_Commande) et mutate_line dans une transaction unique : toute erreur annule aussi l’en-tête et les mouvements déclenchés. Les triggers existants restent seuls responsables du stock. Valider références, organisation, article actif, sens, quantité entière, prix explicite dans la devise du bon, lots et capacités numériques avant validation. Le catalogue /registre/articles?contexte=composition applique la même organisation que cette écriture, y compris pour un administrateur global ; le registre général conserve son périmètre habituel.

Un verrou transactionnel par acteur et UUID et une preuve COMPOSE dans l’audit existant permettent de rejouer la demande après perte de réponse, sans nouvelle création. Le contenu canonique et l’organisation doivent être identiques ; sinon refuser le rejeu. Le résultat fournit bon, lignes et replayed (201 initial, 200 rejoué). Les erreurs utilisent bon.<champ> ou lignes.<indice_original>.<champ>, même si les verrous sont pris dans un ordre stable. Aucun schéma ou trigger supplémentaire n’est nécessaire pour ce parcours.

### Numéro automatique des bons

La création centrale T_Commande appelle fn_reserver_identite_commande(), qui réserve une seule valeur de son identité PostgreSQL existante et retourne ID_Commande + CodeCmd. fn_code_commande(id) produit cmd- suivi de cet identifiant, sans zéros ajoutés ; fn_code_facture(idBon) produit fac- suivi de l’identifiant du bon, sans consommer la séquence des commandes. Les triggers imposent les codes canoniques et leur conservation. Ne pas utiliser MAX+1, un compteur du navigateur, un UUID affiché ni une seconde allocation Python. Une séquence peut présenter des trous après abandon d’une transaction ; ne pas réutiliser ces numéros.

CodeCmd est généré au point d’écriture partagé, pas par compose_order ou receive_article. Refuser un code imposé à la création et toute modification effective après création, quel que soit le rôle. La migration 20261025_08, explicitement autorisée par le propriétaire, renumérote les documents actuels et leurs références financières atomiquement, en conservant la correspondance dans l’audit. En exploitation normale, aucune lecture ne complète ni ne renumérote un code. Le rejeu COMPOSE/RECEIVE retrouve le bon et son code avant toute allocation supplémentaire et garde la compatibilité des empreintes historiques. Les tests de numérotation sont isolés ; ne pas consommer la séquence de la base client pour une recette.


## Composition, restitutions et instantanés de facture

GET /api/logistique/commandes/{id}/composition recharge dans un même instantané le bon brut, toutes ses lignes et leur ventilation. PUT sur cette route applique le panier complet et les changements d’en-tête sous la même transaction, avec révision globale et UUID stable. Les diminutions/retraits précèdent les augmentations ; les articles sont verrouillés dans un ordre stable. Conserver auteur, numéros automatiques, informations inconnues à NULL et lignes historiques inchangées. Après une réponse perdue, le rejeu ne réapplique pas les mouvements.

La migration 20261025_06_retours_physiques.sql ajoute T_RetourBon et les vues V_RetourArticle/V_RetourLot/V_RetourBon. Un événement de retour partiel ou complet relie un bon de sortie à son propre bon d’entrée inverse. Plusieurs événements sont possibles tant que le cumul par article et lot ne dépasse pas la sortie ; la part sans lot est un budget séparé. Le PU est celui du mouvement historique, la devise reste celle de la sortie et les triggers existants réalisent le crédit de stock. Aucune deuxième mise à jour de QteArticle ni création Python de mouvement. Le lien, les documents de stock et les ventilations deviennent immuables. Les lots archivés ou articles inactifs peuvent être reçus dans cette seule portée interne de compensation, sans réactivation du catalogue ni drapeau client.

Le service GET/POST /commandes/{id}/retours contrôle droits, organisation du bon, sens sortie, révision, motif, quantités et lots restants. Verrouiller l’origine avant calcul et validation ; le couple auteur/UUID avec empreinte empêche un double crédit. Une source clôturée peut être compensée par une entrée distincte sans être déclôturée. Les anciens booléens de remise ne sont pas la preuve d’un événement de restitution.

La migration 20261025_07_factures_snapshots.sql ajoute T_Facture/T_FactureLigne et leurs projections financières. GET/POST/PUT /commandes/{id}/facture partage la serrure du bon avec les restitutions, attribue une référence automatique et conserve les lignes à l’émission. Facturer les quantités nettes des retours déjà enregistrés ; ne pas modifier le montant stock original du bon pour cela. Les retours postérieurs alimentent MontantAvoirAEtablir/AvoirAEtablir sans diminuer silencieusement la facture ni produire de remboursement. L’émission réelle d’un avoir est un parcours financier distinct encore à raccorder. Les factures historiques sans instantané restent consultables ; une reprise contrôlée est requise pour leur édition.

MontantFacture porte le montant effectivement émis, MontantTTC de V_Commande conserve la valeur du bon de stock ; V_SuiviReglements utilise le total de facture et les règlements réels. Le tableau de bord facturation additionne MontantFacture par devise, jamais les anciennes quantités brutes des bons. Un délai de paiement vient d’une valeur explicite du référentiel (delayDays), pas de son identifiant. Aucun taux fiscal uniforme ni conversion de devise n’est introduit.

Les migrations exigent préconditions, sauvegarde et verrous courts ; elles refusent une installation partielle et vérifient les empreintes des documents historiques. Chaque nouvel objet/colonne reçoit COMMENT ON. Les tables métier restent unmanaged ; ne pas générer de migration Django concurrente. Les recettes de création/retour/facture sont réalisées sur un cluster privé ne contenant qu’une copie de structure et des données fictives, jamais sur la base client.
