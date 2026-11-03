"""Libellés de choix génériques ; aucune modification du dictionnaire ou des FK."""


def reference_label(row):
    if not isinstance(row, dict):
        return ''
    abbreviation = row.get('AbrGenerique') if 'AbrGenerique' in row else row.get('abbr')
    if isinstance(abbreviation, str) and abbreviation.strip():
        return abbreviation.strip()
    identifier = row.get('ID_Generique', row.get('id'))
    return 'Valeur sans abréviation' + (f' #{identifier}' if identifier is not None else '')


def reference_label_sql(alias=''):
    """Expression réservée aux alias constants des projections de choix."""
    if alias and (not alias.isidentifier() or not alias.isascii()):
        raise ValueError('Alias SQL constant attendu.')
    prefix = alias + '.' if alias else ''
    return ('CASE WHEN '+prefix+'"ID_Generique" IS NULL THEN NULL ELSE COALESCE(NULLIF(btrim('
            +prefix+'"AbrGenerique"),\'\'),\'Valeur sans abréviation #\'||'
            +prefix+'"ID_Generique"::text) END')
