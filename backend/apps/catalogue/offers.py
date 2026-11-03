"""Projection minimale des offres volontairement partagées, derrière l’accès ERP."""
import hashlib
from apps.core import db
from apps.logistique.photos import stored_photo


def public_offer(row):
    # Une liste fermée évite de propager des notes ou colonnes ajoutées au stock.
    keys = ('ID_Article','NomArticle','RefArticle','PVArticle','DeviseCode','DeviseLibelle',
            'Unite','EtatDisponibilite','IdEntite','NomEntite','AdresseEntite','PhoneEntite')
    result = {key: row.get(key) for key in keys}
    photo = row.get('PhotoArticle')
    result['PhotoArticle'] = ('/api/public/articles/'+str(row['ID_Article'])+'/photo?v='
        + hashlib.sha256(photo.encode('utf8')).hexdigest()[:16]) if stored_photo(photo) else None
    return result


def offers(q, take, skip):
    where, values = 'TRUE', []
    if q:
        where = '(v."NomArticle" ILIKE %s OR v."RefArticle" ILIKE %s OR v."NomEntite" ILIKE %s OR v."AdresseEntite" ILIKE %s)'
        values = ['%'+q+'%'] * 4
    source = 'logistique."V_OffreArticle" v'
    total = db.one('SELECT count(*) n FROM '+source+' WHERE '+where, values)['n']
    rows = db.query('SELECT v.* FROM '+source+' WHERE '+where+' ORDER BY v."NomArticle",v."ID_Article" LIMIT %s OFFSET %s', [*values,take,skip])
    return [public_offer(row) for row in rows], {'take':take,'skip':skip,'count':len(rows),'total':total}
