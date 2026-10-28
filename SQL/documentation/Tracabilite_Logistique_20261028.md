# Traçabilité durable des règlements et contrôle SQL

La migration `20261028_03_tracabilite_logistique.sql` complète le socle PostgreSQL sans déplacer les informations déjà enregistrées ni fabriquer un historique manquant. Son installation relève de la procédure DBA avec sauvegarde vérifiée ; le fichier SQL ne s’exécute pas au démarrage de l’application.

## Informations conservées

Quatre colonnes facultatives complètent `logistique."T_Reglements"` :

| Colonne | Rôle |
|---|---|
| `CreeParUserFk` | Auteur réel de création communiqué à SQL, immuable après création. |
| `CreeLe` | Horodatage technique de création, distinct de la date métier du règlement. |
| `ModifieParUserFk` | Auteur réel de la dernière écriture. |
| `ModifieLe` | Horodatage technique de la dernière écriture. |

Les écritures historiques gardent ces quatre valeurs à NULL. Si un ancien événement CREATE prouve l’auteur, la consultation peut encore le lire dans l’audit sans remplir artificiellement la nouvelle colonne. L’Entité reste celle de la facture parent : aucun second champ propriétaire divergent n’est ajouté au paiement. Les révisions applicatives conservent leur instantané des lignes et du parent ; aucune colonne Version redondante n’est imposée.

Le backend utilise `set_admin_actor` dans la transaction d’écriture. Le contexte `systeme.actor_user_id` est transactionnel ; SQL vérifie l’existence du compte. Une écriture SQL sans contexte prouvé conserve un auteur inconnu. Le contexte d’audit ne remplace jamais les droits d’accès du rôle PostgreSQL ni les contrôles d’Entité des API.

## Règles financières et concurrence

Le trigger contrôle INSERT **et UPDATE** : montant strictement positif, date métier renseignée, mode de règlement actif à la création ou au changement, facture existante, devise et tiers immuables. Le cumul ne peut dépasser le montant de la facture diminué des avoirs imputés. Un excédent historique peut seulement diminuer. Une facture clôturée ou comportant des avoirs conserve les protections existantes.

Le parent est verrouillé avant le calcul du solde. Le trigger est nommé `a0_reglement_apres_avoir` afin d’acquérir ce verrou **avant** le contrôle de propriété qui prend un verrou partagé. La recette a mis en évidence un interblocage lors de conversions SHARE vers UPDATE concurrentes ; cet ordre évite cette conversion pour deux créations simultanées. Les services applicatifs continuent à verrouiller le parent avant ses paiements pour toutes les écritures.

SQL enregistre une seule image CREATE/UPDATE/DELETE par écriture, nettoyée par `fn_audit_sans_secrets`, avec l’Entité durable de la facture. Le service Python conserve uniquement les événements PAYMENT_* nécessaires à l’idempotence, sans second audit détaillé. Écriture, image d’audit et preuve de rejeu sont atomiques.

## Autres contrôles

- L’audit de numérotation utilise `NEW.IdEntiteFk`, indépendamment de l’entreprise actuelle du créateur. Les événements historiques ne sont pas réécrits.
- `CodeArticleInterne` est unique **par entreprise**. Sa comparaison textuelle et les valeurs NULL restent conformes au contrat existant ; aucun code n’est renommé.
- Une contrainte vérifie que `T_PieceJustificative.Sha256` correspond exactement à son contenu binaire conservé en base. Le contenu privé n’est pas copié dans les journaux.

## Recette isolée

`SQL/tests/test_tracabilite_logistique.py` exige une base PostgreSQL locale explicitement nommée `sauverndeko_test_*`, avec la structure antérieure à cette migration. Elle crée uniquement des données fictives, installe la migration puis contrôle la conservation des anciennes valeurs et des journaux, les auteurs/dates, les gardes SQL, les rejeux API individuels et par panier, les mises à jour/suppressions auditées une seule fois, les encaissements concurrents, l’unicité inter-entreprises et l’intégrité des justificatifs.

Cette recette n’envoie aucun message et ne modifie aucune donnée de SauverNdeko. Une base isolée validée ne constitue pas une recette visuelle du navigateur ni une preuve de restauration de la base cliente.
