# Patrimoine et affectations

Le parcours Immobilisations appartient au groupe Patrimoine de Logistique. Une fiche représente un équipement individuel ou un groupe explicitement homogène ; le registre des biens n’est pas le catalogue commercial des Articles.

`T_Immobilisation` et `V_Immobilisation` sont le socle partagé des lectures, consultations et exports. Code IMMO-ID, entreprise et création sont immuables. Les quantités sont entières exactes ; le suivi individuel ou un numéro de série impose 1. Prix inconnu et zéro restent distincts. La valeur d’acquisition est calculée en SQL sans mouvement, CUMP, amortissement ou écriture comptable implicite.

Les listes de type, état et service viennent du référentiel et des correspondances persistées : surcharge d’entreprise active avant portée globale. Aucun identifiant de famille ne doit être repris d’une autre installation. Le responsable et le lieu sont de la même entreprise. Les anciennes affectations restent dans l’audit ; un bien archivé conserve sa fiche et protège les propriétaires encore liés.

Les six données professionnelles minimales de `T_Utilisateurs` restent séparées dans `V_User_Affectation`. Fonction et service ne remplacent pas le rôle de sécurité. L’interface d’administration rassemble Utilisateurs et les informations professionnelles ; l’ancienne source Profils reste compatible, sans second parcours utilisateur ni extension du profil public.

Les choix de colonnes de tableau et d’export sont indépendants et persistés. Les identifiants sans rendu métier sont exclus des choix du tableau mais peuvent rester exportables explicitement. Le prix affiché peut porter sa devise ; aucune colonne supplémentaire n’est ajoutée contre le choix enregistré de l’export.

Le paquet neuf charge structure, dictionnaire et correspondances fermées dans l’ordre documenté. Il ne copie ni entreprise, compte, bien, historique, préférence personnelle ou configuration privée. Une évolution de code ou une migration présente ne suffit pas à affirmer son installation réelle : consulter les preuves d’application et de recette.

Lire [le contrat SQL](../../../SQL/documentation/Immobilisations_Affectations_20261028.md) et [le guide utilisateur](../../../docs/prise-en-main-patrimoine.md). Les futures pièces justificatives, maintenance, cessions et amortissements restent à traiter comme évolutions distinctes ; ne pas présenter leur existence sur la seule base du nom Immobilisations.
