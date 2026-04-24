import Carousel from "react-bootstrap/Carousel";
import HeroSection from "../components/HeroSection";
import StatsCards from "../components/StatsCards";

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
          ? "Les dernieres donnees publiques sont disponibles."
          : "Mode demonstration actif. Les donnees reelles s'afficheront automatiquement des que l'API publique sera disponible."}
      </p>
      <button className="verify-button d-inline-flex align-items-center gap-2" type="button">
        <i className="bi bi-arrow-repeat" aria-hidden="true" />
        Verifier
      </button>
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

function AnnouncementSlider({ items, onOpenProducts }) {
  const slides = [];
  for (let index = 0; index < items.length; index += 3) {
    slides.push(items.slice(index, index + 3));
  }

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
        <Carousel.Item key={`announcement-${index}`}>
          <div className="announcement-slide">
            {group.map((item) => (
              <button className="announcement-card" type="button" key={item.id} onClick={onOpenProducts}>
                <div className="announcement-thumb">
                  <img src={item.photo || "/illustration-produits.svg"} alt={item.name} />
                </div>
                <div className="announcement-copy">
                  <span className="badge rounded-pill text-bg-light text-primary-emphasis mb-2">Annonce</span>
                  <strong>{item.name}</strong>
                  <p>{item.observation}</p>
                </div>
              </button>
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
    <button className="nearby-row" type="button" onClick={onSelect}>
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

export default function Home({ health, stats, products, pharmacies, experts, onOpenSearch, onNavigate, onContact }) {
  return (
    <div className="view-home" id="accueil">
      <section className="desktop-overview">
        <HeroSection
          onOpenSearch={onOpenSearch}
          onProducts={() => onNavigate("/produits")}
          onExperts={() => onNavigate("/experts")}
        />
        <StatsCards stats={stats} health={health} />
      </section>

      <section className="web-feature-grid">
        <WebFeatureCard
          icon="bi-search-heart"
          title="Recherche produit"
          text="Lancez une recherche, ouvrez une fiche publique et preparez votre achat plus rapidement."
          buttonLabel="Chercher maintenant"
          onClick={() => onNavigate("/produits")}
        />
        <WebFeatureCard
          icon="bi-geo-alt"
          title="Pharmacies et depots"
          text="Retrouvez les structures disponibles et elargissez facilement votre zone de recherche."
          buttonLabel="Voir les points proches"
          onClick={() => onNavigate("/pharmacies")}
          tone="soft"
        />
        <WebFeatureCard
          icon="bi-person-lines-fill"
          title="Contacter un expert"
          text="Consultez les profils publics et ouvrez un parcours de discussion adapte au besoin."
          buttonLabel="Trouver un expert"
          onClick={() => onNavigate("/experts")}
          tone="soft"
        />
      </section>

      <section className="web-data-grid">
        <WebDataPanel title="Structures actives" icon="bi-hospital" actionLabel="Voir tout" onAction={() => onNavigate("/pharmacies")}>
          {pharmacies.slice(0, 3).map((item) => (
            <button
              className="web-list-row"
              type="button"
              key={item.id}
              onClick={() => onContact({ type: "structure", id: item.id, name: item.name })}
            >
              <div>
                <strong>{item.name}</strong>
                <p>{item.address}</p>
              </div>
              <span>{item.phone}</span>
            </button>
          ))}
        </WebDataPanel>

        <WebDataPanel title="Experts disponibles" icon="bi-people" actionLabel="Consulter" onAction={() => onNavigate("/experts")}>
          {experts.slice(0, 3).map((item) => (
            <button
              className="web-list-row"
              type="button"
              key={item.id}
              onClick={() => onContact({ type: "expert", id: item.id, name: item.fullName })}
            >
              <div>
                <strong>{item.fullName}</strong>
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
        <AnnouncementSlider items={products.slice(0, 6)} onOpenProducts={() => onNavigate("/produits")} />
      </section>

      <PromoCard
        tone="product"
        title="Trouvez et procurez-vous rapidement des produits pharmaceutiques"
        buttonLabel="RECHERCHER UN PRODUIT"
        onClick={() => onNavigate("/produits")}
        image="/illustration-produits.svg"
      />

      <PromoCard
        tone="expert"
        title="Echangez avec des experts sur differentes maladies et preoccupations de sante"
        buttonLabel="TROUVER UN EXPERT"
        onClick={() => onNavigate("/experts")}
        image="/illustration-experts.svg"
      />

      <section className="nearby-section" id="pharmacies">
        <div className="location-badge">
          <i className="bi bi-geo-alt" aria-hidden="true" />
        </div>
        <p className="nearby-copy">
          Selon votre position, nous avons repertorie les pharmacies et depots suivants.
        </p>
        <div className="nearby-list-card">
          {pharmacies.slice(0, 4).map((item) => (
            <NearbyRow key={item.id} item={item} onSelect={() => onNavigate("/pharmacies")} />
          ))}
        </div>
        <button className="expand-button" type="button" onClick={() => onNavigate("/pharmacies")}>
          ELARGIR LA ZONE
        </button>
      </section>
    </div>
  );
}
