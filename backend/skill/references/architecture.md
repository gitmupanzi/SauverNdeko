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

Voir [le bilan métier et technique](../../../SQL/documentation/Audit_Metier_20261024.md) et [le guide de démarrage](../../README.md).

Le socle natif est documenté dans [le bilan PostgreSQL](../../../SQL/documentation/Django_Public_20261024.md). Les migrations du socle sont distinctes des scripts SQL métier.

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
