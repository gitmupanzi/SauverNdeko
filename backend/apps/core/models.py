"""Modèles unmanaged générés depuis le catalogue PostgreSQL lu le 24/10/2026.
Le CRUD métier utilise les services SQL et les triggers existants.
"""

from django.db import models


class T_Chat(models.Model):
    IdChat = models.AutoField(primary_key=True)
    TextChat = models.TextField(null=True)
    ChatFile = models.TextField(null=True)
    ChatLink = models.TextField(null=True)
    AuthorIdFk = models.IntegerField(null=True)
    IdDiscussionFk = models.IntegerField(null=True)
    DateChat = models.DateTimeField()
    LuChat = models.BooleanField()

    class Meta:
        managed = False
        db_table = '"communication"."T_Chat"'


class T_Communication(models.Model):
    IdCommunication = models.AutoField(primary_key=True)
    IdUserFk = models.IntegerField(null=True)
    IdTypeCommunication = models.IntegerField(null=True)
    ContenuCommunication = models.TextField(null=True)
    DateCommunication = models.DateTimeField()
    ObsCommunication = models.TextField(null=True)
    ValideCommunication = models.BooleanField()
    LectureCommunication = models.BooleanField()
    IdEntiteFk = models.IntegerField(null=True)

    class Meta:
        managed = False
        db_table = '"communication"."T_Communication"'


class T_Niveau_0(models.Model):
    ID_Niveau_0 = models.AutoField(primary_key=True)
    NomNiveau_0 = models.TextField(null=True)
    CodeNiveau_0 = models.TextField(null=True)
    geometryNiveau_0 = models.TextField(null=True)

    class Meta:
        managed = False
        db_table = '"geolocalisation"."T_Niveau_0"'


class T_Niveau_1_Old(models.Model):
    ID_Niveau_1_Old = models.AutoField(primary_key=True)
    NomNiveau_1_Old = models.TextField(null=True)
    geometryNiveau_1_Old = models.TextField(null=True)
    surfaceNiveau_1_Old = models.TextField(null=True)

    class Meta:
        managed = False
        db_table = '"geolocalisation"."T_Niveau_1_Old"'


class T_Niveau_1(models.Model):
    ID_Niveau_1 = models.AutoField(primary_key=True)
    ID_Niveau_0_Fk = models.IntegerField(null=True)
    ID_Niveau_1_Old_Fk = models.IntegerField(null=True)
    NomNiveau_1 = models.TextField(null=True)
    Alt1_Niveau_1 = models.TextField(null=True)
    Alt2_Niveau_1 = models.TextField(null=True)
    AbreNiveau_1 = models.TextField(null=True)
    CodeSNIS = models.TextField(null=True)
    CodeNiveau_1 = models.TextField(null=True)
    PopulationNiveau_1 = models.DecimalField(max_digits=12, decimal_places=6, null=True)
    geometryNiveau_1 = models.TextField(null=True)
    surfaceNiveau_1 = models.TextField(null=True)
    timezoneNiveau_1 = models.TextField(null=True)
    wikidataNiveau_1 = models.TextField(null=True)
    EtenduNiveau_1 = models.TextField(null=True)
    ObsNiveau_1 = models.TextField(null=True)
    FusionNiveau_1 = models.BooleanField(null=True)
    VisibleNiveau_1 = models.BooleanField()
    VisibleNiveau_5 = models.BooleanField()
    LatitudeNiveau_1 = models.DecimalField(max_digits=9, decimal_places=6, null=True)
    LongitudeNiveau_1 = models.DecimalField(max_digits=9, decimal_places=6, null=True)

    class Meta:
        managed = False
        db_table = '"geolocalisation"."T_Niveau_1"'


class T_Niveau_2(models.Model):
    ID_Niveau_2 = models.AutoField(primary_key=True)
    ID_Niveau_1_FK = models.IntegerField(null=True)
    ID_TypeNiveau_2_Fk = models.IntegerField(null=True)
    NomNiveau_2 = models.TextField(null=True)
    Alt1_NomNiveau_2 = models.TextField(null=True)
    AbreNiveau_2 = models.TextField(null=True)
    CodeNiveau_2 = models.TextField(null=True)
    PopulationNiveau_2 = models.DecimalField(max_digits=12, decimal_places=6, null=True)
    geometryNiveau_2 = models.TextField(null=True)
    surfaceNiveau_2 = models.TextField(null=True)
    EtenduNiveau_2 = models.TextField(null=True)
    ObsNiveau_2 = models.TextField(null=True)
    ID_StatutNiveau_2 = models.IntegerField(null=True)
    ID_StatusDeploiFk = models.IntegerField(null=True)
    KmDPSANT = models.DecimalField(max_digits=10, decimal_places=2, null=True)
    ID_VoieAccesDPSANTFk = models.IntegerField(null=True)
    SelectNiveau_2 = models.BooleanField(null=True)
    LatitudeNiveau_2 = models.DecimalField(max_digits=9, decimal_places=6, null=True)
    LongitudeNiveau_2 = models.DecimalField(max_digits=9, decimal_places=6, null=True)
    AltitudeNiveau_2 = models.DecimalField(max_digits=10, decimal_places=2, null=True)

    class Meta:
        managed = False
        db_table = '"geolocalisation"."T_Niveau_2"'


class T_Niveau_3(models.Model):
    ID_Niveau_3 = models.AutoField(primary_key=True)
    ID_Niveau_2_FK = models.IntegerField(null=True)
    ID_TypeNiveau_2_Fk = models.IntegerField(null=True)
    NomNiveau_3 = models.TextField(null=True)
    Alt_Niveau_3 = models.TextField(null=True)
    surfaceNiveau_3 = models.TextField(null=True)
    geometryNiveau_3 = models.TextField(null=True)
    AbreNiveau_3 = models.TextField(null=True)
    CodeNiveau_3 = models.TextField(null=True)
    PopulationNiveau_3 = models.DecimalField(max_digits=12, decimal_places=6, null=True)
    EtenduNiveau_3 = models.TextField(null=True)
    ObsNiveau_3 = models.TextField(null=True)
    ID_StatutNiveau_3_Fk = models.IntegerField(null=True)
    ID_StatutDeploieFk = models.IntegerField(null=True)
    KmAntenneBCZS = models.DecimalField(max_digits=100, decimal_places=7, null=True)
    ID_VoieAccesANTBCZFk = models.IntegerField(null=True)
    KmDPSBCZS = models.DecimalField(max_digits=100, decimal_places=7, null=True)
    ID_VoieAccesDPSBCZFk = models.IntegerField(null=True)
    SelectNiveau_3 = models.BooleanField(null=True)
    LatitudeNiveau_3 = models.DecimalField(max_digits=13, decimal_places=5, null=True)
    LongitudeNiveau_3 = models.DecimalField(max_digits=13, decimal_places=5, null=True)
    AltitudeNiveau_3 = models.DecimalField(max_digits=10, decimal_places=7, null=True)

    class Meta:
        managed = False
        db_table = '"geolocalisation"."T_Niveau_3"'


class T_Niveau_4(models.Model):
    ID_Niveau_4 = models.AutoField(primary_key=True)
    ID_Niveau_3_Fk = models.IntegerField(null=True)
    ID_TypeNiveau_4_Fk = models.IntegerField(null=True)
    NomNiveau_4 = models.TextField(null=True)
    AbreNiveau_4 = models.TextField(null=True)
    CodeNiveau_4 = models.TextField(null=True)
    surfaceNiveau_4 = models.TextField(null=True)
    geometryNiveau_4 = models.TextField(null=True)
    ID_DispoReseauNiveau_4 = models.IntegerField(null=True)
    ID_VoieAccesZsASFk = models.IntegerField(null=True)
    ID_StatutNiveau_4 = models.IntegerField(null=True)
    ID_StatutDeploiementFk = models.IntegerField(null=True)
    ObsNiveau_4 = models.TextField(null=True)
    SelectNiveau_4 = models.BooleanField(null=True)
    LatitudeNiveau_4 = models.DecimalField(max_digits=13, decimal_places=6, null=True)
    LongitudeNiveau_4 = models.DecimalField(max_digits=13, decimal_places=6, null=True)
    AltitudeNiveau_4 = models.DecimalField(max_digits=10, decimal_places=2, null=True)
    PopulationNiveau_4 = models.DecimalField(max_digits=12, decimal_places=6, null=True)
    KmZoneSanteAS = models.DecimalField(max_digits=10, decimal_places=2, null=True)

    class Meta:
        managed = False
        db_table = '"geolocalisation"."T_Niveau_4"'


class T_Niveau_5(models.Model):
    ID_Niveau_5 = models.AutoField(primary_key=True)
    ID_Niveau_4_Fk = models.IntegerField(null=True)
    ID_Niveau_3_Fk = models.IntegerField(null=True)
    ID_TypeNiveau_5_Fk = models.IntegerField(null=True)
    NomNiveau_5 = models.TextField(null=True)
    AbreNiveau_5 = models.TextField(null=True)
    CodeNiveau_5 = models.TextField(null=True)
    PopulationNiveau_5 = models.DecimalField(max_digits=12, decimal_places=6, null=True)
    surfaceNiveau_5 = models.TextField(null=True)
    geometryNiveau_5 = models.TextField(null=True)
    ID_DispoReseauNiveau_5 = models.IntegerField(null=True)
    ID_VoieAccesZsSiteFk = models.IntegerField(null=True)
    ID_StatutNiveau_5 = models.IntegerField(null=True)
    ID_StatutDeploiementFk = models.IntegerField(null=True)
    ObsNiveau_5 = models.TextField(null=True)
    SelectNiveau_5 = models.BooleanField(null=True)
    ID_TypeToitFk = models.IntegerField(null=True)
    KmZoneSanteNiveau_5 = models.DecimalField(
        max_digits=12, decimal_places=2, null=True
    )
    LatitudeNiveau_5 = models.DecimalField(max_digits=12, decimal_places=6, null=True)
    LongitudeNiveau_5 = models.DecimalField(max_digits=12, decimal_places=6, null=True)
    AltitudeNiveau_5 = models.DecimalField(max_digits=12, decimal_places=2, null=True)

    class Meta:
        managed = False
        db_table = '"geolocalisation"."T_Niveau_5"'


class T_Article(models.Model):
    IdEntiteFk = models.IntegerField(null=True)
    ID_DeviseFk = models.IntegerField()
    PoidsUnitaire = models.DecimalField(max_digits=14, decimal_places=6, null=True)
    ID_UnitePoidsFk = models.IntegerField(null=True)
    InformationArticle = models.TextField(null=True)
    ID_Article = models.AutoField(primary_key=True)
    ID_TypeArticleFk = models.IntegerField(null=True)
    ID_CategorieArticleFk = models.IntegerField(null=True)
    ID_UserFK = models.IntegerField(null=True)
    ID_UniteFk = models.IntegerField(null=True)
    DateHeureAuto = models.DateTimeField(null=True)
    CodeArticleExterne = models.IntegerField(null=True)
    NomArticle = models.TextField()
    RefArticle = models.TextField(null=True)
    QteArticle = models.DecimalField(max_digits=14, decimal_places=3)
    PUArticle = models.DecimalField(max_digits=12, decimal_places=2)
    PVArticle = models.DecimalField(max_digits=12, decimal_places=2)
    QteMinArticle = models.DecimalField(max_digits=14, decimal_places=3, null=True)
    PhotoArticle = models.TextField(null=True)
    ObsArticle = models.TextField(null=True)
    ValideArticle = models.BooleanField()
    DatePeremptionArticle = models.DateTimeField(null=True)
    DatePeremptionAlerteArticle = models.DateTimeField(null=True)
    NbreJoursAlerteArticle = models.IntegerField(null=True)
    CodeArticleInterne = models.TextField(null=True)

    class Meta:
        managed = False
        db_table = '"logistique"."T_Article"'


class T_Commande(models.Model):
    ID_DestinationFk = models.IntegerField(null=True)
    IdEntiteFk = models.IntegerField(null=True)
    ID_TiersFk = models.BigIntegerField(null=True)
    ID_DeviseFk = models.IntegerField()
    ID_Commande = models.AutoField(primary_key=True)
    ID_TypeCmdFk = models.IntegerField(null=True)
    ID_StatutCmdFk = models.IntegerField(null=True)
    ID_ClientFk = models.IntegerField(null=True)
    ID_UserFk = models.IntegerField(null=True)
    geolocalisationCmd = models.TextField(null=True)
    DateHeureAutoCmd = models.DateTimeField(null=True)
    DateCmd = models.DateTimeField(null=True)
    CodeCmd = models.TextField(null=True)
    RefCmd = models.TextField(null=True)
    MontantHT = models.DecimalField(max_digits=12, decimal_places=2, null=True)
    MontantTTC = models.DecimalField(max_digits=12, decimal_places=2, null=True)
    UrlBL = models.TextField(null=True)
    ObsCmd = models.TextField(null=True)
    SelectCmd = models.BooleanField(null=True)
    DateHeureAutoFacture = models.DateTimeField(null=True)
    DateFacture = models.DateTimeField(null=True)
    CodeFacture = models.TextField(null=True)
    MontantRegleFacture = models.DecimalField(
        max_digits=12, decimal_places=2, null=True
    )
    MontantResteFacture = models.DecimalField(
        max_digits=12, decimal_places=2, null=True
    )
    StatusFacture = models.TextField(null=True)
    ValideRemiseFacture = models.BooleanField(null=True)
    UrlFacture = models.TextField(null=True)
    ID_ConditionPaiementFk = models.IntegerField(null=True)
    DateEcheancePaiement = models.DateTimeField(null=True)
    ID_ModePaiementFk = models.IntegerField(null=True)
    NomClientSaisi = models.TextField(null=True)

    class Meta:
        managed = False
        db_table = '"logistique"."T_Commande"'


class T_CommandeDetail(models.Model):
    pk = models.CompositePrimaryKey("ID_ArticleFk", "ID_CmdFk")
    ID_CmdFk = models.IntegerField()
    ID_ArticleFk = models.IntegerField()
    QteCmdDetail = models.DecimalField(max_digits=14, decimal_places=3, null=True)
    PUCmdDetail = models.DecimalField(max_digits=12, decimal_places=2, null=True)
    ObsCmdDetail = models.TextField(null=True)
    RemiseCmdDetail = models.BooleanField(null=True)
    LieuCmdDetail = models.IntegerField(null=True)
    SelectCmdDetail = models.BooleanField(null=True)

    class Meta:
        managed = False
        db_table = '"logistique"."T_CommandeDetail"'


class T_Mouvement(models.Model):
    ID_DeviseFk = models.IntegerField()
    ID_Mvt = models.AutoField(primary_key=True)
    ID_TypeMvtFk = models.IntegerField(null=True)
    ID_ArticleFk = models.IntegerField(null=True)
    ID_cmdFk = models.IntegerField(null=True)
    DateHeureAutoMvt = models.DateTimeField(null=True)
    DateMvt = models.DateTimeField(null=True)
    QteMvt = models.DecimalField(max_digits=14, decimal_places=3, null=True)
    PUMvt = models.DecimalField(max_digits=12, decimal_places=2, null=True)

    class Meta:
        managed = False
        db_table = '"logistique"."T_Mouvement"'


class T_Reglements(models.Model):
    ID_TiersFk = models.BigIntegerField(null=True)
    ID_DeviseFk = models.IntegerField()
    ID_Reglement = models.AutoField(primary_key=True)
    CodeFactureFk = models.TextField(null=True)
    ID_ModeReglementFk = models.IntegerField()
    ID_ClientFk = models.IntegerField(null=True)
    DateReglement = models.DateTimeField(null=True)
    MontantRegle = models.DecimalField(max_digits=12, decimal_places=2, null=True)

    class Meta:
        managed = False
        db_table = '"logistique"."T_Reglements"'


class T_Caisse(models.Model):
    IdCaisse = models.AutoField(primary_key=True)
    IdDeviseFk = models.IntegerField()
    MontantCaisse = models.DecimalField(max_digits=10, decimal_places=2, null=True)
    IdEntiteFk = models.IntegerField(null=True)

    class Meta:
        managed = False
        db_table = '"operations"."T_Caisse"'


class T_Paiement(models.Model):
    IdPaiement = models.AutoField(primary_key=True)
    CodePaiement = models.TextField(null=True)
    IdUserFk = models.IntegerField()
    IdTypePaiementFk = models.IntegerField()
    MontantPaiement = models.DecimalField(max_digits=10, decimal_places=2)
    IdStatutPaiementFk = models.IntegerField(null=True)
    DatePaiement = models.DateTimeField(null=True)
    ObsPaiement = models.TextField(null=True)
    ValidePaiement = models.BooleanField()
    IdDeviseFk = models.IntegerField()
    IdPayeurFk = models.IntegerField(null=True)
    IdTypeMouvementFk = models.IntegerField(null=True)
    IdEntiteFk = models.IntegerField()

    class Meta:
        managed = False
        db_table = '"operations"."T_Paiement"'


class T_Paiement_Archive(models.Model):
    IdPaiement = models.IntegerField(null=True)
    CodePaiement = models.TextField(null=True)
    IdUserFk = models.IntegerField(null=True)
    IdTypePaiementFk = models.IntegerField(null=True)
    MontantPaiement = models.DecimalField(max_digits=10, decimal_places=2, null=True)
    IdStatutPaiementFk = models.IntegerField(null=True)
    DatePaiement = models.DateTimeField(null=True)
    ObsPaiement = models.TextField(null=True)
    ValidePaiement = models.BooleanField(null=True)
    IdDeviseFk = models.IntegerField(null=True)
    IdPayeurFk = models.IntegerField(null=True)
    IdTypeMouvementFk = models.IntegerField(null=True)
    DateArchivage = models.DateTimeField(null=True)
    IdEntiteFk = models.IntegerField(null=True)
    IdPaiementArchive = models.AutoField(primary_key=True)

    class Meta:
        managed = False
        db_table = '"operations"."T_Paiement_Archive"'


class T_Professionnel(models.Model):
    IdProfessionnel = models.AutoField(primary_key=True)
    IdUserFk = models.IntegerField()
    IdTypeProfessionnelFk = models.IntegerField()
    IdSpecialiteFk = models.IntegerField()
    NumeroIdentification = models.TextField(null=True)
    ExperienceAns = models.IntegerField(null=True)
    ObsProfessionnel = models.TextField(null=True)
    ValideProfessionnel = models.BooleanField(null=True)

    class Meta:
        managed = False
        db_table = '"professionnel"."T_Professionnel"'


class T_Professionnel_Entite(models.Model):
    pk = models.CompositePrimaryKey("IdProfessionnelFk", "IdEntiteFk")
    IdProfessionnelFk = models.IntegerField()
    IdEntiteFk = models.IntegerField()
    IdTypeLienFk = models.IntegerField(null=True)
    DateDebut = models.DateTimeField(null=True)
    DateFin = models.DateTimeField(null=True)
    EstPrincipal = models.BooleanField(null=True)
    ObsLien = models.TextField(null=True)

    class Meta:
        managed = False
        db_table = '"professionnel"."T_Professionnel_Entite"'


class T_CategorieGenerique(models.Model):
    ID_CategorieGenerique = models.AutoField(primary_key=True)
    NomCategorieGenerique = models.TextField(null=True)
    ModuleCategorieGenerique = models.TextField(null=True)
    ValideCategorieGenerique = models.BooleanField(null=True)

    class Meta:
        managed = False
        db_table = '"referentiel"."T_CategorieGenerique"'


class T_Generique(models.Model):
    ID_Generique = models.AutoField(primary_key=True)
    ID_CategorieGeneriqueFk = models.IntegerField()
    NomGenerique = models.TextField()
    AbrGenerique = models.TextField(null=True)
    VisibleNiveau_2 = models.BooleanField(null=True)
    VisibleNiveau_3 = models.BooleanField(null=True)
    VisibleNiveau_4 = models.BooleanField(null=True)
    VisibleNiveau_5 = models.BooleanField(null=True)
    VisibleArticle = models.BooleanField(null=True)
    VisibleCmd = models.BooleanField(null=True)
    VisibleFacture = models.BooleanField(null=True)
    VisibleUsers = models.BooleanField(null=True)
    VisibleVoie = models.BooleanField(null=True)
    VisibleAll = models.BooleanField(null=True)
    ObsGenerique = models.TextField(null=True)
    ValideGenerique = models.BooleanField()

    class Meta:
        managed = False
        db_table = '"referentiel"."T_Generique"'


class T_Audit_Log(models.Model):
    IdLog = models.AutoField(primary_key=True)
    TableName = models.TextField(null=True)
    Operation = models.TextField(null=True)
    OldData = models.JSONField(null=True)
    NewData = models.JSONField(null=True)
    ChangedAt = models.DateTimeField(null=True)
    IdEntiteFk = models.IntegerField(null=True)

    class Meta:
        managed = False
        db_table = '"systeme"."T_Audit_Log"'


class T_Fk_Correspondance(models.Model):
    IdFkCorrespondance = models.AutoField(primary_key=True)
    ModuleName = models.TextField()
    SchemaName = models.TextField()
    ViewName = models.TextField(null=True)
    SourceKey = models.TextField()
    FieldName = models.TextField()
    FieldLabel = models.TextField(null=True)
    MappingType = models.TextField()
    ReferenceSchemaName = models.TextField(null=True)
    ReferenceObjectName = models.TextField(null=True)
    ReferenceFieldName = models.TextField(null=True)
    TargetCategoryIdFk = models.IntegerField(null=True)
    MappingValue = models.TextField()
    IsDefaultMapping = models.BooleanField()
    ValideFkCorrespondance = models.BooleanField()
    SettingScope = models.TextField()
    ScopeValue = models.TextField(null=True)
    DisplayOrder = models.IntegerField()
    UpdatedAt = models.DateTimeField()
    UpdatedByUserFk = models.IntegerField(null=True)
    ObsFkCorrespondance = models.TextField(null=True)

    class Meta:
        managed = False
        db_table = '"systeme"."T_Fk_Correspondance"'


class T_Entite(models.Model):
    IdEntite = models.AutoField(primary_key=True)
    NomEntite = models.TextField()
    PhoneEntite = models.TextField(null=True)
    EmailEntite = models.TextField()
    AdresseEntite = models.TextField(null=True)
    DateCreationEntite = models.DateTimeField(null=True)
    IdTypeEntiteFk = models.IntegerField(null=True)
    ValideEntite = models.BooleanField(null=True)

    class Meta:
        managed = False
        db_table = '"systeme"."T_Entite"'


class T_Entite_Localisation(models.Model):
    IdEntiteLocalisation = models.AutoField(primary_key=True)
    IdEntiteFk = models.IntegerField()
    IdNiveau_3_Fk = models.IntegerField(null=True)
    IdNiveau_4_Fk = models.IntegerField(null=True)
    IdNiveau_5_Fk = models.IntegerField(null=True)
    Latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True)
    Longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True)
    AdresseDetaillee = models.TextField(null=True)
    DateCreation = models.DateTimeField(null=True)

    class Meta:
        managed = False
        db_table = '"systeme"."T_Entite_Localisation"'


class T_Licence(models.Model):
    IdLicence = models.AutoField(primary_key=True)
    IdEntiteFk = models.IntegerField()
    CleLicence = models.TextField(null=True)
    DateDebut = models.DateTimeField(null=True)
    DateFin = models.DateTimeField()
    IdStatutLicenceFk = models.IntegerField()
    ValideLicence = models.BooleanField(null=True)
    ExpireeLicence = models.BooleanField(null=True)

    class Meta:
        managed = False
        db_table = '"systeme"."T_Licence"'


class T_Login(models.Model):
    IdLogin = models.AutoField(primary_key=True)
    IdUserFk = models.IntegerField()
    IdTypeLoginFk = models.IntegerField()
    DateLogin = models.DateTimeField()
    IdEntiteFk = models.IntegerField(null=True)

    class Meta:
        managed = False
        db_table = '"systeme"."T_Login"'


class T_Utilisateurs(models.Model):
    IdUser = models.AutoField(primary_key=True)
    NomUser = models.TextField()
    PrenomUser = models.TextField()
    EmailUser = models.TextField()
    MotdepasseUser = models.TextField()
    PhoneUser = models.TextField(null=True)
    DatecreationUser = models.DateTimeField(null=True)
    IdRoleFk = models.IntegerField(null=True)
    ValideUser = models.BooleanField()
    SexeUser = models.TextField()
    DateModificationUser = models.DateTimeField()
    UrlPhoto = models.TextField(null=True)
    IdEntiteFk = models.IntegerField(null=True)
    Is_staff = models.BooleanField()
    Is_Admin = models.BooleanField()

    class Meta:
        managed = False
        db_table = '"systeme"."T_Utilisateurs"'


class T_Discussion(models.Model):
    IdDiscussion = models.AutoField(primary_key=True)
    IdUserClientFk = models.IntegerField(null=True)
    IdProfessionnelFk = models.IntegerField(null=True)
    IdEntiteFk = models.IntegerField(null=True)
    TypeDiscussion = models.TextField()
    SujetDiscussion = models.TextField(null=True)
    DateCreation = models.DateTimeField()
    DernierMessageAt = models.DateTimeField(null=True)
    ValideDiscussion = models.BooleanField()

    class Meta:
        managed = False
        db_table = '"communication"."T_Discussion"'


class T_Admin_UI_Setting(models.Model):
    IdAdminUISetting = models.AutoField(primary_key=True)
    SettingScope = models.TextField()
    ScopeValue = models.TextField(null=True)
    SettingKey = models.TextField()
    SettingLabel = models.TextField(null=True)
    SettingGroup = models.TextField(null=True)
    SettingValue = models.TextField(null=True)
    SettingValueJson = models.JSONField(null=True)
    SettingType = models.TextField(null=True)
    DisplayOrder = models.IntegerField(null=True)
    IsEditable = models.BooleanField(null=True)
    IsSystem = models.BooleanField(null=True)
    ValideSetting = models.BooleanField(null=True)
    CreatedAt = models.DateTimeField(null=True)
    UpdatedAt = models.DateTimeField(null=True)
    UpdatedByUserFk = models.IntegerField(null=True)
    ObsSetting = models.TextField(null=True)

    class Meta:
        managed = False
        db_table = '"systeme"."T_Admin_UI_Setting"'


class T_Recherche(models.Model):
    IdRecherche = models.AutoField(primary_key=True)
    IdUserFk = models.IntegerField(null=True)
    TexteRecherche = models.TextField()
    TypeRecherche = models.CharField(max_length=80, null=True)
    ID_ArticleResultFk = models.IntegerField(null=True)
    IdEntiteResultFk = models.IntegerField(null=True)
    IdSpecialiteFk = models.IntegerField(null=True)
    LatitudeUser = models.DecimalField(max_digits=9, decimal_places=6, null=True)
    LongitudeUser = models.DecimalField(max_digits=9, decimal_places=6, null=True)
    DateRecherche = models.DateTimeField()

    class Meta:
        managed = False
        db_table = '"analytics"."T_Recherche"'

class T_LotArticle(models.Model):
    ID_LotArticle = models.AutoField(primary_key=True)
    ID_ArticleFk = models.IntegerField()
    NumeroLot = models.CharField(max_length=100)
    DatePeremptionLot = models.DateField(null=True)
    Actif = models.BooleanField()
    CreeLe = models.DateTimeField()
    class Meta:
        managed = False
        db_table = '"logistique"."T_LotArticle"'

class T_MouvementLot(models.Model):
    pk = models.CompositePrimaryKey("ID_MvtFk", "ID_LotArticleFk")
    ID_MvtFk = models.IntegerField()
    ID_LotArticleFk = models.IntegerField()
    Quantite = models.DecimalField(max_digits=14, decimal_places=3)
    class Meta:
        managed = False
        db_table = '"logistique"."T_MouvementLot"'

class T_Client(models.Model):
    ID_Client=models.BigAutoField(primary_key=True)
    IdEntiteFk=models.IntegerField()
    Nom=models.TextField()
    Nature=models.TextField()
    ID_TypeClientFk=models.IntegerField()
    Email=models.TextField(null=True)
    Telephone=models.TextField(null=True)
    Adresse=models.TextField(null=True)
    IdUserFk=models.IntegerField(null=True)
    IdProfessionnelFk=models.IntegerField(null=True)
    IdEntiteRepresenteeFk=models.IntegerField(null=True)
    ObsClient=models.TextField(null=True)
    Actif=models.BooleanField(default=True)
    CreeParUserFk=models.IntegerField()
    ModifieParUserFk=models.IntegerField()
    DateCreation=models.DateTimeField()
    DateModification=models.DateTimeField()
    class Meta:
        managed=False
        db_table='"logistique"."T_Client"'

from .inventory_models import T_UniteStockPrecision, T_Inventaire, T_InventaireLigne
