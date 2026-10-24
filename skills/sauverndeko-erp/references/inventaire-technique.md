# Inventaire technique des sources

> Relevé historique de l’architecture Express/Prisma avant conversion. Depuis le choix ultérieur du propriétaire le 24/10/2026, le backend actif est Django ; voir [le bilan actuel](../../../SQL/documentation/Audit_Metier_20261024.md). Les fichiers Node décrits ici ont depuis été supprimés à la demande du propriétaire. Leurs chemins ci-dessous sont historiques ; le registre actuel se trouve dans backend/apps/core/registry.json et les modèles dans backend/apps/core/models.py. La base est restée inchangée pendant la conversion.

Relevé initial du 24/10/2026. Les sections Prisma et routes décrivent cet état historique. Les sections SQL ci-dessous sont actualisées depuis les sources canoniques après la migration 04 et le nettoyage du dossier SQL ; elles restent une lecture de fichiers et non une nouvelle interrogation PostgreSQL. Les noms ci-dessous ne prouvent pas que les objets sont installés. node_modules, client Prisma généré, sorties Vite, sauvegardes binaires et fichiers privés sont exclus.

## Modèles Prisma

31 modèles, huit schémas dans backend/prisma/schema.prisma. Lors du relevé initial, les scripts SQL ne contenaient que 15 déclarations de tables distinctes. Les sources canoniques actuelles décrivent désormais les 31 tables métier.

| Schéma | Modèle | Clé déclarée |
|---|---|---|
| analytics | T_Recherche | IdRecherche        Int                      @id(map: "Pk_IdRecherche") @default(autoincrement()) |
| communication | T_Chat | IdChat         Int             @id @default(autoincrement()) |
| communication | T_Communication | IdCommunication      Int             @id(map: "Pk_IdCommunication") @default(autoincrement()) |
| geolocalisation | T_Niveau_0 | ID_Niveau_0      Int          @id @default(autoincrement()) |
| geolocalisation | T_Niveau_1_Old | ID_Niveau_1_Old      Int          @id @default(autoincrement()) |
| geolocalisation | T_Niveau_1 | ID_Niveau_1        Int             @id @default(autoincrement()) |
| geolocalisation | T_Niveau_2 | ID_Niveau_2                                              Int          @id @default(autoincrement()) |
| geolocalisation | T_Niveau_3 | ID_Niveau_3                                              Int                     @id @default(autoincrement()) |
| geolocalisation | T_Niveau_4 | ID_Niveau_4                                                Int                     @id @default(autoincrement()) |
| geolocalisation | T_Niveau_5 | ID_Niveau_5                                                Int                     @id @default(autoincrement()) |
| logistique | T_Article | ID_Article                                               Int                @id @default(autoincrement()) |
| logistique | T_Commande | ID_Commande                                                Int                @id @default(autoincrement()) |
| logistique | T_CommandeDetail | @@id([ID_ArticleFk, ID_CmdFk]) |
| logistique | T_Mouvement | ID_Mvt           Int          @id @default(autoincrement()) |
| logistique | T_Reglements | ID_Reglement       Int         @id @default(autoincrement()) |
| operations | T_Caisse | IdCaisse      Int         @id @default(autoincrement()) |
| operations | T_Paiement | IdPaiement         Int             @id(map: "Pk_IdPaiement") @default(autoincrement()) |
| operations | T_Paiement_Archive | IdPaiementArchive  Int       @id @default(autoincrement()) |
| professionnel | T_Professionnel | IdProfessionnel        Int                      @id(map: "Pk_IdProfessionnel") @default(autoincrement()) |
| professionnel | T_Professionnel_Entite | @@id([IdProfessionnelFk, IdEntiteFk], map: "Pk_Professionnel_Entite") |
| referentiel | T_CategorieGenerique | ID_CategorieGenerique    Int                   @id @default(autoincrement()) |
| referentiel | T_Generique | ID_Generique                                              Int                      @id(map: "Pk_T_Generique") @default(autoincrement()) |
| systeme | T_Audit_Log | IdLog      Int       @id @default(autoincrement()) |
| systeme | T_Fk_Correspondance | IdFkCorrespondance     Int                   @id @default(autoincrement()) |
| systeme | T_Entite | IdEntite               Int                      @id(map: "Pk_IdEntite") @default(autoincrement()) |
| systeme | T_Entite_Localisation | IdEntiteLocalisation Int         @id(map: "Pk_IdEntiteLocalisation") @default(autoincrement()) |
| systeme | T_Licence | IdLicence         Int         @id(map: "Pk_IdLicence") |
| systeme | T_Login | IdLogin        Int            @id(map: "Pk_IdLogin") @default(autoincrement()) |
| systeme | T_Utilisateurs | IdUser               Int                   @id(map: "Pk_IdUser") @default(autoincrement()) |
| communication | T_Discussion | IdDiscussion      Int              @id @default(autoincrement()) |
| systeme | T_Admin_UI_Setting | IdAdminUISetting Int             @id(map: "Pk_Admin_UI_Setting") @default(autoincrement()) |

## Préfixes REST modulaires

25 montages dans backend/src/modules/register-module-routes.js. Chaque export provient de l’index du domaine ; lire ensuite l’index du sous-module. La protection du chemin monté doit être vérifiée indépendamment des anciens routeurs.

| Préfixe | Export monté |
|---|---|
| /api/referentiel/categories-generiques | referentielModules.categorieGenerique.router |
| /api/referentiel/generiques | referentielModules.generique.router |
| /api/systeme/utilisateurs | systemeModules.utilisateur.router |
| /api/systeme/entites | systemeModules.entite.router |
| /api/systeme/entite-localisations | systemeModules.entiteLocalisation.router |
| /api/systeme/licences | systemeModules.licence.router |
| /api/systeme/logins | systemeModules.login.router |
| /api/systeme/audit-logs | systemeModules.auditLog.router |
| /api/systeme/fk-correspondances | systemeModules.fkCorrespondance.router |
| /api/systeme/admin-ui-settings | systemeModules.adminUiSetting.router |
| /api/logistique/articles | logistiqueModules.article.router |
| /api/logistique/commandes | logistiqueModules.commande.router |
| /api/logistique/commande-details | logistiqueModules.commandeDetail.router |
| /api/logistique/reglements | logistiqueModules.reglement.router |
| /api/logistique/mouvements | logistiqueModules.mouvement.router |
| /api/logistique/stock | logistiqueModules.stock.router |
| /api/logistique/dashboard | logistiqueModules.dashboard.router |
| /api/geolocalisation/niveau-0 | geolocalisationModules.niveau0.router |
| /api/geolocalisation/niveau-1-old | geolocalisationModules.niveau1Old.router |
| /api/geolocalisation/niveau-1 | geolocalisationModules.niveau1.router |
| /api/geolocalisation/niveau-2 | geolocalisationModules.niveau2.router |
| /api/geolocalisation/niveau-3 | geolocalisationModules.niveau3.router |
| /api/geolocalisation/niveau-4 | geolocalisationModules.niveau4.router |
| /api/geolocalisation/niveau-5 | geolocalisationModules.niveau5.router |
| /api/geolocalisation/hierarchie | geolocalisationModules.hierarchie.router |

## Routes et fabriques

Les déclarations locales suivantes sont extraites des index de sous-modules et fichiers .routes.js. Elles peuvent coexister avec des routes historiques. Le chemin HTTP complet résulte du montage dans app.js/register-module-routes.js ; cette liste n’est pas un test HTTP. Les modules construits par buildStandardModule ajoutent GET /, /search, /:id et, sauf readOnly, POST /, PUT /:id, DELETE /:id dans module-kit.js.

- backend/routes/auth.routes.js : POST /auth/login ; POST /auth/register ; POST /auth/refresh ; POST /auth/logout ; GET /auth/me ; PUT /auth/me ; GET /auth/verify
- backend/routes/discussion.routes.js : POST /start ; GET / ; GET /:id/messages ; POST /:id/messages
- backend/routes/domain.routes.js : GET /utilisateurs ; GET /utilisateurs/:id ; POST /utilisateurs ; PUT /utilisateurs/:id ; DELETE /utilisateurs/:id ; GET /entites ; GET /entites/:id ; POST /entites ; PUT /entites/:id ; DELETE /entites/:id ; GET /licences ; GET /licences/:id ; POST /licences ; PUT /licences/:id ; DELETE /licences/:id ; GET /articles ; GET /articles/:id ; POST /articles ; PUT /articles/:id ; DELETE /articles/:id ; GET /recherches ; GET /recherches/:id ; POST /recherches ; DELETE /recherches/:id ; GET /commandes ; GET /commandes/:id ; POST /commandes ; PUT /commandes/:id ; DELETE /commandes/:id
- backend/routes/index.routes.js : GET /models ; GET /models/:model ; GET /models/:model/:id ; POST /models/:model ; PUT /models/:model/:id ; DELETE /models/:model/:id ; GET /admin-ui-settings ; GET /admin-ui-settings/audit ; PUT /admin-ui-settings
- backend/routes/logistique.legacy.routes.js : GET /references ; GET /commandes/:id/details ; POST /commandes/:id/details ; PUT /commandes/:id/details/:articleId ; DELETE /commandes/:id/details/:articleId ; GET /stock/audit ; GET /stock/alertes ; GET /stock/consommation ; GET /stock/couverture ; GET /commandes-sans-details ; GET /reglements/entries
- backend/routes/logistique.routes.js : GET /dashboard ; GET /references ; GET /articles ; POST /articles ; PUT /articles/:id ; DELETE /articles/:id ; GET /commandes ; POST /commandes ; PUT /commandes/:id ; DELETE /commandes/:id ; GET /commandes/:id/details ; GET /mouvements ; POST /commandes/:id/details ; PUT /commandes/:id/details/:articleId ; DELETE /commandes/:id/details/:articleId ; GET /stock/audit ; GET /stock/alertes ; GET /stock/consommation ; GET /stock/couverture ; GET /commandes-sans-details ; GET /reglements/entries ; GET /reglements ; POST /reglements ; PUT /reglements/:id
- backend/routes/public.routes.js : GET /stats ; GET /articles ; GET /pharmacies ; GET /experts ; GET /maladies ; GET /chat/context
- backend/routes/views.routes.js : GET / ; GET /:schema/:view
- backend/src/modules/geolocalisation/hierarchie/index.js : GET /children/:level/:id ; GET /
- backend/src/modules/geolocalisation/niveau-0/index.js : fabrique standard
- backend/src/modules/geolocalisation/niveau-1/index.js : fabrique standard
- backend/src/modules/geolocalisation/niveau-1-old/index.js : fabrique standard
- backend/src/modules/geolocalisation/niveau-2/index.js : fabrique standard
- backend/src/modules/geolocalisation/niveau-3/index.js : fabrique standard
- backend/src/modules/geolocalisation/niveau-4/index.js : fabrique standard
- backend/src/modules/geolocalisation/niveau-5/index.js : fabrique standard
- backend/src/modules/logistique/article/index.js : GET /search ; GET /:id ; GET / ; POST / ; PUT /:id ; DELETE /:id
- backend/src/modules/logistique/commande/index.js : GET /search ; GET /:id ; GET / ; POST / ; PUT /:id ; DELETE /:id
- backend/src/modules/logistique/commande-detail/index.js : GET /search ; GET /:commandeId/:articleId ; GET / ; POST / ; PUT /:commandeId/:articleId ; DELETE /:commandeId/:articleId
- backend/src/modules/logistique/dashboard/index.js : GET /
- backend/src/modules/logistique/mouvement/index.js : GET /search ; GET /:id ; GET /
- backend/src/modules/logistique/reglement/index.js : GET /search ; GET /entries ; GET /:id ; GET / ; POST / ; PUT /:id ; DELETE /:id
- backend/src/modules/logistique/stock/index.js : GET /alertes ; GET /audit ; GET /consommation ; GET /couverture ; GET /
- backend/src/modules/referentiel/categorie-generique/categorie-generique.routes.js : GET /search ; GET /:id ; GET / ; POST / ; PUT /:id ; DELETE /:id
- backend/src/modules/referentiel/generique/generique.routes.js : GET /search ; GET /categorie/:categorieId ; GET /:id ; GET / ; POST / ; PUT /:id ; DELETE /:id
- backend/src/modules/systeme/admin-ui-setting/index.js : GET /audit ; GET /search ; GET /:id ; GET / ; POST / ; PUT / ; PUT /:id ; DELETE /:id ; fabrique standard
- backend/src/modules/systeme/audit-log/index.js : fabrique standard
- backend/src/modules/systeme/entite/index.js : fabrique standard
- backend/src/modules/systeme/entite-localisation/index.js : fabrique standard
- backend/src/modules/systeme/fk-correspondance/index.js : fabrique standard
- backend/src/modules/systeme/licence/index.js : fabrique standard
- backend/src/modules/systeme/login/index.js : fabrique standard
- backend/src/modules/systeme/utilisateur/index.js : fabrique standard

## Objets SQL déclarés

Inventaire des quinze extraits canoniques des huit domaines, après la migration 04 : 31 tables, 48 vues, 31 fonctions, six procédures et 30 triggers. Le schéma operations ne contient aucune vue installée. Les définitions complètes, contraintes et commentaires figurent dans les fichiers indiqués ; voir aussi le [guide SQL](../../../SQL/README.md).

### TABLE

| Objet | Source canonique |
|---|---|
| referentiel."T_Generique" | SQL/0. Schema referentiel/Referentiel_Tables.sql |
| referentiel."T_CategorieGenerique" | SQL/0. Schema referentiel/Referentiel_Tables.sql |
| systeme."T_Entite" | SQL/1. Schema systeme/Systeme_Tables.sql |
| systeme."T_Utilisateurs" | SQL/1. Schema systeme/Systeme_Tables.sql |
| systeme."T_Entite_Localisation" | SQL/1. Schema systeme/Systeme_Tables.sql |
| systeme."T_Admin_UI_Setting" | SQL/1. Schema systeme/Systeme_Tables.sql |
| systeme."T_Audit_Log" | SQL/1. Schema systeme/Systeme_Tables.sql |
| systeme."T_Fk_Correspondance" | SQL/1. Schema systeme/Systeme_Tables.sql |
| systeme."T_Licence" | SQL/1. Schema systeme/Systeme_Tables.sql |
| systeme."T_Login" | SQL/1. Schema systeme/Systeme_Tables.sql |
| operations."T_Caisse" | SQL/2. Schema operations/Operations_Tables.sql |
| operations."T_Paiement" | SQL/2. Schema operations/Operations_Tables.sql |
| operations."T_Paiement_Archive" | SQL/2. Schema operations/Operations_Tables.sql |
| logistique."T_Article" | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique."T_Commande" | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique."T_CommandeDetail" | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique."T_Mouvement" | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique."T_Reglements" | SQL/3. Schema logistique/Logistique_Tables.sql |
| geolocalisation."T_Niveau_0" | SQL/4. Schema geolocalisation/geolocalisation_Tables.sql |
| geolocalisation."T_Niveau_1" | SQL/4. Schema geolocalisation/geolocalisation_Tables.sql |
| geolocalisation."T_Niveau_1_Old" | SQL/4. Schema geolocalisation/geolocalisation_Tables.sql |
| geolocalisation."T_Niveau_2" | SQL/4. Schema geolocalisation/geolocalisation_Tables.sql |
| geolocalisation."T_Niveau_3" | SQL/4. Schema geolocalisation/geolocalisation_Tables.sql |
| geolocalisation."T_Niveau_4" | SQL/4. Schema geolocalisation/geolocalisation_Tables.sql |
| geolocalisation."T_Niveau_5" | SQL/4. Schema geolocalisation/geolocalisation_Tables.sql |
| professionnel."T_Professionnel" | SQL/5. Schema professionnel/Professionnel_Tables.sql |
| professionnel."T_Professionnel_Entite" | SQL/5. Schema professionnel/Professionnel_Tables.sql |
| analytics."T_Recherche" | SQL/6. Schema analytics/Analytics_Tables.sql |
| communication."T_Chat" | SQL/7. Schema communication/Communication_Tables.sql |
| communication."T_Communication" | SQL/7. Schema communication/Communication_Tables.sql |
| communication."T_Discussion" | SQL/7. Schema communication/Communication_Tables.sql |

### VIEW

| Objet | Source canonique |
|---|---|
| referentiel."V_CategorieGenerique" | SQL/0. Schema referentiel/Referentiel_views.sql |
| referentiel."V_Generique" | SQL/0. Schema referentiel/Referentiel_views.sql |
| systeme."V_Admin_UI_Setting" | SQL/1. Schema systeme/Systeme_View.sql |
| systeme."V_Admin_UI_Setting_Audit" | SQL/1. Schema systeme/Systeme_View.sql |
| systeme."V_Admin_UI_Setting_Group" | SQL/1. Schema systeme/Systeme_View.sql |
| systeme."V_Audit_log" | SQL/1. Schema systeme/Systeme_View.sql |
| systeme."V_Entite_Localisation_Detail" | SQL/1. Schema systeme/Systeme_View.sql |
| systeme."V_Entite_Public" | SQL/1. Schema systeme/Systeme_View.sql |
| systeme."V_Fk_Correspondance" | SQL/1. Schema systeme/Systeme_View.sql |
| systeme."V_Fk_Correspondance_Audit" | SQL/1. Schema systeme/Systeme_View.sql |
| systeme."V_Fk_Correspondance_Detail" | SQL/1. Schema systeme/Systeme_View.sql |
| systeme."V_Licence_active" | SQL/1. Schema systeme/Systeme_View.sql |
| systeme."V_Login_history" | SQL/1. Schema systeme/Systeme_View.sql |
| systeme."V_User_profil" | SQL/1. Schema systeme/Systeme_View.sql |
| logistique."V_Article" | SQL/3. Schema logistique/Logistique_View.sql |
| logistique."V_AlertStock" | SQL/3. Schema logistique/Logistique_View.sql |
| logistique."V_AuditStock" | SQL/3. Schema logistique/Logistique_View.sql |
| logistique."V_MouvementStock" | SQL/3. Schema logistique/Logistique_View.sql |
| logistique."V_AuditStock_Theorique" | SQL/3. Schema logistique/Logistique_View.sql |
| logistique."V_Commande" | SQL/3. Schema logistique/Logistique_View.sql |
| logistique."V_CommandeDetail" | SQL/3. Schema logistique/Logistique_View.sql |
| logistique."V_CommandeOverview" | SQL/3. Schema logistique/Logistique_View.sql |
| logistique."V_CommandesSansDetails" | SQL/3. Schema logistique/Logistique_View.sql |
| logistique."V_ConsoMensuelle" | SQL/3. Schema logistique/Logistique_View.sql |
| logistique."V_CouvertureStock" | SQL/3. Schema logistique/Logistique_View.sql |
| logistique."V_Mouvement" | SQL/3. Schema logistique/Logistique_View.sql |
| logistique."V_SuiviReglements" | SQL/3. Schema logistique/Logistique_View.sql |
| geolocalisation."V_AS_sans_Site" | SQL/4. Schema geolocalisation/geolocalisation_views.sql |
| geolocalisation."V_Niveau_0" | SQL/4. Schema geolocalisation/geolocalisation_views.sql |
| geolocalisation."V_Niveau_1" | SQL/4. Schema geolocalisation/geolocalisation_views.sql |
| geolocalisation."V_Niveau_1_Old" | SQL/4. Schema geolocalisation/geolocalisation_views.sql |
| geolocalisation."V_Niveau_2" | SQL/4. Schema geolocalisation/geolocalisation_views.sql |
| geolocalisation."V_Niveau_3" | SQL/4. Schema geolocalisation/geolocalisation_views.sql |
| geolocalisation."V_Niveau_4" | SQL/4. Schema geolocalisation/geolocalisation_views.sql |
| geolocalisation."V_Niveau_5" | SQL/4. Schema geolocalisation/geolocalisation_views.sql |
| geolocalisation."V_Pop_N3_Couverte_Sites" | SQL/4. Schema geolocalisation/geolocalisation_views.sql |
| geolocalisation."V_RESEAU_AS_par_ZS" | SQL/4. Schema geolocalisation/geolocalisation_views.sql |
| geolocalisation."V_Stats_N1_N2" | SQL/4. Schema geolocalisation/geolocalisation_views.sql |
| geolocalisation."V_Stats_N3_Structures" | SQL/4. Schema geolocalisation/geolocalisation_views.sql |
| geolocalisation."V_ZS_sans_AS" | SQL/4. Schema geolocalisation/geolocalisation_views.sql |
| professionnel."V_Professionnel_Detail" | SQL/5. Schema professionnel/Professionnel_views.sql |
| professionnel."V_Professionnel_Global" | SQL/5. Schema professionnel/Professionnel_views.sql |
| professionnel."V_Professionnel_Par_Entite" | SQL/5. Schema professionnel/Professionnel_views.sql |
| professionnel."V_Professionnel_Public" | SQL/5. Schema professionnel/Professionnel_views.sql |
| analytics."V_Recherche" | SQL/6. Schema analytics/Analytics_view.sql |
| communication."V_Chat" | SQL/7. Schema communication/Communication_views.sql |
| communication."V_Communication" | SQL/7. Schema communication/Communication_views.sql |
| communication."V_Communication_non_lues" | SQL/7. Schema communication/Communication_views.sql |

### FUNCTION

| Objet | Source canonique |
|---|---|
| referentiel.fn_guard_sens_stock | SQL/0. Schema referentiel/Referentiel_Tables.sql |
| systeme.audit_log_function | SQL/1. Schema systeme/Systeme_Tables.sql |
| systeme.fn_admin_ui_setting_set_updated_at | SQL/1. Schema systeme/Systeme_Tables.sql |
| systeme.fn_audit_sans_secrets | SQL/1. Schema systeme/Systeme_Tables.sql |
| systeme.format_phone_number | SQL/1. Schema systeme/Systeme_Tables.sql |
| systeme.notify_licence_expiry | SQL/1. Schema systeme/Systeme_Tables.sql |
| systeme.prevent_multiple_active_licenses | SQL/1. Schema systeme/Systeme_Tables.sql |
| systeme.prevention_delete_if_dependent | SQL/1. Schema systeme/Systeme_Tables.sql |
| systeme.update_date_modification | SQL/1. Schema systeme/Systeme_Tables.sql |
| systeme.update_licence_status | SQL/1. Schema systeme/Systeme_Tables.sql |
| operations.archive_paiements | SQL/2. Schema operations/Operations_Tables.sql |
| operations.fn_audit_caisse | SQL/2. Schema operations/Operations_Tables.sql |
| operations.fn_audit_flux_caisse | SQL/2. Schema operations/Operations_Tables.sql |
| operations.gestion_caisse_on_paiement | SQL/2. Schema operations/Operations_Tables.sql |
| operations.notification_payment_success | SQL/2. Schema operations/Operations_Tables.sql |
| operations.prevent_delete_caisse_if_dependent | SQL/2. Schema operations/Operations_Tables.sql |
| logistique.fn_assert_generique_category | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique.fn_audit_stock | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique.fn_commande_cloturee | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique.tr_crud_article_after | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique.tr_crud_article_before | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique.tr_crud_commande | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique.tr_crud_commandedetail | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique.tr_crud_reglement | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique.tr_delete_commande | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique.tr_guard_commandedetail | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique.tr_lock_commande_cloturee | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique.tr_lock_mouvement_direct | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique.tr_totaux_commande | SQL/3. Schema logistique/Logistique_Tables.sql |
| communication.fn_lock_discussion_message | SQL/7. Schema communication/Communication_Tables.sql |
| communication.fn_sync_dernier_message | SQL/7. Schema communication/Communication_Tables.sql |

### PROCEDURE

| Objet | Source canonique |
|---|---|
| logistique.ps_crud_article | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique.ps_crud_commande | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique.ps_crud_commandedetail | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique.ps_crud_reglement | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique.ps_update_qte_article | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique.ps_update_totaux_commande | SQL/3. Schema logistique/Logistique_Tables.sql |

### TRIGGER

| Objet | Source canonique |
|---|---|
| referentiel."T_Generique" : tr_guard_sens_stock | SQL/0. Schema referentiel/Referentiel_Tables.sql |
| systeme."T_Admin_UI_Setting" : tr_admin_ui_setting_set_updated_at | SQL/1. Schema systeme/Systeme_Tables.sql |
| systeme."T_Login" : "trigger_audit_T_Login" | SQL/1. Schema systeme/Systeme_Tables.sql |
| systeme."T_Utilisateurs" : "trigger_audit_T_Utilisateurs" | SQL/1. Schema systeme/Systeme_Tables.sql |
| systeme."T_Licence" : "trigger_audit_log_T_Licence" | SQL/1. Schema systeme/Systeme_Tables.sql |
| systeme."T_Utilisateurs" : trigger_format_phone_number | SQL/1. Schema systeme/Systeme_Tables.sql |
| systeme."T_Licence" : trigger_notify_licence_expiry | SQL/1. Schema systeme/Systeme_Tables.sql |
| systeme."T_Licence" : trigger_prevent_multiple_licenses | SQL/1. Schema systeme/Systeme_Tables.sql |
| systeme."T_Utilisateurs" : trigger_prevention_delete_utilisateur | SQL/1. Schema systeme/Systeme_Tables.sql |
| systeme."T_Utilisateurs" : trigger_update_date_modification | SQL/1. Schema systeme/Systeme_Tables.sql |
| systeme."T_Licence" : trigger_update_licence_status | SQL/1. Schema systeme/Systeme_Tables.sql |
| operations."T_Paiement" : trigger_archive_paiements | SQL/2. Schema operations/Operations_Tables.sql |
| operations."T_Paiement" : "trigger_audit_T_Paiement" | SQL/2. Schema operations/Operations_Tables.sql |
| operations."T_Paiement" : trigger_gestion_caisse_on_paiement | SQL/2. Schema operations/Operations_Tables.sql |
| operations."T_Paiement" : trigger_notification_payment_success | SQL/2. Schema operations/Operations_Tables.sql |
| operations."T_Caisse" : trigger_prevention_delete_caisse | SQL/2. Schema operations/Operations_Tables.sql |
| logistique."T_CommandeDetail" : tr_00_guard_commandedetail | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique."T_Article" : tr_crud_article_after | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique."T_Article" : tr_crud_article_before | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique."T_Commande" : tr_crud_commande | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique."T_CommandeDetail" : tr_crud_commandedetail | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique."T_Reglements" : tr_crud_reglement | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique."T_CommandeDetail" : tr_delete_commandedetail | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique."T_Commande" : tr_lock_commande_cloturee | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique."T_Mouvement" : tr_lock_mouvement_direct | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique."T_CommandeDetail" : tr_totaux_commande_delete | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique."T_CommandeDetail" : tr_totaux_commande_insert | SQL/3. Schema logistique/Logistique_Tables.sql |
| logistique."T_CommandeDetail" : tr_totaux_commande_update | SQL/3. Schema logistique/Logistique_Tables.sql |
| communication."T_Chat" : tr_00_lock_discussion_message | SQL/7. Schema communication/Communication_Tables.sql |
| communication."T_Chat" : tr_sync_dernier_message | SQL/7. Schema communication/Communication_Tables.sql |

## Couverture des commentaires dans les fichiers SQL

Comptage statique des instructions COMMENT ON dans les extraits actuels ; ce comptage ne prouve ni la justesse des textes ni leur installation dans une base. Le bilan de la migration 04 documente le contrôle PostgreSQL effectué.

| Fichier | COMMENT ON |
|---|---|
| SQL/0. Schema referentiel/Referentiel_Tables.sql | 37 |
| SQL/0. Schema referentiel/Referentiel_views.sql | 24 |
| SQL/1. Schema systeme/Systeme_Tables.sql | 236 |
| SQL/1. Schema systeme/Systeme_View.sql | 165 |
| SQL/2. Schema operations/Operations_Tables.sql | 84 |
| SQL/3. Schema logistique/Logistique_Tables.sql | 177 |
| SQL/3. Schema logistique/Logistique_View.sql | 281 |
| SQL/4. Schema geolocalisation/geolocalisation_Tables.sql | 206 |
| SQL/4. Schema geolocalisation/geolocalisation_views.sql | 233 |
| SQL/5. Schema professionnel/Professionnel_Tables.sql | 47 |
| SQL/5. Schema professionnel/Professionnel_views.sql | 78 |
| SQL/6. Schema analytics/Analytics_Tables.sql | 26 |
| SQL/6. Schema analytics/Analytics_view.sql | 4 |
| SQL/7. Schema communication/Communication_Tables.sql | 79 |
| SQL/7. Schema communication/Communication_views.sql | 46 |

## Sources frontend applicatives

Configurations, pages et composants présents, hors images et sorties de build :

- frontend/src/App.jsx
- frontend/src/components/AdminRoute.jsx
- frontend/src/components/ExpertCard.jsx
- frontend/src/components/HeroSection.jsx
- frontend/src/components/Navbar.jsx
- frontend/src/components/PharmacyCard.jsx
- frontend/src/components/ProductCard.jsx
- frontend/src/components/ProtectedRoute.jsx
- frontend/src/components/PublicTable.jsx
- frontend/src/components/StatsCards.jsx
- frontend/src/contexts/AuthContext.jsx
- frontend/src/data/mockData.js
- frontend/src/hooks/usePublicCatalogue.js
- frontend/src/main.jsx
- frontend/src/pages/admin/geolocalisation.js
- frontend/src/pages/admin/referentiel.js
- frontend/src/pages/admin/systeme.js
- frontend/src/pages/Admin.jsx
- frontend/src/pages/Discussions.jsx
- frontend/src/pages/Diseases.jsx
- frontend/src/pages/Experts.jsx
- frontend/src/pages/Home.jsx
- frontend/src/pages/Login.jsx
- frontend/src/pages/logistique/AlertesStock.jsx
- frontend/src/pages/logistique/Articles.jsx
- frontend/src/pages/logistique/CommandeDetails.jsx
- frontend/src/pages/logistique/Commandes.jsx
- frontend/src/pages/logistique/ConsommationMensuelle.jsx
- frontend/src/pages/logistique/CouvertureStock.jsx
- frontend/src/pages/logistique/DashboardLogistique.jsx
- frontend/src/pages/logistique/logistiqueShared.jsx
- frontend/src/pages/logistique/Mouvements.jsx
- frontend/src/pages/logistique/Reglements.jsx
- frontend/src/pages/logistique/StockAudit.jsx
- frontend/src/pages/logistique/views.js
- frontend/src/pages/Logistique.jsx
- frontend/src/pages/Pharmacies.jsx
- frontend/src/pages/Products.jsx
- frontend/src/pages/Profile.jsx
- frontend/src/pages/Register.jsx
- frontend/src/services/api.js
- frontend/src/services/auth.js
- frontend/src/services/authStorage.js
- frontend/src/services/logistique.js
- frontend/src/services/mappers.js
- frontend/src/styles.css

## Contrôles disponibles

- frontend/package.json : dev, build, preview ; aucun script test.
- backend/package.json : start, dev, prisma:generate, prisma:pull ; aucun script test ni migration SQL déclarée.
- Les scripts SQL *_Test.sql existent et peuvent contenir des écritures : les réserver à une base isolée après lecture.
- Les références de cartographie décrivent les écarts à valider, sans les corriger par cette livraison.


## Complément : catalogue installé et commentaires

L’inspection PostgreSQL du 24/10/2026 trouve 30 tables, 39 vues, 27 séquences, 25 fonctions, six procédures, 24 triggers, 232 contraintes, 142 index et 1020 colonnes dans les huit schémas applicatifs. Les 1553 objets/colonnes de ce périmètre sont maintenant commentés. Ces nombres décrivent la base installée, tandis que les sections précédentes décrivent les déclarations des fichiers avant cette livraison.

Consulter le [bilan et les migrations de commentaires](../../../SQL/documentation/Commentaires_PostgreSQL_20261024.md) pour la validation et les divergences entre dépôt et base.


## Fiabilisation logistique — évolution 20261024_02

La migration 02 est appliquée à la base locale : verrouillage des parents, totaux par instruction, clôture normalisée, alertes sans seuil, couverture sans jours futurs et audit SQL filtrable. Les données existantes sont inchangées ; les contrôles ont été exécutés sur une base de recette fictive. Les deux nouvelles fonctions et le remplacement d’un trigger par quatre portent la couverture globale à 1558 objets/colonnes commentés (27 fonctions, six procédures, 27 triggers ; autres familles inchangées).

Consulter le [bilan de fiabilisation](../../../SQL/documentation/Logistique_Fiabilisation_20261024.md). Les écarts de droits API, d’isolation et de calculs du dashboard frontend restent ouverts.
