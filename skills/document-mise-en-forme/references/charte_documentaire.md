# Charte documentaire SauverNdeko

La [configuration JSON](../assets/charte_sauverndeko.json) est la référence des valeurs de présentation. Les règles ci-dessous expliquent leur application. Une instruction explicite du propriétaire ou un gabarit client fourni pour le document concerné prévaut sur ces valeurs par défaut.

## Identité et émetteur

Le nom du logiciel est SauverNdeko. Le [logo local](../assets/sauverndeko-logo.jpg) identifie le logiciel ; son original est frontend/public/sauverndeko-logo.jpg et son empreinte est enregistrée dans le registre de provenance. Sur les documents métier d’une entreprise, utiliser son propre logo autorisé, sans déformation. En son absence, conserver son nom sans lui attribuer le logo du logiciel.

Pour une organisation utilisatrice, les documents métier portent son nom, son identité et son logo lorsqu’ils sont disponibles et autorisés dans le contexte. La mention SauverNdeko reste une identification du logiciel. Ne pas attribuer les opérations à SauverNdeko comme société vendeuse, ni reprendre l’identité d’un autre client. Une identité incomplète demeure un brouillon, avec les champs manquants signalés.

### Identité courante sur les PDF métier

La demande explicite du propriétaire du 28/10/2026 s’applique aux bons d’entrée, de sortie, de livraison, aux commandes CMD, factures, reçus et avoirs générés par l’application. Chaque génération ou régénération utilise l’identité courante de l’entreprise propriétaire : nom, logo, adresse, contacts, site, identifiants déclaratifs comme RCCM/NIF et mention. Une modification de ce profil apparaît donc aussi sur le PDF régénéré d’un ancien document.

Cette présentation ne réécrit ni les identités historiques conservées en base, ni le tiers figé, les lignes, montants, dates, références d’émission ou écritures financières. Un justificatif ou PDF déjà archivé reste téléchargé à l’octet près ; seule une nouvelle génération adopte le profil courant.

Le profil permet de renseigner un téléphone principal et un téléphone secondaire facultatif, ainsi que l’adresse, l’e-mail, le site et les identifiants déclaratifs. Reprendre les informations réellement saisies ; ne pas inventer de coordonnée manquante.

Les options persistées `AfficherEnteteDocument` et `AfficherPiedDocument` sont activées par défaut. Elles se règlent dans le profil de l’entreprise ; le téléchargement les applique directement, sans dialogue ni option ponctuelle. Masquer l’en-tête retire son bloc détaillé ; **le nom de l’entreprise reste visible** dans la présentation compacte. Le pied présente le nom, les identifiants, les mentions et la pagination ; le masquer retire entièrement ce bloc. Les références métier restent dans le corps. Vérifier les quatre combinaisons, les contenus longs et les documents multipages.

La source commune est `systeme.V_IdentiteDocumentaire` / `fn_identite_documentaire`. Le logo normalisé PNG est stocké dans `T_Entite`, avec MIME, SHA-256 et date ; ses octets ne vont ni dans les JSON de profil, ni dans les audits ou exports génériques. Le service autorise d’abord l’entreprise et le document. Ne pas charger de logo par une URL externe ni reprendre la marque d’une autre entreprise. Voir [le parcours utilisateur](../../../docs/identite-entreprise-pdf.md).

## Palette commune

| Usage | Couleur | Provenance/application |
|---|---|---|
| Bleu principal | #3F7DF1 | --blue de frontend/src/styles.css |
| En-têtes et liens soutenus | #2F67D6 | --blue-strong ; texte blanc pour les bandeaux |
| Fond secondaire | #EAF1FF | --blue-soft |
| Accent vert | #55BF57 | --green ; filet/repère, sans petit texte blanc sur ce fond |
| Accent turquoise | #11B4BB | --teal ; usage ponctuel |
| Texte | #252525 | --ink |
| Texte secondaire documentaire | #5F6B7A | Adaptation lisible pour documents imprimés |
| Fond/alternance | #FFFFFF / #F4F4F4 | Surfaces de l’application |
| Bordure | #D8E1EC | Séparation documentaire discrète |

Employer la couleur comme repère, avec un libellé ou symbole compréhensible. Aucun dégradé, ombre lourde ou effet 3D ajouté aux tableaux. Le logo fourni reste inchangé même si son dessin contient ses propres effets.

## Typographie et mise en page

Pour les titres, Raleway rappelle l’interface lorsqu’elle est disponible. Pour le texte et les tableaux Office, conserver Aptos ; Calibri est le repli documentaire. Déclarer toute substitution lors d’une conversion et inspecter son effet sur les retours à la ligne. Ne pas distribuer de fichiers de police avec le skill.

Word/PDF : A4 portrait, marges gauche 2,5 cm et autres 2 cm, texte 11 pt, titre 18 pt et niveaux 14/12/11 pt, interligne 1,15, espace après 6 pt. Paysage pour les tableaux larges ; garder une taille lisible, normalement au moins 9 pt dans les tableaux. Le logo carré a une largeur de référence de 2 cm, hauteur proportionnelle. Adapter un gabarit client fourni sans changer les données.

Excel : texte 11 pt, en-têtes gris clair (#F3F4F6) à texte sombre (#374151), alternance très légère et bordures grises fines. Pour les exports de listes, les en-têtes occupent la première ligne, les données commencent à la deuxième ; aucun logo, titre, bandeau ou bloc de contexte ne précède le tableau. Le contexte reste dans la feuille Informations. Cette préférence explicite du propriétaire du 25/10/2026 remplace les anciens en-têtes bleus pour Excel. Les couleurs ne rendent jamais un montant ou statut implicite.

## Valeurs et contexte

Les dates narratives peuvent s’écrire 24 octobre 2026 ; les tableaux utilisent 24/10/2026, avec heure complète si utile. La date de génération ne remplace pas une date métier ou un état de stock à une date donnée. Ne pas convertir un fuseau de données silencieusement ; déclarer celui de l’extraction lorsqu’il est connu.

Les montants s’affichent avec séparateur de milliers et décimales cohérentes ; leur devise vient de la source. Les quantités conservent leur unité et la précision fournie. Ne pas transformer une valeur absente en zéro ni additionner des devises ou unités différentes.

Les paramètres de diffusion et de validation proviennent du contexte. Un filigrane, une couleur ou une protection de feuille ne donnent pas un droit d’accès. Les informations techniques détaillées restent dans la traçabilité autorisée, sans longues consignes visibles sur les documents remis au client.
