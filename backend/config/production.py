"""Paramètres de production derrière un frontal HTTPS de confiance."""
import os
from urllib.parse import urlsplit
from django.core.exceptions import ImproperlyConfigured
from .settings import *

DEBUG=False
DJANGO_ADMIN_ENABLED=False
LEGACY_PLAINTEXT_PASSWORDS=False
hosts=[value.strip() for value in os.environ.get('DJANGO_ALLOWED_HOSTS','').split(',') if value.strip()]
origin=os.environ.get('SAUVERNDEKO_FRONTEND_URL','')
try:
    parsed=urlsplit(origin)
    port=parsed.port
except ValueError:
    raise ImproperlyConfigured('Configurer les hôtes exacts et une origine frontend HTTPS.') from None
if (any(host.startswith('.') or '*' in host for host in hosts)
        or parsed.scheme!='https' or parsed.hostname not in hosts
        or parsed.username is not None or parsed.password is not None
        or '?' in origin or '#' in origin or parsed.path not in {'','/'} or port==0):
    raise ImproperlyConfigured('Configurer les hôtes exacts et une origine frontend HTTPS.')
if not os.environ.get('DJANGO_SECRET_KEY') or len(SECRET_KEY)<50 or len(JWT_SECRET)<32 or len(JWT_REFRESH_SECRET)<32 or len({SECRET_KEY,JWT_SECRET,JWT_REFRESH_SECRET})!=3:
    raise ImproperlyConfigured('Les secrets de production doivent être longs et distincts.')
db_sslmode=os.environ.get('SAUVERNDEKO_DB_SSLMODE','verify-full')
if db_sslmode not in {'verify-full','verify-ca','require','disable'}:
    raise ImproperlyConfigured('Mode TLS PostgreSQL non autorisé.')
if db_sslmode=='disable' and DATABASES['default']['HOST'] not in {'localhost','127.0.0.1','::1'}:
    raise ImproperlyConfigured('TLS PostgreSQL requis hors de la boucle locale.')
DATABASES['default']['OPTIONS']['sslmode']=db_sslmode
if os.environ.get('SAUVERNDEKO_DB_SSLROOTCERT'):
    DATABASES['default']['OPTIONS']['sslrootcert']=os.environ['SAUVERNDEKO_DB_SSLROOTCERT']
ALLOWED_HOSTS=hosts
CORS_ALLOWED_ORIGINS=[origin.rstrip('/')]
CSRF_TRUSTED_ORIGINS=CORS_ALLOWED_ORIGINS
SECURE_PROXY_SSL_HEADER=('HTTP_X_FORWARDED_PROTO','https')
SECURE_SSL_REDIRECT=True
SECURE_HSTS_SECONDS=31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS=False
SECURE_HSTS_PRELOAD=False
SESSION_COOKIE_SECURE=True
CSRF_COOKIE_SECURE=True
X_FRAME_OPTIONS='DENY'
LOGGING={
 'version':1,'disable_existing_loggers':False,
 'formatters':{'service':{'format':'{asctime} {levelname} {name} {message}','style':'{'}},
 'handlers':{'console':{'class':'logging.StreamHandler','formatter':'service'}},
 'root':{'handlers':['console'],'level':'INFO'},
 'loggers':{'django.request':{'handlers':['console'],'level':'WARNING','propagate':False}},
}
