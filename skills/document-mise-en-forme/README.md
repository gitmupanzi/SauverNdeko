# Documents SauverNdeko

Version documentaire 3.0 — 24 octobre 2026.

Ce skill adapte la mise en forme Excel, Word et PDF à SauverNdeko et aux organisations utilisatrices de son ERP. Le [point d’entrée](SKILL.md) route vers les règles de format, les données métier, la parité et les modèles opérationnels.

La [charte JSON](assets/charte_sauverndeko.json) reprend les couleurs de l’application et le [logo SauverNdeko](assets/sauverndeko-logo.jpg). L’organisation émettrice conserve son identité autorisée ; le logiciel ne se substitue pas à elle.

## Contenu

Règles de présentation et de contrôle, modèles Markdown de rapports/commandes/livraisons/factures, helpers d’affichage synthétiques et tests. Les modèles ne sont pas des fichiers Office binaires ; aucun exporteur natif ou document réel n’est annoncé comme livré par cette adaptation.

Pour une implémentation, lire [l’intégration](references/integration_plateforme.md) et les skills ERP/backend/frontend du dépôt. Les helpers actuels HTML/.xls et impression navigateur restent à remplacer ou compléter pour obtenir les formats natifs conformes.

## Vérification

Depuis le dossier du skill, avec Python :

~~~text
python -B scripts/verifier_dossier.py --strict-external
python -B -m unittest discover -s tests -p "test_*.py" -v
~~~

Le premier contrôle vérifie les fichiers, la charte, le logo, les liens et les empreintes. Le second vérifie des conventions sur données ERP fictives. Les niveaux de rendu et d’intégration nécessitent les fichiers réellement générés, comme décrit dans [le contrôle qualité](references/controle_qualite.md) et [le bilan](CONTROLE_LIVRAISON.md).

Le [registre de provenance](references/sources_et_migrations.json) conserve l’origine de la copie initiale et les sources SauverNdeko utilisées. Il ne dépend pas de l’installation du projet d’origine sur une autre machine. Les [consignes du dépôt](../AGENTS.md) centralisent les règles d’utilisation ; aucune installation globale de skill n’est réalisée.
