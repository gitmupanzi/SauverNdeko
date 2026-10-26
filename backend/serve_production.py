"""Service WSGI de production ; l'écoute reste derrière le frontal privé."""
import os
import ipaddress
os.environ.setdefault('DJANGO_SETTINGS_MODULE','config.production')
from waitress import serve
from config.wsgi import application

if __name__=='__main__':
    proxy=str(ipaddress.ip_address(os.environ.get('SAUVERNDEKO_TRUSTED_PROXY','127.0.0.1')))
    serve(application,listen=os.environ.get('SAUVERNDEKO_WSGI_LISTEN','127.0.0.1:5000'),threads=int(os.environ.get('SAUVERNDEKO_WSGI_THREADS','8')),trusted_proxy=proxy,trusted_proxy_count=1,trusted_proxy_headers={'x-forwarded-for','x-forwarded-proto','x-forwarded-port','x-forwarded-host'},clear_untrusted_proxy_headers=True,max_request_body_size=10*1024*1024,expose_tracebacks=False)
