const {
  createError,
  parsePositiveInt,
  validateCreatePayload,
  validateListQuery,
  validateSearchQuery,
  validateUpdatePayload,
} = require('./categorie-generique.validation');
const {
  toCreatePayload,
  toUpdatePayload,
} = require('./categorie-generique.mapper');

class CategorieGeneriqueService {
  constructor(repository) {
    this.repository = repository;
  }

  async listCategoriesGeneriques(query = {}) {
    const filters = validateListQuery(query);
    return this.repository.findMany(filters);
  }

  async searchCategoriesGeneriques(query = {}) {
    const filters = validateSearchQuery(query);
    return this.repository.findMany({
      ...filters,
      searchTerm: filters.q,
    });
  }

  async getCategorieGeneriqueById(id) {
    const categoryId = parsePositiveInt(id, 'id');
    const categorie = await this.repository.findById(categoryId);

    if (!categorie) {
      throw createError('Categorie generique introuvable.', 404, 'NOT_FOUND');
    }

    return categorie;
  }

  async createCategorieGenerique(payload) {
    validateCreatePayload(payload);
    return this.repository.create(toCreatePayload(payload));
  }

  async updateCategorieGenerique(id, payload) {
    const categoryId = parsePositiveInt(id, 'id');
    validateUpdatePayload(payload);

    const existing = await this.repository.findById(categoryId);

    if (!existing) {
      throw createError('Categorie generique introuvable.', 404, 'NOT_FOUND');
    }

    return this.repository.update(categoryId, toUpdatePayload(payload));
  }

  async deleteCategorieGenerique(id) {
    const categoryId = parsePositiveInt(id, 'id');
    const existing = await this.repository.findById(categoryId);

    if (!existing) {
      throw createError('Categorie generique introuvable.', 404, 'NOT_FOUND');
    }

    return this.repository.softDelete(categoryId);
  }
}

module.exports = {
  CategorieGeneriqueService,
};
