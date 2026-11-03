import { useEffect, useRef } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import ThemePicker from "../components/ThemePicker";
import AppIcon from "../components/AppIcon";
import { loginPathFor } from "../services/authNavigation";
import "./PublicCatalogue.css";

const SERVICES = [
  { key: "produits", path: "/produits", icon: "box", image: "/illustration-produits.svg", imageWidth: 1074, imageHeight: 739, label: "Produits", title: "Consulter les produits référencés", text: "Parcourez le catalogue et consultez les informations des fiches disponibles.", action: "Consulter les produits", evolving: true },
  { key: "professionnels", path: "/experts", icon: "user", image: "/illustration-experts.svg", imageWidth: 1086.13, imageHeight: 782.67, label: "Professionnels", title: "Trouver des compétences", text: "Recherchez par domaine ou besoin, consultez un profil publié et prenez contact par messagerie.", action: "Trouver un professionnel" },
  { key: "structures", path: "/pharmacies", icon: "building", image: "/illustration-pharmacies.svg", imageWidth: 1046, imageHeight: 729.87, label: "Structures", title: "Repérer une structure", text: "Consultez les établissements référencés et les coordonnées qu’ils ont renseignées.", action: "Consulter les structures", evolving: true },
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
        <nav className="catalogue-nav" aria-label="Présentation de SauverNdeko"><a href="#services">La plateforme</a><a href="#entreprises">Pour les entreprises</a><a href="#demarche">Notre démarche</a></nav>
        <div className="catalogue-header-actions"><ThemePicker /><Link className="catalogue-button is-outline" to={isAuthenticated ? "/" : "/login"}><AppIcon name={isAuthenticated ? "apps" : "lock"} />{isAuthenticated ? "Mes applications" : "Se connecter"}</Link></div>
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
        <aside className="catalogue-journey" aria-label="Le parcours sur SauverNdeko">
          <div className="catalogue-journey-heading"><span className="catalogue-mark"><AppIcon name="apps" size={26} /></span><div><span className="catalogue-overline">Votre parcours</span><h2>Du besoin au contact</h2></div></div>
          <ol>
            <li><span className="catalogue-step-icon"><AppIcon name="search" size={22} /></span><div><h3>Rechercher</h3><p>Un produit, une compétence ou une structure.</p></div></li>
            <li><span className="catalogue-step-icon"><AppIcon name="document" size={22} /></span><div><h3>Consulter</h3><p>Les informations renseignées dans les fiches.</p></div></li>
            <li><span className="catalogue-step-icon"><AppIcon name="mail" size={22} /></span><div><h3>Échanger</h3><p>Présenter votre besoin dans une discussion privée.</p></div></li>
          </ol>
          <p className="catalogue-journey-note"><AppIcon name="globe" />D’abord la santé. Un socle conçu aussi pour l’immobilier et la construction.</p>
        </aside>
      </section>

      <section className="catalogue-services catalogue-container" id="services" aria-labelledby="catalogue-services-title">
        <div className="catalogue-section-heading"><div><span className="catalogue-overline">La plateforme</span><h2 id="catalogue-services-title">L’information utile, au même endroit.</h2></div><p>Choisissez votre point de départ.</p></div>
        <div className="catalogue-service-grid">{SERVICES.map(service => <article className="catalogue-service-card" key={service.key}>
          <div className="catalogue-service-top"><span className="catalogue-service-icon"><AppIcon name={service.icon} size={25} /></span><span className="catalogue-service-label">{service.label}</span>{service.evolving ? <span className="catalogue-status">En amélioration</span> : null}</div>
          <div className="catalogue-service-media" aria-hidden="true"><img src={service.image} alt="" width={service.imageWidth} height={service.imageHeight} loading="lazy" decoding="async" /></div>
          <h3>{service.title}</h3><p>{service.text}</p><Link className="catalogue-text-link" to={destination(service.path)}>{service.action}<AppIcon name="chevron-right" /></Link>
        </article>)}</div>
        <p className="catalogue-section-note">Les annuaires Produits et Structures sont en cours d’amélioration. Les informations disponibles dépendent des organisations participantes.</p>
      </section>

      <section className="catalogue-container" id="entreprises" aria-labelledby="catalogue-business-title">
        <div className="catalogue-business">
          <div className="catalogue-business-copy"><span className="catalogue-overline">Pour les entreprises</span><h2 id="catalogue-business-title">Gérer votre activité, avec des données reliées.</h2><p>Suivez les opérations de votre entreprise dans un espace dédié, selon les modules et les droits de votre compte.</p><Link className="catalogue-button is-primary" to={destination("/logistique")}>Accéder à la logistique<AppIcon name="chevron-right" /></Link></div>
          <div className="catalogue-business-features">
            <div><span><AppIcon name="box" size={21} /></span><h3>Stock et traçabilité</h3><p>Articles, lots, entrées, sorties et inventaires.</p></div>
            <div><span><AppIcon name="receipt" size={21} /></span><h3>Documents et règlements</h3><p>Bons, factures et paiements suivis par entreprise.</p></div>
            <div><span><AppIcon name="user" size={21} /></span><h3>Relations et patrimoine</h3><p>Clients, fournisseurs et immobilisations.</p></div>
            <div><span><AppIcon name="shield" size={21} /></span><h3>Accès maîtrisés</h3><p>Licences, rôles et historique des opérations.</p></div>
          </div>
        </div>
      </section>

      <section className="catalogue-research catalogue-container" id="demarche" aria-labelledby="catalogue-research-title">
        <span className="catalogue-research-icon"><AppIcon name="chart" size={27} /></span><div><span className="catalogue-overline">Notre démarche</span><h2 id="catalogue-research-title">Construire un outil utile, puis en mesurer les effets.</h2><p>SauverNdeko vise à faciliter l’accès aux produits et aux professionnels de santé en RDC. Le projet de recherche étudiera comment les demandes pourraient aider à anticiper les besoins logistiques. Les prévisions et les effets sur la santé restent à évaluer.</p></div>
      </section>

      <section className="catalogue-faq catalogue-container" aria-labelledby="catalogue-faq-title">
        <div className="catalogue-section-heading"><div><span className="catalogue-overline">Avant de commencer</span><h2 id="catalogue-faq-title">Quelques repères.</h2></div></div>
        <div className="catalogue-faq-list">
          <details><summary>Comment accéder aux services ?<AppIcon name="chevron-down" /></summary><p>Connectez-vous avec votre compte SauverNdeko. Les applications et leurs actions s’affichent selon votre licence et vos autorisations. Pour obtenir un accès, contactez l’administrateur de votre organisation.</p></details>
          <details><summary>Comment vérifier la disponibilité d’un produit ?<AppIcon name="chevron-down" /></summary><p>Les informations proviennent des organisations participantes et peuvent évoluer. Confirmez le prix et la disponibilité auprès de la structure avant de vous déplacer.</p></details>
          <details><summary>Que contient un profil professionnel ?<AppIcon name="chevron-down" /></summary><p>Une présentation, des compétences et des services déclarés par le gestionnaire du profil. Sa publication ne constitue pas une vérification des diplômes ni un diagnostic médical. La messagerie permet de présenter votre demande directement au professionnel.</p></details>
        </div>
      </section>
      <section className="catalogue-start catalogue-container" aria-labelledby="catalogue-start-title"><div><h2 id="catalogue-start-title">Votre espace SauverNdeko.</h2><p>Retrouvez les applications accessibles à votre compte.</p></div><Link className="catalogue-button is-primary" to={isAuthenticated ? "/" : "/login"}>{isAuthenticated ? "Ouvrir mes applications" : "Se connecter"}<AppIcon name="chevron-right" /></Link></section>
    </main>
    <footer className="catalogue-footer"><div className="catalogue-container"><Brand /><p>Une plateforme en développement, pensée pour la RDC.</p><a href="#catalogue-start">Retour en haut<AppIcon name="arrow-up" /></a></div></footer>
  </div>;
}
