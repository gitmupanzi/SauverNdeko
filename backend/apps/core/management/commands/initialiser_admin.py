"""Premier compte de plateforme, uniquement sur une installation sans utilisateur."""
import getpass
import os
from django.core.management.base import BaseCommand,CommandError
from django.core.validators import validate_email
from django.core.exceptions import ValidationError
from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from apps.accounts.passwords import validators
from django.contrib.auth.hashers import make_password
from django.db import transaction
from apps.core import db
from apps.core.repository import audit
from apps.accounts.authentication import Actor

class Command(BaseCommand):
    help='Initialiser le premier administrateur ; mot de passe dans une variable temporaire ou saisie masquée.'
    def add_arguments(self,parser):
        parser.add_argument('--email',required=True)
        parser.add_argument('--nom',required=True)
        parser.add_argument('--prenom',required=True)
        parser.add_argument('--sexe',required=True,choices=['M','F'])
    def handle(self,*args,**options):
        if db.one('SELECT count(*) n FROM systeme."T_Utilisateurs"')['n']:raise CommandError('Initialisation refusée : des utilisateurs existent déjà.')
        try:validate_email(options['email'])
        except ValidationError:raise CommandError('Adresse e-mail invalide.')
        if any(not options[key].strip() or len(options[key])>150 for key in ('nom','prenom')):raise CommandError('Nom et prénom requis, 150 caractères maximum.')
        secret=os.environ.get('SAUVERNDEKO_BOOTSTRAP_PASSWORD')
        if not secret:
            secret=getpass.getpass('Mot de passe du premier administrateur : ')
            if secret!=getpass.getpass('Confirmer le mot de passe : '):raise CommandError('Les mots de passe diffèrent.')
        if len(secret)<14:raise CommandError('Choisir un mot de passe d’au moins 14 caractères.')
        try:validate_password(secret,user=User(username=options['email'],email=options['email'],first_name=options['prenom'],last_name=options['nom']),password_validators=validators())
        except ValidationError as error:raise CommandError(' '.join(error.messages))
        db.ensure_writable()
        with transaction.atomic():
            db.query('LOCK TABLE systeme."T_Utilisateurs" IN EXCLUSIVE MODE')
            if db.one('SELECT count(*) n FROM systeme."T_Utilisateurs"')['n']:raise CommandError('Initialisation refusée : des utilisateurs existent déjà.')
            row=db.one('INSERT INTO systeme."T_Utilisateurs"("NomUser","PrenomUser","EmailUser","MotdepasseUser","SexeUser","Is_Admin","Is_staff","ValideUser") VALUES(%s,%s,%s,%s,%s,true,true,true) RETURNING "IdUser"',[options['nom'].strip(),options['prenom'].strip(),options['email'].strip().lower(),make_password(secret),options['sexe']])
            actor=Actor({'IdUser':row['IdUser'],'Is_Admin':True})
            audit({'schema':'systeme','name':'T_Utilisateurs'},'PLATFORM_BOOTSTRAP',new={'IdUser':row['IdUser'],'initialAdministrator':True},actor=actor)
        self.stdout.write('Premier administrateur créé ; reconnectez-vous depuis la page de connexion.')
