# Paramètres entreprise et TVA — contrat PostgreSQL

La migration `20261102_01_entite_tva.sql` complète le paramétrage durable de l’entreprise et le socle de facturation. Le module **Paramètres** est enregistré comme module socle dans `systeme.T_ModuleApplication` ; les droits applicatifs et le périmètre d’entreprise restent contrôlés par le serveur.

## Source du taux

`systeme.T_Entite.TauxTVAEntite` est un pourcentage exact `numeric(7,4)`, non nul, compris entre 0 et 100. Le défaut est **0** pour les entreprises existantes et nouvelles. Aucune valeur réglementaire, exonération ou régime fiscal n’est déduit du pays ou du secteur. La vue commune `systeme.V_IdentiteDocumentaire` expose aussi ce taux, sans ajouter une configuration parallèle.

Un taux est un paramètre d’entreprise, pas une valeur de référence générique : il appartient directement à la fiche propriétaire. Un changement de taux ne modifie pas les anciennes factures, avoirs, lignes, identités émises, règlements ou mouvements.

## Émission des factures

Les prix et montants des lignes de bons constituent la base **hors taxes**. Le stock, les coûts et les totaux physiques des bons demeurent inchangés. La TVA s’applique à la facture émise, sur les quantités nettes des restitutions antérieures à sa création.

`logistique.fn_facturation_tva(ID_Commande)` est la projection unique de prévisualisation : `TauxTVA`, `MontantHT`, `MontantTVA` et `MontantTTC`. La base HT est arrondie par ligne à deux décimales ; sa taxe est ensuite arrondie à deux décimales. Les totaux sont les sommes de ces lignes. Le TTC est HT + TVA. Le calcul n’utilise aucun flottant ni conversion de devise.

Le trigger d’insertion de `T_Facture` verrouille le bon et l’entreprise, capture le taux courant et calcule les montants autoritatifs. `T_Facture.TauxTVA` et `MontantTVA` deviennent des instantanés immuables. Le trigger de `T_FactureLigne` calcule sa `MontantTVA` avec ce taux ; sa `MontantTTC` est une colonne générée à partir de `MontantLigne` HT + taxe. Le contrôle différé vérifie les lignes nettes du bon, leur HT, leur TVA et le TTC de l’en-tête avant validation de la transaction.

Une facture déjà émise utilise son instantané. Le taux courant de l’entreprise sert seulement à une **nouvelle** émission. Une interface de préparation ouverte avant un changement de taux doit être rechargée avant confirmation ; sa révision et les verrouillages côté service doivent couvrir cette projection fiscale.

## Restitutions et avoirs

Les retours physiques conservent leur comportement de stock. Un retour antérieur à l’émission réduit la quantité facturée. Un retour postérieur donne lieu à un avoir indépendant ; il ne réécrit pas la facture.

`T_Avoir.TauxTVA` reprend le taux de la facture d’origine. Son `MontantTVA` est la taxe créditée et `MontantHT` est généré par TTC − TVA. Chaque ligne garde `MontantLigne` comme base HT, ajoute `MontantTVA`, puis calcule `MontantTTC` comme somme des deux.

Les montants des retours partiels sont calculés par **différence des arrondis cumulés** de la ligne facturée, après soustraction des avoirs déjà émis. La TVA utilise la fraction de la taxe réellement facturée pour cette quantité. La dernière restitution reprend exactement les reliquats HT et TVA. Cela évite de rembourser plusieurs fois un centime d’arrondi. Un retour financier nul n’exige pas un avoir de montant positif ; les quantités non encore créditées restent prises en compte pour la prochaine restitution valorisée.

`fn_lignes_avoir_attente(ID_Commande)` fournit les quantités et montants HT/TVA/TTC exacts à créditer ; `fn_montant_avoir_attente` en somme le **TTC**. Les triggers contrôlent les quantités réellement retournées et le montant de chaque ligne. Un contrôle différé refuse un en-tête d’avoir ne correspondant pas à ses lignes. L’imputation et le remboursement continuent à utiliser le TTC historique, sans second effet de stock.

## Vues et tableaux

`V_Facture`, `V_FactureLigne` et `V_Avoir` exposent les nouvelles composantes fiscales en fin de projection, en conservant les anciennes colonnes et leur ordre. `V_SuiviReglements` ajoute `TauxTVA`, `MontantTVA` et `MontantHTFacture` pour les fiches et registres financiers. `V_Commande` ajoute `TauxTVAFacture`, `MontantTVAFacture` et `MontantHTFacture`, distincts des montants physiques du bon.

Le catalogue commun des tableaux ajoute ces champs dans Factures et Bons de stock, sans doublon, avec affichage et export désactivés par défaut. Ils deviennent disponibles dans les réglages sans imposer une nouvelle disposition aux utilisateurs.

## Migration et vérifications

L’installation est versionnée et transactionnelle ; elle ajoute les valeurs par défaut et les colonnes générées sans modifier les anciennes colonnes financières ni les quantités. Les taxes des anciens documents restent à zéro, cohérentes avec leur contrat antérieur HT = TTC. La migration ne rejoue aucun mouvement et ne change pas de propriétaire.

`SQL/tests/test_entite_tva_postgresql.py` exige une base PostgreSQL locale `sauverndeko_test_*` **avant** la migration. Elle y crée des factures et avoirs fictifs antérieurs, applique le fichier SQL, vérifie la conservation de toutes les anciennes lignes, puis exerce taux, arrondis, deux entreprises, factures, retours partiels, avoirs, immutabilité et refus transactionnels. Les données de recette ne sont jamais écrites dans la base SauverNdeko.
