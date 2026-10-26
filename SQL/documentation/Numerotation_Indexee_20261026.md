# Historique de numérotation indexé

La migration `20261026_06_performance_numerotation.sql` remplace le parcours des audits et ses expressions régulières à chaque création de bon par deux index GIN partiels : identités extraites de `OldData` et de `NewData` pour les audits Commande/Facture déjà pris en compte.

`logistique.fn_identites_audit(jsonb)` est immuable, stricte et parallèle sûre. Elle extrait `ID_Commande`, `ID_CommandeFk`, `ID_CommandeRetourFk`, les anciens codes `C_`/`F_` et les codes courts `cmd-`/`fac-`, sans distinction de casse. Les zéros initiaux sont normalisés, les valeurs sont dédupliquées et les entrées non objets ou non numériques sont ignorées. Le résultat `numeric[]` préserve les grands identifiants historiques usuels sans cast integer/bigint. Les valeurs de plus de 1 000 chiffres significatifs sont ignorées : elles ne peuvent correspondre à l’identité publique integer et produiraient une clé GIN démesurée. Un long préfixe de zéros reste pris en charge.

La fonction de réservation existante conserve sa séquence, ses références automatiques, ses contraintes d’unicité et les recherches dans les bons courants. Les journaux et données métier ne sont pas réécrits. La non-réutilisation après suppression reste fondée sur les traces existantes ; aucune nouvelle table de catégories n’est créée.

Recette portable `SQL/tests/test_numerotation_indexee.py` : URL de base privée `sauverndeko_test_*` explicitement obligatoire, aucune connexion de repli. Les 22 contrôles ont passé sur une copie isolée : données anciennes/nouvelles, formats et zéros initiaux, grands identifiants, refus de réutilisation d’une identité historique, exclusion des audits d’autres tables, usage réel des deux index dans EXPLAIN sur 5 000 audits, puis 16 créations concurrentes distinctes avec une seule trace de première numérotation chacune. Les jeux de volumétrie et les créations sont exclusivement fictifs et privés.

L’installation réelle, sa sauvegarde et les mesures de performance d’interface sont consignées par la livraison coordonnée.
