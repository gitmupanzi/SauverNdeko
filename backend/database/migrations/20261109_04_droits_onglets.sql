-- Étend le catalogue des restrictions individuelles sans modifier les droits enregistrés.
ALTER TABLE systeme."T_UtilisateurModule"
    DROP CONSTRAINT "T_UtilisateurModule_check1",
    ADD CONSTRAINT utilisateur_module_onglet_check CHECK (
        "CodeOnglet" = ''
        OR ("CodeModule" = 'logistique' AND "CodeOnglet" IN ('dashboard', 'dossiers', 'tiers', 'depots', 'articles', 'lots', 'stocks-depots', 'commandes', 'details', 'transferts', 'mouvements', 'inventaires', 'factures', 'reglements', 'immobilisations'))
        OR ("CodeModule" = 'caisse' AND "CodeOnglet" IN ('tableau-de-bord', 'caisses', 'ecritures', 'clotures'))
        OR ("CodeModule" = 'support' AND "CodeOnglet" IN ('tableau-de-bord', 'tickets'))
        OR ("CodeModule" = 'administration' AND "CodeOnglet" IN ('tableau-de-bord', 'utilisateurs', 'roles', 'permissions', 'entites', 'licences', 'correspondances', 'parametres', 'messagerie', 'audit', 'connexions', 'audit-parametres'))
        OR ("CodeModule" = 'discussions' AND "CodeOnglet" IN ('messages', 'demandes', 'annonces'))
        OR ("CodeModule" = 'professionnels' AND "CodeOnglet" IN ('annuaire', 'profils'))
    );

COMMENT ON CONSTRAINT utilisateur_module_onglet_check ON systeme."T_UtilisateurModule"
    IS 'Seuls les onglets dont les droits sont contrôlés côté serveur peuvent recevoir une restriction individuelle.';
