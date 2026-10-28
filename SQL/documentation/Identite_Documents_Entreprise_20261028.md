# Identité courante de l’entreprise et documents PDF

La migration `20261028_07_identite_documents_entreprise.sql` complète le profil documentaire de `systeme.T_Entite`. Elle est installée dans SauverNdeko après sauvegarde contrôlée. Elle refuse un second passage et ne réécrit aucune donnée métier existante.

## Données et validations

| Champ ajouté | Règle |
|---|---|
| SiteWebEntite | Facultatif, HTTP(S), 255 caractères au plus ; pas de contrôles, d’espace ou d’identifiants intégrés dans l’autorité. |
| PhoneSecondaireEntite | Facultatif, 1 à 20 caractères ; pas de contrôles ni d’espaces extérieurs. NULL représente l’absence. |
| AfficherEnteteDocument | Booléen obligatoire, true par défaut. |
| AfficherPiedDocument | Booléen obligatoire, true par défaut. |
| LogoEntite | Octets PNG privés normalisés par le service, 2 Mio au plus. |
| LogoMimeEntite | image/png lorsque le logo est présent. |
| LogoSha256Entite | Empreinte des octets exacts, recalculée indépendamment par PostgreSQL. |
| LogoModifieLe | Horodatage serveur de pose du logo. |

Les quatre valeurs du logo sont toutes absentes ou toutes renseignées. La base contrôle signature PNG, IHDR, fin IEND, taille, MIME et SHA ; le service effectue le décodage complet et la normalisation. Les noms, adresses et mentions ne reçoivent aucun contenu supposé. Les identifiants légaux existants restent déclaratifs et génériques, dix couples libellé/valeur au plus. La nouvelle contrainte d’adresse accepte LF/CRLF et reste NOT VALID pour préserver les anciennes adresses tout en contrôlant les prochaines écritures.

`V_IdentiteDocumentaire` conserve l’ordre des colonnes antérieures et ajoute les métadonnées, avec `PhoneSecondaireEntite` en dernière position. La fonction canonique fournit les mêmes informations en JSON. Aucune de ces projections ne contient `LogoEntite`. `fn_audit_sans_secrets` retire aussi cette clé lorsqu’elle apparaît dans un objet imbriqué ou du JSON encodé ; les métadonnées d’intégrité restent disponibles.

## Présentation et historique

Les PDF d’entrée, sortie, livraison, commande CMD, facture, reçu et avoir utilisent le profil **courant** de l’entreprise propriétaire à chaque génération ou régénération. Le nom demeure visible même si le bloc détaillé d’en-tête est masqué. Le pied affiche nom, identifiants, mentions et pagination ; sa désactivation retire entièrement ce bloc. Les réglages sont exclusivement persistés dans le profil et appliqués au téléchargement sans dialogue supplémentaire.

Les tiers émis, quantités, prix, montants, dates, références et écritures restent historiques. Les instantanés antérieurs demeurent en base. Un PDF ou justificatif déjà archivé est restitué sans changer ses octets. Le service vérifie les droits et l’entreprise du document avant de consulter le profil ou son logo.

## Application et vérification

L’application réelle conserve les douze anciennes colonnes des entreprises, leurs valeurs et les empreintes des 66 autres tables. Les huit champs reçoivent uniquement leurs défauts NULL/true. Aucun compte, logo ou document fictif n’a été injecté dans SauverNdeko pour la recette.

Les preuves locales sont distinctes :

- `.runtime/identite-pdf07/verification.json` : 57 contrôles SQL, contraintes directes, commentaires, invariance des tables et instantanés.
- `.runtime/identite-entreprise-api/verification.json` : 13 tests API, gestion du profil, logo privé, conflits et périmètres d’entreprises.
- `.runtime/identite-pdf-api/verification.json` : 312 contrôles, sept documents, quatre combinaisons d’en-tête/pied, historique financier conservé.
- `.runtime/pdf-mise-en-page07/verification.json` : 189 contrôles de mise en page ; 48 pages rendues ont été inspectées dans la recette finale, dont noms/adresses longs, logo transparent et signatures.
- `.runtime/identite-pdf07-applique.json` : application transactionnelle réelle et comparaison des données avant/après.
- `.runtime/identite07-canonical-20261028-23636f823d/verification.json` : huit sources sans données et deux restaurations vides conformes au catalogue et aux commentaires.

Les deux structures restaurées contiennent respectivement 67 et 57 tables, 80 vues et 126 triggers. Elles ne contiennent aucune entreprise ni donnée cliente. Les valeurs CRLF/LF des contraintes utilisent la notation SQL échappée explicite. Une conversion des fins de ligne du fichier par Git ne change ainsi pas les valeurs de ces expressions.

Pour une nouvelle installation, utiliser le socle canonique actuel et un nouveau paquet `preparer_installation` avec son dictionnaire fermé. Les profils et logos appartiennent à l’entreprise de destination ; aucune identité d’une instance source n’est réutilisée. Le [guide utilisateur](../../docs/identite-entreprise-pdf.md) décrit les réglages disponibles.
