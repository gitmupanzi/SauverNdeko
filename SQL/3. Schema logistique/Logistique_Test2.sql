SELECT * FROM referentiel."T_Generique"
Where "ID_Generique"=102
ORDER BY "ID_Generique" ASC 


DELETE FROM logistique."T_Mouvement";
DELETE FROM logistique."T_Article";
DELETE FROM logistique."T_Commande";
DELETE FROM logistique."T_CommandeDetail";


SELECT * FROM logistique."T_Article";
SELECT * FROM logistique."T_Commande";
SELECT * FROM logistique."T_CommandeDetail";
SELECT * FROM logistique."T_Mouvement";

/ Entrée : 448
Select "ID_Generique" FROM referentiel."T_Generique"
where "AbrGenerique"='Entrée'
/Sortie : 449
Select "ID_Generique" FROM referentiel."T_Generique"
where "AbrGenerique"='Sortie'



