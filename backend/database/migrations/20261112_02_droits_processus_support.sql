-- Le droit individuel sur l’onglet Processus utilise les mêmes restrictions que Tickets.
ALTER TABLE systeme."T_UtilisateurModule"
    DROP CONSTRAINT utilisateur_module_onglet_check,
    ADD CONSTRAINT utilisateur_module_onglet_check CHECK (
        "CodeOnglet" = ''
        OR ("CodeModule" = 'logistique' AND "CodeOnglet" IN ('dashboard', 'dossiers', 'tiers', 'depots', 'articles', 'lots', 'stocks-depots', 'commandes', 'details', 'transferts', 'mouvements', 'inventaires', 'factures', 'reglements', 'immobilisations'))
        OR ("CodeModule" = 'caisse' AND "CodeOnglet" IN ('tableau-de-bord', 'caisses', 'ecritures', 'clotures'))
        OR ("CodeModule" = 'support' AND "CodeOnglet" IN ('tableau-de-bord', 'tickets', 'processus'))
        OR ("CodeModule" = 'administration' AND "CodeOnglet" IN ('tableau-de-bord', 'utilisateurs', 'roles', 'permissions', 'entites', 'licences', 'correspondances', 'parametres', 'messagerie', 'audit', 'connexions', 'audit-parametres'))
        OR ("CodeModule" = 'discussions' AND "CodeOnglet" IN ('messages', 'demandes', 'annonces'))
        OR ("CodeModule" = 'professionnels' AND "CodeOnglet" IN ('annuaire', 'profils'))
    );

COMMENT ON CONSTRAINT utilisateur_module_onglet_check ON systeme."T_UtilisateurModule"
    IS 'Seuls les onglets dont les droits sont contrôlés côté serveur, dont Processus de suivi dans Support, acceptent une restriction individuelle.';
