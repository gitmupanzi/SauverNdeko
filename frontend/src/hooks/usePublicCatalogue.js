import { useEffect, useState } from "react";
import {
  fetchPublicArticles,
  fetchPublicExperts,
  fetchPublicMaladies,
  fetchPublicPharmacies,
  fetchPublicStats,
} from "../services/api";
import {
  getCollection,
  mapArticlePublic,
  mapDiseasePublic,
  mapExpertPublic,
  mapPharmacyPublic,
  mapStatsPublic,
} from "../services/mappers";
import {
  mockArticles,
  mockDiseases,
  mockExperts,
  mockPharmacies,
  mockStats,
} from "../data/mockData";

export function usePublicCatalogue() {
  const [health, setHealth] = useState({ loading: true, ok: false, source: "mock" });
  const [catalogue, setCatalogue] = useState({
    articles: mockArticles,
    pharmacies: mockPharmacies,
    experts: mockExperts,
    diseases: mockDiseases,
    stats: mockStats,
  });

  useEffect(() => {
    let active = true;

    async function loadData() {
      const [statsResult, articlesResult, pharmaciesResult, expertsResult, diseasesResult] =
        await Promise.allSettled([
          fetchPublicStats(),
          fetchPublicArticles(),
          fetchPublicPharmacies(),
          fetchPublicExperts(),
          fetchPublicMaladies(),
        ]);

      if (!active) {
        return;
      }

      const articlesPayload = articlesResult.status === "fulfilled" ? articlesResult.value : null;
      const pharmaciesPayload = pharmaciesResult.status === "fulfilled" ? pharmaciesResult.value : null;
      const expertsPayload = expertsResult.status === "fulfilled" ? expertsResult.value : null;
      const diseasesPayload = diseasesResult.status === "fulfilled" ? diseasesResult.value : null;
      const statsPayload = statsResult.status === "fulfilled" ? statsResult.value : null;

      const articles = getCollection(articlesPayload).map(mapArticlePublic);
      const pharmacies = getCollection(pharmaciesPayload).map(mapPharmacyPublic);
      const experts = getCollection(expertsPayload).map(mapExpertPublic);
      const diseases = getCollection(diseasesPayload).map(mapDiseasePublic);

      const usingArticles = articles.length ? articles : mockArticles;
      const usingPharmacies = pharmacies.length ? pharmacies : mockPharmacies;
      const usingExperts = experts.length ? experts : mockExperts;
      const usingDiseases = diseases.length ? diseases : mockDiseases;
      const usingStats = mapStatsPublic(
        statsPayload,
        mockStats,
        usingArticles,
        usingPharmacies,
        usingExperts,
        usingDiseases
      );

      const liveEndpointAvailable =
        Boolean(statsPayload) ||
        articles.length > 0 ||
        pharmacies.length > 0 ||
        experts.length > 0 ||
        diseases.length > 0;

      setHealth({
        loading: false,
        ok: liveEndpointAvailable,
        source: liveEndpointAvailable ? "api" : "mock",
      });

      setCatalogue({
        articles: usingArticles,
        pharmacies: usingPharmacies,
        experts: usingExperts,
        diseases: usingDiseases,
        stats: usingStats,
      });
    }

    loadData();

    return () => {
      active = false;
    };
  }, []);

  return { health, catalogue };
}
