-- Initialisation vierge, après references.sql et correspondances.sql.
-- Les identifiants sont lus dans le dictionnaire commun du paquet.
BEGIN;
DO $support_seed$
DECLARE
    expected record;
    candidates integer[];
    states jsonb := '{}'::jsonb;
    verification jsonb := '{}'::jsonb;
BEGIN
    IF EXISTS (
        SELECT FROM systeme."T_Admin_UI_Setting"
        WHERE "SettingScope" = 'global' AND "ScopeValue" IS NULL AND "SettingKey" = 'support.workflow'
    ) THEN
        RETURN;
    END IF;

    FOR expected IN SELECT * FROM (VALUES
        ('T_Support', 'ID_StatutFk', 'new', 'support.status.new', 'Nouveau'),
        ('T_Support', 'ID_StatutFk', 'active', 'support.status.active', 'En cours'),
        ('T_Support', 'ID_StatutFk', 'pending', 'support.status.pending', 'En attente'),
        ('T_Support', 'ID_StatutFk', 'resolved', 'support.status.resolved', 'Résolu'),
        ('T_Support', 'ID_StatutFk', 'closed', 'support.status.closed', 'Clôturé'),
        ('T_ResolutionSupport', 'ID_ResultatVerificationFk', 'accepted', 'support.verify.ok', 'Conforme'),
        ('T_ResolutionSupport', 'ID_ResultatVerificationFk', 'rejected', 'support.verify.ko', 'À reprendre')
    ) AS definitions(table_name, column_name, state_key, technical_code, standard_label)
    LOOP
        -- Les codes techniques historiques sont prioritaires. Le paquet peut
        -- aussi contenir le libellé français standard dans les deux champs.
        SELECT coalesce(
            array_agg(g."ID_Generique") FILTER (WHERE g."AbrGenerique" = expected.technical_code),
            array_agg(g."ID_Generique") FILTER (WHERE g."AbrGenerique" = expected.standard_label
                                                AND g."NomGenerique" = expected.standard_label),
            ARRAY[]::integer[]
        ) INTO candidates
        FROM referentiel."T_ChampReferentiel" f
        JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique" = f."ID_CategorieDefautFk"
        JOIN referentiel."T_Generique" g ON g."ID_CategorieGeneriqueFk" = c."ID_CategorieGenerique"
        WHERE f."SchemaName" = 'support' AND f."TableName" = expected.table_name
          AND f."ColumnName" = expected.column_name
          AND c."IdEntiteFk" IS NULL AND c."ValideCategorieGenerique"
          AND g."IdEntiteFk" IS NULL AND g."ValideGenerique";

        IF cardinality(candidates) <> 1 THEN
            RAISE EXCEPTION 'Référence standard Support absente ou ambiguë pour % : % correspondance(s).',
                expected.technical_code, cardinality(candidates) USING ERRCODE = '23514';
        END IF;
        IF expected.column_name = 'ID_StatutFk' THEN
            states := states || jsonb_build_object(expected.state_key, candidates[1]);
        ELSE
            verification := verification || jsonb_build_object(expected.state_key, candidates[1]);
        END IF;
    END LOOP;

    INSERT INTO systeme."T_Admin_UI_Setting" (
        "SettingScope", "SettingKey", "SettingLabel", "SettingGroup", "SettingType",
        "SettingValueJson", "IsEditable", "IsSystem", "ValideSetting", "ObsSetting"
    ) VALUES (
        'global', 'support.workflow', 'Circuit de traitement du Support', 'support', 'json',
        jsonb_build_object(
            'version', 1,
            'states', states,
            'verification', verification,
            'transitions', '[
                {"from":"new","to":"active","action":"start"},
                {"from":"active","to":"pending","action":"pause"},
                {"from":"pending","to":"active","action":"resume"},
                {"from":"active","to":"resolved","action":"resolve"},
                {"from":"pending","to":"resolved","action":"resolve"},
                {"from":"resolved","to":"closed","action":"close"},
                {"from":"resolved","to":"active","action":"reopen"},
                {"from":"closed","to":"active","action":"reopen"}
            ]'::jsonb
        ),
        true, true, true, 'Circuit initial standard d’installation.'
    );
END $support_seed$;
COMMIT;
