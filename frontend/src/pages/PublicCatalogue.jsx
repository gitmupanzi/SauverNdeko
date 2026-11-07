import { useEffect, useRef } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import ThemePicker from "../components/ThemePicker";
import AppIcon from "../components/AppIcon";
import CatalogueMetrics from "../components/CatalogueMetrics";
import { loginPathFor } from "../services/authNavigation";
import "./PublicCatalogue.css";

const SERVICES = [
  { key: "produits", path: "/produits", icon: "box", image: "/illustration-produits.svg", imageWidth: 1074, imageHeight: 739, label: "Produits", title: "Trouvez un produit.", text: "Retrouvez les offres partagées et les informations de chaque produit.", action: "Consulter les produits" },
  { key: "professionnels", path: "/experts", icon: "user", image: "/illustration-experts.svg", imageWidth: 1086.13, imageHeight: 782.67, label: "Professionnels", title: "Trouvez un professionnel.", text: "Découvrez les profils, leurs domaines et les services proposés.", action: "Trouver un professionnel" },
  { key: "structures", path: "/pharmacies", icon: "building", image: "/illustration-pharmacies.svg", imageWidth: 1046, imageHeight: 729.87, label: "Structures", title: "Repérez une structure.", text: "Repérez un établissement et consultez ses informations pratiques.", action: "Consulter les structures" },
];

export function catalogueDestination(path, authenticated) {
  return authenticated ? path : loginPathFor({ pathname: path });
}

function Brand() {
  return <Link className="catalogue-brand" to="/catalogue" aria-label="SauverNdeko — présentation"><img src="/sauverndeko-logo.jpg" alt="" width="42" height="42" /><span>SauverNdeko</span></Link>;
}

export default function PublicCatalogue() {
  const { isAuthenticated } = useAuth();
  const pageRef = useRef(null), headerRef = useRef(null);
  const destination = path => catalogueDestination(path, isAuthenticated);
  useEffect(() => {
    const page = pageRef.current, header = headerRef.current;
    if (!page || !header) return;
    // Les ancres restent visibles même si l’en-tête revient à la ligne sur mobile.
    const measure = () => page.style.setProperty("--catalogue-header-height", `${Math.ceil(header.getBoundingClientRect().height)}px`);
    measure();
    const observer = typeof ResizeObserver === "undefined" ? null : new ResizeObserver(measure);
    observer?.observe(header);
    window.addEventListener("resize", measure);
    return () => { observer?.disconnect(); window.removeEventListener("resize", measure); };
  }, []);
  useEffect(() => {
    const previous = document.title;
    document.title = "SauverNdeko | Produits, professionnels et structures";
    return () => { document.title = previous; };
  }, []);
  return <div className="public-catalogue" id="catalogue-start" ref={pageRef}>
    <a className="catalogue-skip" href="#catalogue-main">Aller au contenu</a>
    <header className="catalogue-header" ref={headerRef}>
      <div className="catalogue-header-inner">
        <Brand />
        <nav className="catalogue-nav" aria-label="Présentation de SauverNdeko"><a href="#services">La plateforme</a><a href="#entreprises">Pour les entreprises</a><a href="#demarche">Notre vision</a></nav>
        <div className="catalogue-header-actions"><ThemePicker /><Link className="catalogue-button is-outline" to={isAuthenticated ? "/espace" : "/login"}><AppIcon name={isAuthenticated ? "apps" : "lock"} />{isAuthenticated ? "Mes applications" : "Se connecter"}</Link></div>
      </div>
    </header>

    <main id="catalogue-main" tabIndex={-1}>
      <section className="catalogue-hero catalogue-container" aria-labelledby="catalogue-title">
        <div className="catalogue-hero-copy">
          <span className="catalogue-eyebrow"><span aria-hidden="true" />Une plateforme congolaise</span>
          <h1 id="catalogue-title">Des produits.<br />Des compétences.<br /><span>Des liens de proximité.</span></h1>
          <p>Un point d’accès aux produits référencés, aux professionnels et aux structures, avec un espace de gestion pour les entreprises.</p>
          <div className="catalogue-hero-actions"><Link className="catalogue-button is-primary" to={destination("/produits")}><AppIcon name="search" />Consulter les produits</Link><Link className="catalogue-text-link" to={destination("/experts")}>Trouver un professionnel<AppIcon name="arrow-up-right" /></Link></div>
          <p className="catalogue-access-note"><AppIcon name="lock" />Les annuaires et les échanges sont accessibles après connexion.</p>
        </div>
        <CatalogueMetrics destination={destination} />
        <aside className="catalogue-journey" aria-label="Le parcours sur SauverNdeko">
          <div className="catalogue-journey-heading"><span className="catalogue-mark"><AppIcon name="apps" size={26} /></span><div><span className="catalogue-overline">Comment ça marche</span><h2>Trouvez ce dont vous avez besoin.</h2></div></div>
          <ol>
            <li><span className="catalogue-step-icon"><AppIcon name="search" size={22} /></span><div><h3>Trouvez</h3><p>Recherchez un produit, un professionnel ou une structure.</p></div></li>
            <li><span className="catalogue-step-icon"><AppIcon name="document" size={22} /></span><div><h3>Découvrez</h3><p>Consultez les fiches, les services et les coordonnées disponibles.</p></div></li>
            <li><span className="catalogue-step-icon"><AppIcon name="mail" size={22} /></span><div><h3>Échangez</h3><p>Présentez votre besoin dans une discussion privée.</p></div></li>
          </ol>
          <p className="catalogue-journey-note"><AppIcon name="globe" />La santé pour commencer, avec une ouverture à l’immobilier et à la construction.</p>
        </aside>
      </section>

      <section className="catalogue-services catalogue-container" id="services" aria-labelledby="catalogue-services-title">
        <div className="catalogue-section-heading"><div><span className="catalogue-overline">La plateforme</span><h2 id="catalogue-services-title">L’information utile, au même endroit.</h2></div><p>Choisissez votre point de départ.</p></div>
        <div className="catalogue-service-grid">{SERVICES.map(service => <article className="catalogue-service-card" key={service.key}>
          <div className="catalogue-service-top"><span className="catalogue-service-icon"><AppIcon name={service.icon} size={25} /></span><span className="catalogue-service-label">{service.label}</span></div>
          <div className="catalogue-service-media" aria-hidden="true"><img src={service.image} alt="" width={service.imageWidth} height={service.imageHeight} loading="lazy" decoding="async" /></div>
          <h3>{service.title}</h3><p>{service.text}</p><Link className="catalogue-text-link" to={destination(service.path)}>{service.action}<AppIcon name="chevron-right" /></Link>
        </article>)}</div>
        <p className="catalogue-section-note">Les informations publiées dépendent des organisations participantes.</p>
      </section>

      <section className="catalogue-container" id="entreprises" aria-labelledby="catalogue-business-title">
        <div className="catalogue-business">
          <div className="catalogue-business-copy"><span className="catalogue-overline">Pour les entreprises</span><h2 id="catalogue-business-title">Un espace pour piloter votre entreprise.</h2><p>Organisez vos stocks, suivez vos opérations et facilitez le travail de vos équipes. Retrouvez les modules utiles à votre activité dans un espace dédié, avec des accès adaptés à chaque collaborateur.</p><Link className="catalogue-button is-primary" to={destination("/logistique")}>Accéder à la logistique<AppIcon name="chevron-right" /></Link></div>
          <div className="catalogue-business-features">
            <div><span><AppIcon name="box" size={21} /></span><h3>Stock et traçabilité</h3><p>Articles, lots, entrées, sorties et inventaires.</p></div>
            <div><span><AppIcon name="receipt" size={21} /></span><h3>Documents et règlements</h3><p>Bons, factures et paiements suivis par entreprise.</p></div>
            <div><span><AppIcon name="user" size={21} /></span><h3>Relations et patrimoine</h3><p>Clients, fournisseurs et immobilisations.</p></div>
            <div><span><AppIcon name="shield" size={21} /></span><h3>Accès maîtrisés</h3><p>Licences, rôles et historique des opérations.</p></div>
          </div>
        </div>
      </section>

      <div className="catalogue-more catalogue-container">
      <section className="catalogue-research" id="demarche" aria-labelledby="catalogue-research-title">
        <span className="catalogue-research-icon"><AppIcon name="globe" size={27} /></span><div><span className="catalogue-overline">Notre vision</span><h2 id="catalogue-research-title">Rapprocher les besoins des solutions.</h2><p>Notre vision est de rapprocher les personnes des produits, des compétences et des services dont elles ont besoin, partout en RDC. En commençant par la santé, nous construisons une plateforme ouverte à d’autres secteurs, pour faciliter les échanges et aider les organisations à mieux anticiper leurs besoins.</p></div>
      </section>

      <section className="catalogue-faq" aria-labelledby="catalogue-faq-title">
        <div className="catalogue-section-heading"><div><span className="catalogue-overline">Avant de commencer</span><h2 id="catalogue-faq-title">Quelques repères.</h2></div></div>
        <div className="catalogue-faq-list">
          <details><summary>Comment accéder aux services ?<AppIcon name="chevron-down" /></summary><p>Connectez-vous avec votre compte SauverNdeko. Les applications et leurs actions s’affichent selon votre licence et vos autorisations. Pour obtenir un accès, contactez l’administrateur de votre organisation.</p></details>
          <details><summary>Comment vérifier la disponibilité d’un produit ?<AppIcon name="chevron-down" /></summary><p>Les informations proviennent des organisations participantes et peuvent évoluer. Confirmez le prix et la disponibilité auprès de la structure avant de vous déplacer.</p></details>
          <details><summary>Que contient un profil professionnel ?<AppIcon name="chevron-down" /></summary><p>Une présentation, des compétences et des services déclarés par le gestionnaire du profil. Sa publication ne constitue pas une vérification des diplômes ni un diagnostic médical. La messagerie permet de présenter votre demande directement au professionnel.</p></details>
        </div>
      </section>
      </div>
    </main>
    <footer className="catalogue-footer"><div className="catalogue-container"><Brand /><p>Une plateforme en développement, pensée pour la RDC.</p><a href="#catalogue-start">Retour en haut<AppIcon name="arrow-up" /></a></div></footer>
  </div>;
}
