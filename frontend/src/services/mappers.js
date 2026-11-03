import {referenceLabel} from "../utils/referenceOptions";
import {formatCurrency} from "../utils/money";

export function normalizeText(value) {
  return String(value || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase();
}

export function matchesSearch(item, searchValue) {
  if (!searchValue) {
    return true;
  }

  return normalizeText(JSON.stringify(item)).includes(searchValue);
}

export function currencyValue(value) {
  if (value == null || value === "") {
    return "Prix a confirmer";
  }

  const number = Number(value);
  if (Number.isNaN(number)) {
    return `${value} FC`;
  }

  return `${new Intl.NumberFormat("fr-FR").format(number)} FC`;
}

export function getCollection(payload) {
  if (Array.isArray(payload)) {
    return payload;
  }

  if (Array.isArray(payload?.data)) {
    return payload.data;
  }

  if (Array.isArray(payload?.items)) {
    return payload.items;
  }

  return [];
}

export function getFirstDefined(...values) {
  return values.find((value) => value !== undefined && value !== null && value !== "");
}

export function getNested(source, path) {
  return path.reduce((accumulator, key) => accumulator?.[key], source);
}

export function pickNested(source, paths, fallback = null) {
  for (const path of paths) {
    const value = getNested(source, path);
    if (value !== undefined && value !== null && value !== "") {
      return value;
    }
  }

  return fallback;
}

export function buildDiscussionPath(targetType, targetId) {
  const params = new URLSearchParams();
  params.set("type", targetType);
  params.set("id", String(targetId));
  return `/discussions?${params.toString()}`;
}

export function mapArticlePublic(item, index) {
  const price = getFirstDefined(item?.PVArticle, item?.prixVente, item?.price);
  const photo = getFirstDefined(item?.PhotoArticle, item?.photo, item?.image, "/illustration-produits.svg");

  return {
    id: String(getFirstDefined(item?.ID_Article, item?.IdArticle, item?.id, `article-${index}`)),
    name: getFirstDefined(item?.NomArticle, item?.nom, item?.name, `Produit ${index + 1}`),
    reference: getFirstDefined(item?.RefArticle, item?.reference, item?.Reference, "Reference non renseignee"),
    price: price==null?"Prix à confirmer":formatCurrency(price,item?.DeviseCode),
    priceValue: price ?? null,
    currencyCode: item?.DeviseCode || "",
    availability: getFirstDefined(item?.EtatDisponibilite,"Disponibilité à confirmer"),
    photo,
    company: getFirstDefined(item?.NomEntite, "Entreprise non renseignée"),
    address: getFirstDefined(item?.AdresseEntite, "Adresse à confirmer"),
    phone: getFirstDefined(item?.PhoneEntite, "Téléphone à confirmer"),
    observation: "Disponibilité et prix à confirmer auprès de l’entreprise.",
  };
}

export function mapPharmacyPublic(item, index) {
  const type = item?.T_Generique ? referenceLabel(item.T_Generique) : pickNested(item, [["type"], ["TypeStructure"]], "Structure");
  const status = getFirstDefined(item?.StatutPublic, item?.statut, item?.ValideEntite);

  return {
    id: String(getFirstDefined(item?.IdEntite, item?.ID_Entite, item?.id, `entite-${index}`)),
    name: getFirstDefined(item?.NomEntite, item?.nom, item?.name, `Structure ${index + 1}`),
    address: getFirstDefined(item?.AdresseEntite, item?.adresse, item?.address, "Adresse non renseignee"),
    phone: getFirstDefined(item?.PhoneEntite, item?.telephone, item?.phone, "Telephone a confirmer"),
    type,
    status:
      typeof status === "boolean"
        ? status
          ? "Structure active"
          : "Verification en cours"
        : getFirstDefined(status, "Disponibilite a confirmer"),
    hours: getFirstDefined(item?.HorairesPublics, item?.horaires, item?.hours, "Horaires a confirmer"),
  };
}

export function mapExpertPublic(item, index) {
  const firstName = pickNested(item, [["T_Utilisateurs", "PrenomUser"], ["prenom"], ["firstName"]], "");
  const lastName = pickNested(item, [["T_Utilisateurs", "NomUser"], ["nom"], ["lastName"]], "");
  const fullName =
    `${firstName} ${lastName}`.trim() ||
    getFirstDefined(item?.fullName, item?.nomComplet, item?.name, `Professionnel ${index + 1}`);
  const structure = pickNested(
    item,
    [
      ["T_Professionnel_Entite", 0, "T_Entite", "NomEntite"],
      ["structure"],
      ["Structure"],
    ],
    "Structure a confirmer"
  );

  return {
    id: String(getFirstDefined(item?.IdProfessionnel, item?.ID_Professionnel, item?.id, `expert-${index}`)),
    firstName: firstName || fullName.split(" ")[0] || "Expert",
    lastName: lastName || fullName.split(" ").slice(1).join(" "),
    fullName,
    photo: pickNested(item, [["T_Utilisateurs", "UrlPhoto"], ["photo"], ["Photo"]], "/illustration-experts.svg"),
    professionalType: item?.T_GeneriqueType ? referenceLabel(item.T_GeneriqueType) : pickNested(
      item,
      [["typeProfessionnel"], ["professionalType"]],
      "Professionnel"
    ),
    specialty: item?.T_GeneriqueSpecialite ? referenceLabel(item.T_GeneriqueSpecialite) : pickNested(
      item,
      [["specialite"], ["specialty"]],
      "Specialite a confirmer"
    ),
    experience: getFirstDefined(item?.ExperienceAns, item?.experience, item?.experienceYears, null),
    structure,
    availability:
      getFirstDefined(item?.DisponibilitePublique, item?.availability) ||
      (item?.canContact === true ? "Contact par messagerie" : "Contact indisponible"),
    sector:item?.sector || "",
    title:item?.title || "",
    summary:item?.summary || "",
    locality:item?.locality || "",
    skills:Array.isArray(item?.skills)?item.skills:[],
    services:Array.isArray(item?.services)?item.services:[],
    structures:Array.isArray(item?.structures)?item.structures:[],
    canContact:item?.canContact===true,
  };
}

export function mapDiseasePublic(item, index) {
  return {
    id: String(getFirstDefined(item?.ID_Generique, item?.IdGenerique, item?.id, `maladie-${index}`)),
    name: getFirstDefined(item?.NomGenerique, item?.nom, item?.name, `Maladie ${index + 1}`),
    abbreviation: getFirstDefined(item?.AbrGenerique, item?.abbreviation, item?.abreviation, "Non renseignee"),
    description:
      getFirstDefined(item?.ObsGenerique, item?.description, item?.observation) || "Description non renseignee.",
    category: pickNested(
      item,
      [["T_CategorieGenerique", "NomCategorieGenerique"], ["categorie"], ["category"]],
      "Maladie"
    ),
  };
}

export function mapStatsPublic(payload, fallbackStats, products, pharmacies, experts, diseases) {
  const stats =
    payload && typeof payload === "object"
      ? (payload.data && typeof payload.data === "object" ? payload.data : payload)
      : {};

  return {
    productsCount: getFirstDefined(stats?.productsCount, stats?.articlesCount, products.length, fallbackStats.productsCount),
    pharmaciesCount: getFirstDefined(
      stats?.pharmaciesCount,
      stats?.structuresCount,
      pharmacies.length,
      fallbackStats.pharmaciesCount
    ),
    expertsCount: getFirstDefined(stats?.expertsCount, stats?.professionnelsCount, experts.length, fallbackStats.expertsCount),
    diseasesCount: getFirstDefined(stats?.diseasesCount, stats?.maladiesCount, diseases.length, fallbackStats.diseasesCount),
    activeStructures: getFirstDefined(
      stats?.activeStructures,
      stats?.structuresActives,
      pharmacies.length,
      fallbackStats.activeStructures
    ),
    latestAnnouncements: getFirstDefined(
      stats?.latestAnnouncements,
      stats?.annoncesCount,
      products.length,
      fallbackStats.latestAnnouncements
    ),
    responseLabel: getFirstDefined(stats?.responseLabel, stats?.delaiReponse, fallbackStats.responseLabel),
  };
}
