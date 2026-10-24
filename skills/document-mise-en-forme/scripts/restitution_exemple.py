"""Affichage documentaire SauverNdeko sur exemples ERP synthétiques, sans exporteur.

Aucune valeur-p ou borne d'intervalle n'est calculée. L'arrondi HALF_UP est
explicite pour la démonstration ; ne pas en déduire la politique applicative.
"""
from __future__ import annotations
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP, localcontext
from typing import Any, Mapping, Optional, Union, Collection
from datetime import date, datetime
import re

Nombre = Union[str, int, Decimal]


def decimal_fini(value: Nombre) -> Decimal:
    if isinstance(value, bool) or not isinstance(value, (str, int, Decimal)):
        raise ValueError("Valeur textuelle, entière ou Decimal requise, sans flottant implicite")
    try:
        number = Decimal(value)
    except (InvalidOperation, ValueError, TypeError) as exc:
        raise ValueError("Valeur décimale invalide") from exc
    if not number.is_finite():
        raise ValueError("Valeur non finie : motif d'indisponibilité requis")
    if len(number.as_tuple().digits) > 100 or abs(number.adjusted()) > 100:
        raise ValueError("Valeur hors périmètre de la démonstration")
    return number


def indisponible(motif: Optional[str]) -> str:
    if not isinstance(motif, str) or not motif.strip():
        raise ValueError("Motif d'indisponibilité requis")
    return "Non disponible — " + motif.strip()


def nombre_fr(value: Nombre, decimales: int = 2) -> str:
    if isinstance(decimales, bool) or not isinstance(decimales, int) or not 0 <= decimales <= 12:
        raise ValueError("Nombre de décimales invalide")
    number = decimal_fini(value)
    with localcontext() as ctx:
        ctx.prec = 220
        rounded = number.quantize(Decimal(1).scaleb(-decimales), rounding=ROUND_HALF_UP)
        if rounded == 0:
            rounded = abs(rounded)
        return f"{rounded:,.{decimales}f}".replace(",", " ").replace(".", ",")


def montant(value: Optional[Nombre], devise: Optional[str], motif: Optional[str] = None,
            decimales: int = 2, devises_autorisees: Optional[Collection[str]] = None) -> str:
    """Afficher une devise explicitement autorisée, sans défaut monétaire."""
    if devise is not None:
        if (not isinstance(devise, str) or not re.fullmatch(r"[A-Z]{3}", devise)
                or devises_autorisees is None or devise not in devises_autorisees):
            raise ValueError("Devise explicite présente dans la configuration autorisée requise")
    if value is None:
        return indisponible(motif)
    formatted = nombre_fr(value, decimales)
    return f"{formatted} {devise}" if devise else formatted + " — devise non renseignée"


def quantite(value: Optional[Nombre], unite: Optional[str], motif: Optional[str] = None,
             decimales: int = 3) -> str:
    if unite is not None and (not isinstance(unite, str) or not unite.strip()):
        raise ValueError("Unité textuelle explicite ou None requise")
    if value is None:
        return indisponible(motif)
    formatted = nombre_fr(value, decimales)
    return f"{formatted} {unite}" if unite else formatted + " — unité non renseignée"


def identifiant(value: Union[str, int]) -> str:
    """Conserver la référence comme texte, y compris zéros ou signe initial."""
    if isinstance(value, bool) or not isinstance(value, (str, int)) or not str(value).strip():
        raise ValueError("Identifiant textuel ou entier non vide requis")
    return str(value)


def cellule_texte(value: Union[str, int]) -> dict[str, str]:
    """Exemple de contrat de cellule ; ne produit pas lui-même un XLSX."""
    return {"valeur": identifiant(value), "type": "texte"}


def date_fr(value: Any, avec_heure: bool = False, motif: Optional[str] = None) -> str:
    """Afficher la date fournie sans conversion silencieuse de fuseau."""
    if value is None:
        return indisponible(motif)
    if isinstance(value, str):
        try:
            value = datetime.fromisoformat(value) if ("T" in value or " " in value) else date.fromisoformat(value)
        except ValueError as exc:
            raise ValueError("Date ISO invalide") from exc
    if not isinstance(value, (date, datetime)):
        raise ValueError("Date native ou ISO requise")
    if avec_heure and not isinstance(value, datetime):
        raise ValueError("Heure absente de la source")
    return value.strftime("%d/%m/%Y %H:%M" if avec_heure else "%d/%m/%Y")


def pourcentage(value: Optional[Nombre], motif: Optional[str] = None) -> str:
    return indisponible(motif) if value is None else nombre_fr(decimal_fini(value) * 100) + " %"


def points(value: Optional[Nombre], motif: Optional[str] = None) -> str:
    return indisponible(motif) if value is None else nombre_fr(value) + " points de pourcentage"


def valeur_p(value: Optional[Nombre], motif: Optional[str] = None) -> str:
    if value is None:
        return indisponible(motif)
    number = decimal_fini(value)
    if not 0 < number <= 1:
        raise ValueError("p doit être dans ]0,1] ; p=0 exige une explication du moteur")
    with localcontext() as ctx:
        ctx.prec = 120
        normalized = number.normalize()
        if normalized.adjusted() < -6:
            return format(normalized, "E").replace(".", ",").replace("E", "e")
        return format(normalized, "f").replace(".", ",")


def intervalle_fourni(bas: Nombre, haut: Nombre, niveau: Nombre,
                      methode: str, unite: str) -> str:
    """Afficher les bornes fournies, sans valider leur fondement statistique."""
    lower, upper, level = map(decimal_fini, (bas, haut, niveau))
    if lower > upper or not 0 < level < 1:
        raise ValueError("Bornes ou niveau invalides")
    if not methode.strip() or not unite.strip():
        raise ValueError("Méthode et unité requises")
    return (f"IC {pourcentage(level)} [{nombre_fr(lower)} ; {nombre_fr(upper)}] "
            f"{unite} — {methode}")


CHAMPS_DEMO = ("document_id", "mode", "organisation_id", "type_document", "portee",
               "filtres_appliques", "date_situation", "periode", "devise", "unite",
               "lignes", "totaux", "limites", "statut_validation")


def differences_demo(reference: Mapping[str, Any], rendu: Mapping[str, Any]) -> list[str]:
    """Comparer deux manifestes fictifs ; ne lit aucun fichier Office/PDF réel."""
    return [key for key in CHAMPS_DEMO
            if key not in reference or key not in rendu or reference[key] != rendu[key]]
