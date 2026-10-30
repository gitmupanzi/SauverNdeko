import AppIcon from "../../components/AppIcon";
import UserAvatar from "../../components/UserAvatar";
import { formatDate } from "../logistique/logistiqueShared";

export const ADMIN_ROOT = "/api/systeme/administration";
export const adminTabKey = key => key === "profils" ? "utilisateurs" : key === "localisations" ? "entites" : key;
const text = (key, label, width = 180) => ({ key, label, width });
const date = (key, label = "Date et heure") => ({ key, label, width: 180, render: row => formatDate(row[key], { withTime: true }) });
const flag = (key, label = "État") => ({ key, label, width: 110, render: row => row[key] == null ? "—" : <span className={"erp-status is-" + (row[key] ? "success" : "neutral")}>{row[key] ? "Actif" : "Inactif"}</span> });
const yes = (key, label) => ({ key, label, width: 120, render: row => row[key] == null ? "—" : row[key] ? "Oui" : "Non" });
const person = { key: "NomUser", label: "Utilisateur", width: 260, render: row => <span className="erp-product-cell"><UserAvatar user={row} photo="" decorative/><span className="erp-product-identity"><strong>{[row.PrenomUser, row.NomUser].filter(Boolean).join(" ") || "Sans nom"}</strong><small>{row.EmailUser || "—"}</small></span></span> };
const boolOptions = [{ value: "true", label: "Actif" }, { value: "false", label: "Inactif" }];
const filter = (key, label, source) => ({ key, label, source });
const state = key => ({ key, label: "État", options: boolOptions });
const badge = (key, label, width = 140) => ({ key, label, width, render: row => row[key] ? <span className="erp-status is-neutral">{row[key]}</span> : "—" });
const identity = (key, label, icon = "document", width = 260) => ({ key, label, width, render: row => <span className="erp-product-cell"><span className="erp-product-avatar"><AppIcon name={icon} size={18}/></span><span className="erp-product-identity"><strong>{row[key] || "Sans libellé"}</strong></span></span> });

/** Colonnes métier et clés stables ; les recherches et exports restent au serveur. */
export const ADMIN_REGISTERS = {
  utilisateurs: {
    title: "Utilisateurs", description: "Comptes, informations professionnelles et accès.", icon: "user", pk: "IdUser", name: "NomUser", editor: "users", create: "Nouvel utilisateur", active: "ValideUser", dateKey: "DatecreationUser",
    columns: [person, text("MatriculeUser","Matricule",150), text("NomEntite", "Entreprise", 220), text("Service","Service",190), text("Fonction","Fonction",190), text("Role", "Rôle", 180), flag("ValideUser"), yes("Is_Admin", "Admin plateforme"), {key:"DateEmbauche",label:"Date d’embauche",width:150,render:row=>formatDate(row.DateEmbauche,{withTime:false})}, {key:"DateFinEmploi",label:"Fin d’emploi",width:150,render:row=>formatDate(row.DateFinEmploi,{withTime:false})}, yes("EstAffectable","Affectation possible"), text("ObservationProfessionnelle","Observations professionnelles",280), date("DatecreationUser", "Créé le"), text("PrenomUser", "Prénom"), text("EmailUser", "Adresse e-mail", 240), text("PhoneUser", "Téléphone"), text("SexeUser", "Sexe", 90), yes("Is_staff", "Équipe"), text("IdUser", "Identifiant", 110)],
    visible: ["NomUser", "MatriculeUser", "NomEntite", "Service", "Fonction", "Role", "ValideUser", "Is_Admin", "actions"], sort: ["NomUser", "asc"], filters: [filter("IdEntite", "Entreprise", "entities"), filter("ID_ServiceFk","Service","personnelServices"), filter("ID_FonctionFk","Fonction","personnelFonctions"), filter("IdRoleFk", "Rôle", "roles"), state("ValideUser"), { key: "Is_Admin", label: "Administration", options: [{ value: "true", label: "Administrateurs" }, { value: "false", label: "Autres comptes" }] }],
  },
  profils: {
    title: "Profils utilisateurs", description: "Identités, services et informations professionnelles.", icon: "user", pk: "IdUser", name: "NomUser", editor: "profiles", active: "ValideUser", dateKey: "DatecreationUser",
    columns: [person,text("MatriculeUser","Matricule",150),text("Service","Service",190),text("Fonction","Fonction",190),{key:"DateEmbauche",label:"Date d’embauche",width:150,render:row=>formatDate(row.DateEmbauche,{withTime:false})},{key:"DateFinEmploi",label:"Fin d’emploi",width:150,render:row=>formatDate(row.DateFinEmploi,{withTime:false})},yes("EstAffectable","Affectation possible"),text("ObservationProfessionnelle","Observations professionnelles",280), text("PhoneUser", "Téléphone"), text("NomEntite", "Entreprise", 230), text("Role", "Rôle", 180), flag("ValideUser"), yes("Is_staff", "Équipe"), yes("Is_Admin", "Admin plateforme"), date("DatecreationUser", "Créé le"), text("EmailUser", "Adresse e-mail", 240), text("EmailEntite", "E-mail entreprise", 240), text("PhoneEntite", "Téléphone entreprise"), text("SexeUser", "Sexe", 90), text("IdUser", "Identifiant", 110)],
    visible: ["NomUser", "MatriculeUser", "NomEntite", "Service", "Fonction", "ValideUser", "actions"], sort: ["NomUser", "asc"], filters: [filter("IdEntite", "Entreprise", "entities"),filter("ID_ServiceFk","Service","personnelServices"),filter("ID_FonctionFk","Fonction","personnelFonctions"), filter("IdRoleFk", "Rôle", "roles"), state("ValideUser")],
  },
  entites: {
    title: "Entreprises", description: "Les organisations de la plateforme.", icon: "apps", pk: "IdEntite", name: "NomEntite", editor: "entities", create: "Nouvelle entreprise", active: "ValideEntite",
    columns: [identity("NomEntite", "Entreprise", "apps"), text("EmailEntite", "Adresse e-mail", 240), text("PhoneEntite", "Téléphone"), text("AdresseEntite", "Adresse", 280), flag("ValideEntite"), text("IdEntite", "Identifiant", 110)],
    visible: ["NomEntite", "EmailEntite", "PhoneEntite", "ValideEntite", "actions"], sort: ["NomEntite", "asc"], filters: [state("ValideEntite")],
  },
  roles: {
    title: "Rôles", description: "Les profils d’accès partagés.", icon: "shield", pk: "ID_Generique", name: "NomGenerique", editor: "roles", create: "Nouveau rôle", active: "ValideGenerique", platformWrite: true,
    columns: [identity("NomGenerique", "Rôle", "shield"), text("AbrGenerique", "Code", 160), text("ObsGenerique", "Description", 360), flag("ValideGenerique"), text("ID_Generique", "Identifiant", 110)],
    visible: ["NomGenerique", "AbrGenerique", "ObsGenerique", "ValideGenerique", "actions"], sort: ["NomGenerique", "asc"], filters: [state("ValideGenerique")],
  },
  licences: {
    title: "Licences", description: "Périodes d’accès et entreprises bénéficiaires.", icon: "shield", pk: "IdLicence", name: "IdLicence", editor: "licences", create: "Nouvelle licence", active: "ValideLicence", dateKey: "DateFin", platformWrite: true,
    columns: [{ key: "IdLicence", label: "Licence", width: 150, render: row => "Licence #" + row.IdLicence }, text("NomEntite", "Entreprise", 260), date("DateDebut", "Début"), date("DateFin", "Échéance"), badge("statut_licence", "Statut"), flag("ValideLicence"), yes("ExpireeLicence", "Expiration déclarée")],
    visible: ["IdLicence", "NomEntite", "DateDebut", "DateFin", "statut_licence", "actions"], sort: ["DateFin", "asc"], filters: [filter("IdEntiteFk", "Entreprise", "entities"), state("ValideLicence"), { key: "statut_licence", label: "Statut de licence", options: [{ value: "Active", label: "Active" }, { value: "Expirée", label: "Expirée" }, { value: "À venir", label: "À venir" }, { value: "Inactive", label: "Inactive" }] }],
  },
  localisations: {
    title: "Localisations des entreprises", description: "Adresses et rattachements territoriaux.", icon: "globe", pk: "IdEntiteLocalisation", name: "NomEntite", editor: "locations", create: "Nouvelle localisation", dateKey: "DateCreation",
    columns: [identity("NomEntite", "Entreprise", "globe"), text("AdresseDetaillee", "Adresse", 280), text("NomNiveau_3", "Niveau territorial 3", 200), text("NomNiveau_4", "Niveau territorial 4", 200), text("NomNiveau_5", "Niveau territorial 5", 200), text("Latitude", "Latitude", 130), text("Longitude", "Longitude", 130), date("DateCreation", "Créé le"), text("TypeEntite", "Type d’entreprise"), text("IdEntiteLocalisation", "Identifiant", 110)],
    visible: ["NomEntite", "AdresseDetaillee", "NomNiveau_3", "NomNiveau_4", "actions"], sort: ["NomEntite", "asc"], filters: [filter("IdEntite", "Entreprise", "entities")],
  },
  correspondances: {
    title: "Correspondances FK", description: "Références utilisées par les champs de l’application.", icon: "movements", pk: "IdFkCorrespondance", name: "FieldLabel", editor: "fk", create: "Nouvelle correspondance", active: "ValideFkCorrespondance", dateKey: "UpdatedAt", platformWrite: true,
    columns: [identity("FieldLabel", "Champ", "movements"), text("ModuleName", "Module", 140), text("SourceKey", "Source", 180), text("NomCategorieGenerique", "Catégorie", 210), text("MappingValue", "Valeur", 170), badge("SettingScope", "Portée", 120), flag("ValideFkCorrespondance"), date("UpdatedAt", "Mis à jour le"), text("SchemaName", "Schéma", 130), text("ViewName", "Vue", 220), text("FieldName", "Nom du champ", 180), text("MappingType", "Type de correspondance", 200), text("ScopeValue", "Cible", 130), text("UpdatedByName", "Modifié par"), text("IdFkCorrespondance", "Identifiant", 110)],
    visible: ["FieldLabel", "ModuleName", "NomCategorieGenerique", "MappingValue", "SettingScope", "ValideFkCorrespondance", "actions"], sort: ["ModuleName", "asc"], filters: [state("ValideFkCorrespondance"), { key: "SettingScope", label: "Portée", options: [{ value: "global", label: "Plateforme" }, { value: "entity", label: "Entreprise" }, { value: "country", label: "Pays" }] }, filter("TargetCategoryIdFk", "Catégorie", "categories")],
  },
  parametres: {
    title: "Paramètres UI", description: "Réglages partagés de l’application.", icon: "settings", pk: "IdAdminUISetting", name: "SettingLabel", editor: "settings", create: "Nouveau paramètre", active: "ValideSetting", dateKey: "UpdatedAt", platformWrite: true,
    columns: [identity("SettingLabel", "Paramètre", "settings"), text("SettingKey", "Clé", 230), text("SettingGroup", "Groupe", 160), badge("SettingScope", "Portée", 120), text("SettingValue", "Valeur", 260), flag("ValideSetting"), date("UpdatedAt", "Mis à jour le"), text("UpdatedByName", "Modifié par"), text("ScopeValue", "Cible", 140), text("SettingType", "Format", 140), yes("IsEditable", "Modifiable"), yes("IsSystem", "Système"), text("IdAdminUISetting", "Identifiant", 110)],
    visible: ["SettingLabel", "SettingGroup", "SettingScope", "SettingValue", "ValideSetting", "actions"], sort: ["SettingGroup", "asc"], filters: [state("ValideSetting"), { key: "SettingScope", label: "Portée", options: [{ value: "global", label: "Plateforme" }, { value: "entite", label: "Entreprise" }, { value: "user", label: "Utilisateur" }, { value: "module", label: "Module" }] }],
  },
  audit: {
    title: "Journaux d’audit", description: "Historique des opérations enregistrées.", icon: "document", pk: "IdLog", name: "TableName", dateKey: "ChangedAt", platform: true,
    columns: [date("ChangedAt"), text("TableName", "Objet", 260), badge("Operation", "Opération"), text("NomEntite", "Entreprise", 240), text("IdLog", "Identifiant", 110)],
    visible: ["ChangedAt", "TableName", "Operation", "NomEntite", "actions"], sort: ["ChangedAt", "desc"], filters: [{ key: "Operation", label: "Opération", options: ["INSERT", "UPDATE", "DELETE"].map(value => ({ value, label: { INSERT: "Création", UPDATE: "Modification", DELETE: "Suppression" }[value] })) }],
  },
  connexions: {
    title: "Historique de connexion", description: "Événements de connexion enregistrés.", icon: "clock", pk: "IdLogin", name: "NomUser", dateKey: "DateLogin", platform: true,
    columns: [date("DateLogin"), person, badge("TypeLogin", "Événement", 180), text("NomEntite", "Entreprise", 240), text("EmailUser", "Adresse e-mail", 240), text("IdLogin", "Identifiant", 110)],
    visible: ["DateLogin", "NomUser", "TypeLogin", "NomEntite", "actions"], sort: ["DateLogin", "desc"], filters: [filter("IdEntite", "Entreprise", "entities")],
  },
  "audit-parametres": {
    title: "Historique des paramètres", description: "Modifications des réglages de l’application.", icon: "clock", pk: "IdLog", name: "SettingLabel", dateKey: "ChangedAt", platform: true,
    columns: [date("ChangedAt"), text("SettingLabel", "Paramètre", 260), badge("Operation", "Opération"), text("SettingGroup", "Groupe"), text("UpdatedByName", "Modifié par", 200), badge("SettingScope", "Portée"), text("IdLog", "Identifiant", 110)],
    visible: ["ChangedAt", "SettingLabel", "Operation", "SettingGroup", "UpdatedByName", "actions"], sort: ["ChangedAt", "desc"], filters: [],
  },
};

export const ADMIN_NAVIGATION = [
  { label: "Pilotage", items: [{ key: "tableau-de-bord", label: "Tableau de bord", icon: "dashboard" }] },
  { label: "Accès", items: [{ key: "utilisateurs", label: "Utilisateurs", icon: "user" }, { key: "roles", label: "Rôles", icon: "shield" }, { key: "permissions", label: "Permissions", icon: "lock", platform: true }] },
  { label: "Organisation", items: [{ key: "entites", label: "Entreprises", icon: "apps" }, { key: "licences", label: "Licences", icon: "shield" }] },
  { label: "Paramétrage", items: [{ key: "correspondances", label: "Correspondances FK", icon: "movements" }, { key: "parametres", label: "Paramètres UI", icon: "settings" }, { key: "messagerie", label: "Messagerie", icon: "mail", platform: true }] },
  { label: "Traçabilité", items: [{ key: "audit", label: "Journaux d’audit", icon: "document", platform: true }, { key: "connexions", label: "Connexions", icon: "clock", platform: true }] },
];
