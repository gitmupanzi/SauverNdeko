INSERT INTO systeme."T_ModuleApplication" (
    "CodeModule", "Nom", "TypeApplication", "EstSocle", "AfficherDansEspace",
    "AccessibleSansEntite", "ReservePlateforme", "Commercialisable", "Actif", "Ordre"
)
VALUES ('data-science', 'Data Science', 'MODULE', false, true, false, false, true, true, 100)
ON CONFLICT ("CodeModule") DO NOTHING;
