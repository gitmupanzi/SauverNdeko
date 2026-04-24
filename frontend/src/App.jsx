import { startTransition, useDeferredValue, useEffect, useRef, useState } from "react";
import Carousel from "react-bootstrap/Carousel";

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || "";

const sampleProducts = [
  {
    id: "demo-paracetamol",
    name: "Paracetamol 500 mg",
    price: "4 500 FC",
    stock: "24 boites",
    info: "Medicament de premiere intention pour les douleurs courantes et la fievre.",
    posologie: "Respecter la posologie indiquee par le professionnel de sante ou la notice.",
    indications: "Fievre, douleurs legeres a moderees, inconfort passager.",
    contre: "A verifier en cas d'allergie, de surdosage ou de traitement associe.",
  },
  {
    id: "demo-amoxicilline",
    name: "Amoxicilline",
    price: "8 000 FC",
    stock: "12 boites",
    info: "Antibiotique a utiliser uniquement sur conseil d'un professionnel de sante.",
    posologie: "Toujours suivre une prescription et terminer le traitement recommande.",
    indications: "Infections bacteriennes selon avis medical.",
    contre: "A eviter sans orientation medicale et en cas d'allergie connue.",
  },
  {
    id: "demo-vitamine-c",
    name: "Vitamine C",
    price: "3 000 FC",
    stock: "40 boites",
    info: "Produit de soutien utilise dans plusieurs routines de prevention et de recuperation.",
    posologie: "Selon la forme et les conseils d'utilisation du fournisseur ou du medecin.",
    indications: "Soutien general et complements selon le besoin.",
    contre: "Verifier la compatibilite avec les autres traitements.",
  },
];

const sampleEntities = [
  {
    id: "entite-1",
    name: "Hopital Central",
    address: "Gombe, avenue principale",
    phone: "+243 000 000 001",
    hours: "24h/24",
    availability: "Produits courants disponibles",
    services: ["Urgence", "Pharmacie", "Orientation"],
  },
  {
    id: "entite-2",
    name: "Pharmacie de la Liberte",
    address: "Masina, boulevard Lumumba",
    phone: "+243 000 000 002",
    hours: "07:00 - 22:00",
    availability: "Stock mis a jour",
    services: ["Vente", "Conseil", "Livraison"],
  },
  {
    id: "entite-3",
    name: "Depot Sante Plus",
    address: "Kinshasa, marche central",
    phone: "+243 000 000 003",
    hours: "08:00 - 18:00",
    availability: "Depot de proximite",
    services: ["Gros", "Detail", "Approvisionnement"],
  },
  {
    id: "entite-4",
    name: "Clinique Nzambe",
    address: "Ngaliema, route principale",
    phone: "+243 000 000 004",
    hours: "24h/24",
    availability: "Accueil clinique",
    services: ["Consultation", "Pharmacie", "Suivi"],
  },
];

const sampleExperts = [
  {
    id: "expert-1",
    name: "Dr Mbala",
    specialty: "Medecine generale",
    availability: "Disponible aujourd'hui",
    contact: "Contacter",
    commune: "Gombe",
  },
  {
    id: "expert-2",
    name: "Dr Kanku",
    specialty: "Pediatrie",
    availability: "Reponse rapide",
    contact: "Contacter",
    commune: "Masina",
  },
  {
    id: "expert-3",
    name: "Dr Mbuyi",
    specialty: "Cardiologie",
    availability: "Sur rendez-vous",
    contact: "Contacter",
    commune: "Ngaliema",
  },
];

const drawerItems = [
  { label: "Accueil", view: "home", icon: "home" },
  { label: "Chercher un produit", view: "products", icon: "search" },
  { label: "Pharmacies", view: "pharmacies", icon: "pin" },
  { label: "Chercher un expert", view: "experts", icon: "group" },
  { label: "Discussions", view: "discussions", icon: "chat" },
];

const topbarItems = [
  { label: "Accueil", view: "home" },
  { label: "Produits", view: "products" },
  { label: "Pharmacies", view: "pharmacies" },
  { label: "Experts", view: "experts" },
  { label: "Discussions", view: "discussions" },
];

function normalizeText(value) {
  return String(value || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase();
}

function matchesSearch(item, searchValue) {
  if (!searchValue) {
    return true;
  }

  return normalizeText(JSON.stringify(item)).includes(searchValue);
}

function chunkItems(items, size) {
  const chunks = [];

  for (let index = 0; index < items.length; index += size) {
    chunks.push(items.slice(index, index + size));
  }

  return chunks;
}

function currencyValue(value) {
  if (value == null || value === "") {
    return "Prix a confirmer";
  }

  return `${value} FC`;
}

function formatDateLabel() {
  try {
    return new Date().toLocaleDateString("fr-FR", {
      weekday: "long",
      day: "numeric",
      month: "long",
      year: "numeric",
    });
  } catch {
    return "Aujourd'hui";
  }
}

function productFromArticle(item, index) {
  const itemId = item?.ID_Article ?? item?.IdArticle ?? `article-${index}`;

  return {
    id: String(itemId),
    name: item?.NomArticle || `Produit ${index + 1}`,
    price: currencyValue(item?.PVArticle),
    stock: item?.QteArticle != null ? `${item.QteArticle} unites` : "Stock non renseigne",
    info:
      item?.ObsArticle ||
      "Informations produit en cours de consolidation. Verifiez toujours la disponibilite avant achat.",
    posologie:
      item?.RefArticle ||
      "Posologie a confirmer avec un professionnel de sante ou la notice du produit.",
    indications:
      item?.NomArticle
        ? `${item.NomArticle} peut etre consulte depuis cette fiche puis verifie chez un specialiste.`
        : "Indications a confirmer selon le besoin et le contexte medical.",
    contre:
      "Ne pas se baser uniquement sur l'interface. Demandez conseil a un professionnel avant toute utilisation.",
  };
}

function entityFromRecord(item, index) {
  const itemId = item?.IdEntite ?? `entite-${index}`;

  return {
    id: String(itemId),
    name: item?.NomEntite || `Point de service ${index + 1}`,
    address: item?.AdresseEntite || item?.EmailEntite || "Adresse non renseignee",
    phone: item?.PhoneEntite || "Telephone a confirmer",
    hours: "Horaires a confirmer",
    availability: item?.ValideEntite ? "Structure verifiee" : "Verification en cours",
    services: ["Orientation", "Disponibilite", "Contact"],
  };
}

function expertFromRecord(item, index) {
  const itemId = item?.IdProfessionnel ?? `expert-${index}`;
  const name =
    item?.T_Utilisateurs?.NomUser ||
    item?.NumeroIdentification ||
    `Professionnel ${index + 1}`;

  return {
    id: String(itemId),
    name,
    specialty: item?.IdSpecialiteFk ? `Specialite ${item.IdSpecialiteFk}` : "Specialite a confirmer",
    availability: item?.ValideProfessionnel ? "Profil verifie" : "Profil a verifier",
    contact: "Contacter",
    commune: "Kinshasa",
  };
}

function Icon({ name }) {
  switch (name) {
    case "menu":
      return (
        <svg className="icon-svg" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M4 7h16M4 12h16M4 17h16" />
        </svg>
      );
    case "search":
      return (
        <svg className="icon-svg" viewBox="0 0 24 24" aria-hidden="true">
          <circle cx="11" cy="11" r="6" />
          <path d="m16 16 4 4" />
        </svg>
      );
    case "back":
      return (
        <svg className="icon-svg" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M15 5 8 12l7 7" />
        </svg>
      );
    case "home":
      return (
        <svg className="icon-svg" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M4 11 12 5l8 6" />
          <path d="M7 10v8h10v-8" />
        </svg>
      );
    case "chat":
      return (
        <svg className="icon-svg" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M6 16H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
          <path d="M10 18h4l4 3v-3h1a2 2 0 0 0 2-2v-4a2 2 0 0 0-2-2h-9a2 2 0 0 0-2 2v4a2 2 0 0 0 2 2Z" />
        </svg>
      );
    case "group":
      return (
        <svg className="icon-svg" viewBox="0 0 24 24" aria-hidden="true">
          <circle cx="9" cy="9" r="3" />
          <circle cx="17" cy="10" r="2.5" />
          <path d="M4 19c.8-2.5 3-4 5-4s4.2 1.5 5 4" />
          <path d="M14 18c.6-1.8 2-2.8 3.7-2.8 1 0 2 .3 2.8 1" />
        </svg>
      );
    case "pin":
      return (
        <svg className="icon-svg" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M12 21s6-5.3 6-11a6 6 0 1 0-12 0c0 5.7 6 11 6 11Z" />
          <circle cx="12" cy="10" r="2.2" />
        </svg>
      );
    case "signal":
      return (
        <svg className="icon-svg icon-signal" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M12 18a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z" />
          <path d="M7.8 16.2a6 6 0 0 1 0-8.4" />
          <path d="M16.2 7.8a6 6 0 0 1 0 8.4" />
          <path d="M4.8 19.2a10 10 0 0 1 0-14.4" />
          <path d="M19.2 4.8a10 10 0 0 1 0 14.4" />
        </svg>
      );
    default:
      return null;
  }
}

function TopBar({ view, onMenu, onBack, onSearch, onNavigate }) {
  const titleMap = {
    home: "Home",
    products: "Chercher un medicament",
    pharmacies: "Pharmacies et depots",
    experts: "Trouver un expert",
    discussions: "Discussions",
    checkout: "Commander",
  };

  const isHome = view === "home";
  const showSearch = view !== "discussions";

  return (
    <header className="topbar">
      <div className="topbar-mobile">
        <button className="icon-button" type="button" onClick={isHome ? onMenu : onBack}>
          <Icon name={isHome ? "menu" : "back"} />
        </button>
        <h1 className="topbar-title">{titleMap[view] || "SauverNdeko"}</h1>
        {showSearch ? (
          <button className="icon-button" type="button" onClick={onSearch}>
            <Icon name="search" />
          </button>
        ) : (
          <span className="topbar-spacer" aria-hidden="true" />
        )}
      </div>

      <div className="topbar-desktop">
        <button className="desktop-brand" type="button" onClick={() => onNavigate("home")}>
          <img src="/sauverndeko-logo.jpg" alt="SauverNdeko" />
          <span>
            <strong>SauverNdeko</strong>
            <small>Rechercher, contacter, acheter</small>
          </span>
        </button>

        <nav className="desktop-tabs" aria-label="Navigation principale">
          {topbarItems.map((item) => (
            <button
              key={item.view}
              className={`desktop-tab ${view === item.view ? "is-active" : ""}`}
              type="button"
              onClick={() => onNavigate(item.view)}
            >
              {item.label}
            </button>
          ))}
        </nav>

        <button className="desktop-search" type="button" onClick={onSearch}>
          <i className="bi bi-search" aria-hidden="true" />
          <span>Rechercher</span>
        </button>
      </div>
    </header>
  );
}

function Sidebar({ isOpen, onClose, onNavigate }) {
  return (
    <aside className={`sidebar-drawer ${isOpen ? "is-open" : ""}`} aria-hidden={!isOpen}>
      <div className="drawer-banner">
        <span>Menu</span>
        <button className="icon-button drawer-menu-button" type="button" onClick={onClose}>
          <Icon name="menu" />
        </button>
      </div>
      <nav className="drawer-nav">
        {drawerItems.map((item) => (
          <button
            key={item.view}
            className="drawer-row"
            type="button"
            onClick={() => onNavigate(item.view)}
          >
            <span className="drawer-row-icon">
              <Icon name={item.icon} />
            </span>
            <span className="drawer-row-label">{item.label}</span>
          </button>
        ))}
      </nav>
    </aside>
  );
}

function SearchResultGroup({ title, items, onSelect }) {
  return (
    <section className="search-group">
      <div className="search-group-head">
        <strong>{title}</strong>
        <span>{items.length}</span>
      </div>
      {items.length === 0 ? (
        <div className="search-empty-inline">Aucun resultat.</div>
      ) : (
        <div className="search-list">
          {items.map((item) => (
            <button
              key={item.id}
              className="search-result"
              type="button"
              onClick={() => onSelect(item)}
            >
              <strong>{item.title}</strong>
              <span>{item.subtitle}</span>
            </button>
          ))}
        </div>
      )}
    </section>
  );
}

function SearchOverlay({
  isOpen,
  search,
  results,
  onClose,
  onChange,
  onSelect,
  inputRef,
}) {
  return (
    <section className={`search-overlay ${isOpen ? "is-open" : ""}`} aria-hidden={!isOpen}>
      <div className="search-modal">
        <div className="search-head">
          <div>
            <span className="search-kicker">Recherche</span>
            <h2>Rechercher un produit, une pharmacie ou un expert</h2>
          </div>
          <button className="search-close" type="button" onClick={onClose}>
            Fermer
          </button>
        </div>

        <input
          ref={inputRef}
          className="search-input"
          type="search"
          placeholder="Produit, pharmacie, medecin..."
          value={search}
          onChange={onChange}
        />

        {!search ? (
          <div className="search-helper-grid">
            <article>
              <strong>Produit</strong>
              <p>Trouvez vite un article puis ouvrez sa fiche detaillee.</p>
            </article>
            <article>
              <strong>Pharmacie</strong>
              <p>Reperez les structures utiles et les points de disponibilite.</p>
            </article>
            <article>
              <strong>Expert</strong>
              <p>Consultez les profils et demarrez un parcours de contact.</p>
            </article>
          </div>
        ) : normalizeText(search).length < 2 ? (
          <div className="search-empty-panel">Ecrivez au moins 2 caracteres.</div>
        ) : (
          <div className="search-results-grid">
            <SearchResultGroup title="Produits" items={results.products} onSelect={onSelect} />
            <SearchResultGroup title="Pharmacies" items={results.entities} onSelect={onSelect} />
            <SearchResultGroup title="Experts" items={results.experts} onSelect={onSelect} />
          </div>
        )}
      </div>
    </section>
  );
}

function VerificationCard({ health }) {
  return (
    <section className="verify-card">
      <div className="verify-logo">
        <img src="/sauverndeko-logo.jpg" alt="SauverNdeko" />
      </div>
      <div className="d-flex align-items-center gap-2">
        <span className={`badge rounded-pill ${health.ok ? "text-bg-success" : "text-bg-secondary"}`}>
          {health.ok ? "Connecte" : "Demo"}
        </span>
        <p className="verify-date">{formatDateLabel()}</p>
      </div>
      <p className="verify-text">
        {health.ok
          ? "Felicitations, vous disposez des dernieres donnees."
          : "Mode demonstration actif. Les donnees reelles seront affichees des que l'API repond."}
      </p>
      <button className="verify-button d-inline-flex align-items-center gap-2" type="button">
        <i className="bi bi-arrow-repeat" aria-hidden="true" />
        VERIFIER
      </button>
    </section>
  );
}

function DesktopOverview({ health, productsCount, entitiesCount, expertsCount, onSearch, onProducts, onExperts }) {
  return (
    <section className="desktop-overview">
      <div className="desktop-overview-copy">
        <span className="desktop-kicker">Webapp SauverNdeko</span>
        <h2>Retrouvez un produit, un expert ou une pharmacie depuis une interface plus claire.</h2>
        <div className="d-flex flex-wrap gap-2">
          <span className="badge text-bg-primary rounded-pill px-3 py-2">Recherche rapide</span>
          <span className="badge text-bg-light rounded-pill px-3 py-2 text-primary">Contact direct</span>
          <span className="badge text-bg-light rounded-pill px-3 py-2 text-primary">Parcours achat</span>
        </div>
        <div className="desktop-overview-actions">
          <button className="desktop-primary d-inline-flex align-items-center gap-2" type="button" onClick={onSearch}>
            <i className="bi bi-search" aria-hidden="true" />
            Lancer une recherche
          </button>
          <button className="desktop-secondary d-inline-flex align-items-center gap-2" type="button" onClick={onProducts}>
            <i className="bi bi-capsule" aria-hidden="true" />
            Voir les produits
          </button>
          <button className="desktop-secondary d-inline-flex align-items-center gap-2" type="button" onClick={onExperts}>
            <i className="bi bi-people" aria-hidden="true" />
            Voir les experts
          </button>
        </div>
      </div>

      <div className="desktop-overview-stats">
        <article>
          <strong>{productsCount}</strong>
          <span>Produits visibles</span>
        </article>
        <article>
          <strong>{entitiesCount}</strong>
          <span>Pharmacies et depots</span>
        </article>
        <article>
          <strong>{expertsCount}</strong>
          <span>Experts disponibles</span>
        </article>
        <article>
          <strong>{health.ok ? "API OK" : "DEMO"}</strong>
          <span>{health.ok ? "Donnees synchronisees" : "Mode de demonstration"}</span>
        </article>
      </div>
    </section>
  );
}

function WebFeatureCard({ icon, title, text, buttonLabel, onClick, tone = "primary" }) {
  return (
    <article className={`web-feature-card ${tone}`}>
      <div className="web-feature-icon">
        <i className={`bi ${icon}`} aria-hidden="true" />
      </div>
      <strong>{title}</strong>
      <p>{text}</p>
      <button className={`web-feature-button ${tone}`} type="button" onClick={onClick}>
        {buttonLabel}
      </button>
    </article>
  );
}

function WebDataPanel({ title, icon, children, actionLabel, onAction }) {
  return (
    <section className="web-data-panel">
      <div className="web-data-head">
        <div className="d-flex align-items-center gap-2">
          <i className={`bi ${icon}`} aria-hidden="true" />
          <strong>{title}</strong>
        </div>
        {actionLabel ? (
          <button className="web-data-link" type="button" onClick={onAction}>
            {actionLabel}
          </button>
        ) : null}
      </div>
      <div className="web-data-body">{children}</div>
    </section>
  );
}

function AnnouncementCard({ item, onSelect }) {
  return (
    <button className="announcement-card" type="button" onClick={() => onSelect(item)}>
      <div className="announcement-thumb">
        <img src="/illustration-produits.svg" alt={item.name} />
      </div>
      <div className="announcement-copy">
        <span className="badge rounded-pill text-bg-light text-primary-emphasis mb-2">Annonce</span>
        <strong>{item.name}</strong>
        <p>{item.info}</p>
      </div>
    </button>
  );
}

function AnnouncementSlider({ items, onSelect }) {
  const slides = chunkItems(items, 3);

  return (
    <Carousel
      className="announcement-carousel"
      indicators={slides.length > 1}
      controls={slides.length > 1}
      interval={null}
      touch
      slide
    >
      {slides.map((group, index) => (
        <Carousel.Item key={`announcement-slide-${index}`}>
          <div className="announcement-slide">
            {group.map((item) => (
              <AnnouncementCard key={item.id} item={item} onSelect={onSelect} />
            ))}
          </div>
        </Carousel.Item>
      ))}
    </Carousel>
  );
}

function PromoCard({ tone, title, buttonLabel, onClick, image }) {
  return (
    <article className={`promo-card promo-${tone}`}>
      <div className="promo-overlay" />
      <img className="promo-illustration" src={image} alt="" aria-hidden="true" />
      <div className="promo-copy">
        <p>{title}</p>
        <button className={`promo-button promo-button-${tone} d-inline-flex align-items-center gap-2`} type="button" onClick={onClick}>
          <i className={`bi ${tone === "product" ? "bi-search-heart" : "bi-chat-dots"}`} aria-hidden="true" />
          {buttonLabel}
        </button>
      </div>
    </article>
  );
}

function NearbyRow({ item, onSelect }) {
  return (
    <button className="nearby-row" type="button" onClick={() => onSelect(item)}>
      <span className="nearby-icon">
        <i className="bi bi-geo-alt" aria-hidden="true" />
      </span>
      <div>
        <strong>{item.name}</strong>
        <p>{item.address}</p>
        <small className="text-muted">{item.phone}</small>
      </div>
    </button>
  );
}

function ProductMiniCard({ item, isActive, onSelect }) {
  return (
    <button
      className={`product-mini-card ${isActive ? "is-active" : ""}`}
      type="button"
      onClick={() => onSelect(item.id)}
    >
      <span className="badge rounded-pill text-bg-light text-primary-emphasis mb-2">Produit</span>
      <strong>{item.name}</strong>
      <span>{item.price}</span>
    </button>
  );
}

function DetailBlock({ title, text }) {
  return (
    <article className="detail-block">
      <div className="d-flex align-items-center gap-2 mb-2">
        <span className="badge rounded-pill text-bg-primary-subtle text-primary-emphasis">{title}</span>
      </div>
      <p>{text}</p>
    </article>
  );
}

function ExpertCard({ item, onContact }) {
  return (
    <article className="expert-card">
      <div>
        <strong>{item.name}</strong>
        <p>{item.specialty}</p>
        <small>{item.availability}</small>
      </div>
      <button className="contact-button d-inline-flex align-items-center gap-2" type="button" onClick={() => onContact(item.name)}>
        <i className="bi bi-send" aria-hidden="true" />
        {item.contact}
      </button>
    </article>
  );
}

function PharmacyDetail({ entity, onContact, onOrder, onBack }) {
  return (
    <section className="pharmacy-detail-card">
      <div className="pharmacy-detail-top">
        <div>
          <span className="badge rounded-pill text-bg-primary-subtle text-primary-emphasis mb-2">
            Structure
          </span>
          <h2>{entity.name}</h2>
          <p>{entity.address}</p>
        </div>
        <button className="secondary-action" type="button" onClick={onBack}>
          Retour accueil
        </button>
      </div>

      <div className="pharmacy-meta-grid">
        <article>
          <strong>Telephone</strong>
          <span>{entity.phone}</span>
        </article>
        <article>
          <strong>Horaires</strong>
          <span>{entity.hours}</span>
        </article>
        <article>
          <strong>Etat</strong>
          <span>{entity.availability}</span>
        </article>
      </div>

      <div className="pharmacy-services">
        {entity.services.map((service) => (
          <span key={service} className="badge rounded-pill text-bg-light text-primary-emphasis">
            {service}
          </span>
        ))}
      </div>

      <div className="detail-actions">
        <button className="primary-action" type="button" onClick={onOrder}>
          Commander ici
        </button>
        <button className="contact-button" type="button" onClick={onContact}>
          Contacter la structure
        </button>
      </div>
    </section>
  );
}

function CheckoutView({ product, entity, quantity, onQuantityChange, onConfirm, onBack }) {
  return (
    <div className="checkout-view">
      <section className="checkout-card">
        <div className="checkout-head">
          <div>
            <span className="badge rounded-pill text-bg-primary-subtle text-primary-emphasis mb-2">
              Commande
            </span>
            <h2>{product?.name || "Produit selectionne"}</h2>
            <p>{entity?.name || "Structure a confirmer"}</p>
          </div>
          <button className="secondary-action" type="button" onClick={onBack}>
            Modifier
          </button>
        </div>

        <div className="checkout-grid">
          <article>
            <strong>Prix unitaire</strong>
            <span>{product?.price || "Prix a confirmer"}</span>
          </article>
          <article>
            <strong>Quantite</strong>
            <div className="quantity-control">
              <button
                type="button"
                onClick={() => onQuantityChange(Math.max(1, quantity - 1))}
              >
                -
              </button>
              <span>{quantity}</span>
              <button type="button" onClick={() => onQuantityChange(quantity + 1)}>
                +
              </button>
            </div>
          </article>
          <article>
            <strong>Retrait / contact</strong>
            <span>{entity?.phone || "Telephone a confirmer"}</span>
          </article>
        </div>

        <div className="checkout-note">
          Validez cette demande pour preparer un contact, une reservation ou un parcours de vente
          plus complet.
        </div>

        <div className="detail-actions">
          <button className="primary-action" type="button" onClick={onConfirm}>
            Valider la demande
          </button>
          <button className="secondary-action" type="button" onClick={onBack}>
            Retour
          </button>
        </div>
      </section>
    </div>
  );
}

function DiscussionsEmpty({ context }) {
  return (
    <section className="discussions-empty">
      <img src="/illustration-experts.svg" alt="Discussions" />
      <span className="badge rounded-pill text-bg-light text-primary-emphasis px-3 py-2">
        Discussions
      </span>
      <p>{context || "Aucune discussion pour le moment."}</p>
    </section>
  );
}

function BottomNav({ view, onHome, onDiscussions, onSearch }) {
  return (
    <nav className="bottom-nav">
      <button
        className={`bottom-icon ${view === "discussions" ? "is-active" : ""}`}
        type="button"
        onClick={onDiscussions}
      >
        <Icon name="chat" />
      </button>

      <button className="home-fab" type="button" onClick={onHome}>
        <Icon name="home" />
      </button>

      <button className="bottom-icon" type="button" onClick={onSearch}>
        <Icon name="search" />
      </button>
    </nav>
  );
}

export default function App() {
  const [view, setView] = useState("home");
  const [search, setSearch] = useState("");
  const deferredSearch = useDeferredValue(normalizeText(search));
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const [health, setHealth] = useState({ loading: true, ok: false });
  const [datasets, setDatasets] = useState({
    articles: [],
    entites: [],
    professionnels: [],
  });
  const [selectedProductId, setSelectedProductId] = useState("");
  const [selectedEntityId, setSelectedEntityId] = useState("");
  const [orderQuantity, setOrderQuantity] = useState(1);
  const [discussionContext, setDiscussionContext] = useState("");
  const searchInputRef = useRef(null);
  const contentRef = useRef(null);

  useEffect(() => {
    let active = true;

    async function loadData() {
      try {
        const [healthResponse, articlesResponse, entitesResponse, expertsResponse] =
          await Promise.all([
            fetch(`${API_BASE_URL}/health`),
            fetch(`${API_BASE_URL}/api/articles?take=8`),
            fetch(`${API_BASE_URL}/api/entites?take=8`),
            fetch(`${API_BASE_URL}/api/models/T_Professionnel?take=8`),
          ]);

        const [articlesData, entitesData, expertsData] = await Promise.all([
          articlesResponse.json(),
          entitesResponse.json(),
          expertsResponse.json(),
        ]);

        if (!active) {
          return;
        }

        setHealth({ loading: false, ok: healthResponse.ok });
        setDatasets({
          articles: Array.isArray(articlesData?.data) ? articlesData.data : [],
          entites: Array.isArray(entitesData?.data) ? entitesData.data : [],
          professionnels: Array.isArray(expertsData?.data) ? expertsData.data : [],
        });
      } catch {
        if (!active) {
          return;
        }

        setHealth({ loading: false, ok: false });
        setDatasets({
          articles: [],
          entites: [],
          professionnels: [],
        });
      }
    }

    loadData();

    return () => {
      active = false;
    };
  }, []);

  const catalogueProducts = datasets.articles.length
    ? datasets.articles.map(productFromArticle)
    : sampleProducts;

  const catalogueEntities = datasets.entites.length
    ? datasets.entites.map(entityFromRecord)
    : sampleEntities;

  const catalogueExperts = datasets.professionnels.length
    ? datasets.professionnels.map(expertFromRecord)
    : sampleExperts;

  useEffect(() => {
    if (!selectedProductId && catalogueProducts[0]) {
      setSelectedProductId(catalogueProducts[0].id);
    }
  }, [catalogueProducts, selectedProductId]);

  useEffect(() => {
    if (!selectedEntityId && catalogueEntities[0]) {
      setSelectedEntityId(catalogueEntities[0].id);
    }
  }, [catalogueEntities, selectedEntityId]);

  useEffect(() => {
    if (!isSearchOpen) {
      return;
    }

    const timer = window.setTimeout(() => {
      searchInputRef.current?.focus();
    }, 40);

    return () => window.clearTimeout(timer);
  }, [isSearchOpen]);

  useEffect(() => {
    contentRef.current?.scrollTo({ top: 0, behavior: "smooth" });
  }, [view, selectedProductId]);

  const activeProduct =
    catalogueProducts.find((item) => item.id === selectedProductId) || catalogueProducts[0];
  const activeEntity =
    catalogueEntities.find((item) => item.id === selectedEntityId) || catalogueEntities[0];

  const searchResults =
    deferredSearch.length < 2
      ? { products: [], entities: [], experts: [] }
      : {
          products: catalogueProducts
            .filter((item) => matchesSearch(item, deferredSearch))
            .slice(0, 5)
            .map((item) => ({
              id: `product-${item.id}`,
              type: "product",
              title: item.name,
              subtitle: item.price,
              payload: item,
            })),
          entities: catalogueEntities
            .filter((item) => matchesSearch(item, deferredSearch))
            .slice(0, 5)
            .map((item) => ({
              id: `entity-${item.id}`,
              type: "entity",
              title: item.name,
              subtitle: item.address,
              payload: item,
            })),
          experts: catalogueExperts
            .filter((item) => matchesSearch(item, deferredSearch))
            .slice(0, 5)
            .map((item) => ({
              id: `expert-${item.id}`,
              type: "expert",
              title: item.name,
              subtitle: item.specialty,
              payload: item,
            })),
        };

  function closeOverlays() {
    setIsSidebarOpen(false);
    setIsSearchOpen(false);
  }

  function openView(nextView) {
    closeOverlays();
    setView(nextView);
  }

  function openProduct(product) {
    setSelectedProductId(product.id);
    closeOverlays();
    setView("products");
  }

  function openEntity(entity) {
    setSelectedEntityId(entity.id);
    closeOverlays();
    setView("pharmacies");
  }

  function handleBack() {
    closeOverlays();
    if (view === "checkout") {
      setView("pharmacies");
      return;
    }

    setView("home");
  }

  function handleSearchChange(event) {
    const nextValue = event.target.value;
    startTransition(() => {
      setSearch(nextValue);
    });
  }

  function handleSearchSelect(result) {
    closeOverlays();

    if (result.type === "product") {
      openProduct(result.payload);
      return;
    }

    if (result.type === "expert") {
      setView("experts");
      return;
    }

    if (result.type === "entity") {
      openEntity(result.payload);
      return;
    }

    setView("home");
  }

  function handleBuyCurrentProduct() {
    if (!activeProduct || !activeEntity) {
      return;
    }

    setOrderQuantity(1);
    setView("checkout");
  }

  function handleContactExpert(targetName) {
    setDiscussionContext(
      targetName
        ? `Discussion ouverte avec ${targetName}. Vous pouvez preparer ici votre prise de contact.`
        : "Aucune discussion pour le moment."
    );
    setView("discussions");
  }

  return (
    <div className="app-shell">
      <div className="phone-shell">
        <div
          className={`screen-overlay ${isSidebarOpen || isSearchOpen ? "is-visible" : ""}`}
          onClick={closeOverlays}
        />

        <Sidebar
          isOpen={isSidebarOpen}
          onClose={() => setIsSidebarOpen(false)}
          onNavigate={openView}
        />

        <SearchOverlay
          isOpen={isSearchOpen}
          search={search}
          results={searchResults}
          onClose={() => setIsSearchOpen(false)}
          onChange={handleSearchChange}
          onSelect={handleSearchSelect}
          inputRef={searchInputRef}
        />

        <TopBar
          view={view}
          onMenu={() => setIsSidebarOpen(true)}
          onBack={handleBack}
          onSearch={() => setIsSearchOpen(true)}
          onNavigate={openView}
        />

        <main className="mobile-content" ref={contentRef}>
          {view === "home" ? (
            <div className="view-home" id="accueil">
              <DesktopOverview
                health={health}
                productsCount={catalogueProducts.length}
                entitiesCount={catalogueEntities.length}
                expertsCount={catalogueExperts.length}
                onSearch={() => setIsSearchOpen(true)}
                onProducts={() => openView("products")}
                onExperts={() => openView("experts")}
              />

              <section className="web-feature-grid">
                <WebFeatureCard
                  icon="bi-search-heart"
                  title="Recherche produit"
                  text="Lancez une recherche, ouvrez une fiche et préparez votre achat plus rapidement."
                  buttonLabel="Chercher maintenant"
                  onClick={() => openView("products")}
                />
                <WebFeatureCard
                  icon="bi-geo-alt"
                  title="Pharmacies et depots"
                  text="Retrouvez les structures disponibles et élargissez facilement votre zone de recherche."
                  buttonLabel="Voir les points proches"
                  onClick={() => openView("pharmacies")}
                  tone="soft"
                />
                <WebFeatureCard
                  icon="bi-person-lines-fill"
                  title="Contacter un expert"
                  text="Consultez les profils vérifiés et ouvrez un parcours de discussion adapté au besoin."
                  buttonLabel="Trouver un expert"
                  onClick={() => openView("experts")}
                  tone="soft"
                />
              </section>

              <section className="web-data-grid">
                <WebDataPanel
                  title="Structures actives"
                  icon="bi-hospital"
                  actionLabel="Voir tout"
                  onAction={() => openView("pharmacies")}
                >
                  {catalogueEntities.slice(0, 3).map((item) => (
                    <button className="web-list-row" type="button" key={item.id} onClick={() => openEntity(item)}>
                      <div>
                        <strong>{item.name}</strong>
                        <p>{item.address}</p>
                      </div>
                      <span>{item.phone}</span>
                    </button>
                  ))}
                </WebDataPanel>

                <WebDataPanel
                  title="Experts disponibles"
                  icon="bi-people"
                  actionLabel="Consulter"
                  onAction={() => openView("experts")}
                >
                  {catalogueExperts.slice(0, 3).map((item) => (
                    <button className="web-list-row" type="button" key={item.id} onClick={() => openView("experts")}>
                      <div>
                        <strong>{item.name}</strong>
                        <p>{item.specialty}</p>
                      </div>
                      <span>{item.availability}</span>
                    </button>
                  ))}
                </WebDataPanel>
              </section>

              <VerificationCard health={health} />

              <section className="announcement-section">
                <div className="announcement-title">
                  <h2>DERNIERES ANNONCES</h2>
                </div>
                <AnnouncementSlider items={catalogueProducts.slice(0, 6)} onSelect={openProduct} />
              </section>

              <PromoCard
                tone="product"
                title="Trouvez et procurez-vous en un temps record des produits pharmaceutiques"
                buttonLabel="RECHERCHER UN PRODUIT"
                onClick={() => openView("products")}
                image="/illustration-produits.svg"
              />

              <PromoCard
                tone="expert"
                title="Echangez avec divers experts de nombreuses maladies"
                buttonLabel="TROUVER UN EXPERT"
                onClick={() => openView("experts")}
                image="/illustration-experts.svg"
              />

              <section className="nearby-section" id="pharmacies">
                <div className="location-badge">
                  <Icon name="pin" />
                </div>
                <p className="nearby-copy">
                  Suivant votre position, nous avons repertorie les pharmacies et depots suivants
                </p>
                <div className="nearby-list-card">
                  {catalogueEntities.slice(0, 4).map((item) => (
                    <NearbyRow key={item.id} item={item} onSelect={openEntity} />
                  ))}
                </div>
                <button className="expand-button" type="button" onClick={() => openView("pharmacies")}>
                  ELARGIR LA ZONE
                </button>
              </section>
            </div>
          ) : null}

          {view === "products" ? (
            <div className="view-products" id="produits">
              <section className="product-focus-card">
                <div className="product-focus-image">
                  <img src="/illustration-produits.svg" alt={activeProduct?.name || "Produit"} />
                </div>
                <div className="product-focus-meta">
                  <strong>{activeProduct?.name}</strong>
                  <span>{activeProduct?.price}</span>
                  <small>{activeProduct?.stock}</small>
                </div>
              </section>

              <div className="product-mini-track">
                {catalogueProducts.slice(0, 5).map((item) => (
                  <ProductMiniCard
                    key={item.id}
                    item={item}
                    isActive={activeProduct?.id === item.id}
                    onSelect={setSelectedProductId}
                  />
                ))}
              </div>

              <DetailBlock title="Infos" text={activeProduct?.info} />
              <DetailBlock title="Posologie" text={activeProduct?.posologie} />
              <DetailBlock title="Indications" text={activeProduct?.indications} />
              <DetailBlock title="Contre indications" text={activeProduct?.contre} />

              <div className="detail-actions">
                <button className="primary-action" type="button" onClick={handleBuyCurrentProduct}>
                  COMMANDER
                </button>
                <button className="secondary-action" type="button" onClick={() => openView("pharmacies")}>
                  VOIR LES PHARMACIES
                </button>
              </div>
            </div>
          ) : null}

          {view === "pharmacies" ? (
            <div className="view-pharmacies" id="pharmacies-detail">
              <PharmacyDetail
                entity={activeEntity}
                onContact={() => handleContactExpert(activeEntity?.name)}
                onOrder={() => setView("checkout")}
                onBack={() => openView("home")}
              />

              <section className="pharmacies-list">
                {catalogueEntities.map((item) => (
                  <NearbyRow key={item.id} item={item} onSelect={openEntity} />
                ))}
              </section>
            </div>
          ) : null}

          {view === "experts" ? (
            <div className="view-experts" id="experts">
              <PromoCard
                tone="expert"
                title="Echangez avec des experts disponibles pour vous orienter rapidement"
                buttonLabel="LANCER UNE DISCUSSION"
                onClick={() => openView("discussions")}
                image="/illustration-experts.svg"
              />

              <section className="experts-list">
                {catalogueExperts.map((item) => (
                  <ExpertCard key={item.id} item={item} onContact={handleContactExpert} />
                ))}
              </section>
            </div>
          ) : null}

          {view === "checkout" ? (
            <CheckoutView
              product={activeProduct}
              entity={activeEntity}
              quantity={orderQuantity}
              onQuantityChange={setOrderQuantity}
              onBack={() => setView("products")}
              onConfirm={() =>
                handleContactExpert(
                  `${activeEntity?.name || "la structure"} pour ${activeProduct?.name || "le produit"}`
                )
              }
            />
          ) : null}

          {view === "discussions" ? (
            <div className="view-discussions" id="discussions">
              <DiscussionsEmpty context={discussionContext} />
            </div>
          ) : null}
        </main>

        <BottomNav
          view={view}
          onHome={() => openView("home")}
          onDiscussions={() => openView("discussions")}
          onSearch={() => setIsSearchOpen(true)}
        />
      </div>
    </div>
  );
}
