"""Modèles descriptifs unmanaged ; écritures réservées aux services d'inventaire."""
from django.db import models


class T_UniteStockPrecision(models.Model):
    ID_UniteFk=models.IntegerField(primary_key=True)
    Decimales=models.SmallIntegerField(default=0)
    ModifieLe=models.DateTimeField()
    class Meta:
        app_label='core';managed=False;db_table='"logistique"."T_UniteStockPrecision"'


class T_Inventaire(models.Model):
    ID_Inventaire=models.BigAutoField(primary_key=True)
    IdEntiteFk=models.IntegerField()
    ID_UserFk=models.IntegerField()
    DateInventaire=models.DateTimeField()
    Motif=models.TextField()
    Etat=models.TextField(default='brouillon')
    Version=models.BigIntegerField(default=1)
    CreeLe=models.DateTimeField()
    ModifieLe=models.DateTimeField()
    ValideLe=models.DateTimeField(null=True)
    ID_ValidateurFk=models.IntegerField(null=True)
    ValidationRequest=models.UUIDField(null=True)
    ValidationHash=models.TextField(null=True)
    class Meta:
        app_label='core';managed=False;db_table='"logistique"."T_Inventaire"'


class T_InventaireLigne(models.Model):
    pk=models.CompositePrimaryKey('ID_InventaireFk','ID_ArticleFk')
    ID_InventaireFk=models.BigIntegerField()
    ID_ArticleFk=models.IntegerField()
    QteTheorique=models.DecimalField(max_digits=14,decimal_places=3)
    QteComptee=models.DecimalField(max_digits=14,decimal_places=3)
    PUCorrection=models.DecimalField(max_digits=12,decimal_places=2,null=True)
    Lots=models.JSONField(default=list)
    Justification=models.TextField()
    ID_CommandeCorrectionFk=models.IntegerField(null=True)
    class Meta:
        app_label='core';managed=False;db_table='"logistique"."T_InventaireLigne"'
