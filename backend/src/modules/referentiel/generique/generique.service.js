const {
  createError,
  parsePositiveInt,
  validateCreatePayload,
  validateListQuery,
  validateSearchQuery,
  validateUpdatePayload,
} = require('./generique.validation');
const {
  toCreatePayload,
  toUpdatePayload,
} = require('./generique.mapper');

class GeneriqueService {
  constructor(repository) {
    this.repository = repository;
  }

  async listGeneriques(query = {}) {
    const filters = validateListQuery(query);
    return this.repository.findMany(filters);
  }

  async searchGeneriques(query = {}) {
    const filters = validateSearchQuery(query);
    return this.repository.findMany({
      ...filters,
      searchTerm: filters.q,
    });
  }

  async listGeneriquesByCategorie(categorieId, query = {}) {
    const categoryId = parsePositiveInt(categorieId, 'categorieId');
    const filters = validateListQuery(query);
    return this.repository.findMany({
      ...filters,
      categorieId: categoryId,
    });
  }

  async getGeneriqueById(id) {
    const generiqueId = parsePositiveInt(id, 'id');
    const generique = await this.repository.findById(generiqueId);

    if (!generique) {
      throw createError('Generique introuvable.', 404, 'NOT_FOUND');
    }

    return generique;
  }

  async createGenerique(payload) {
    validateCreatePayload(payload);
    const data = toCreatePayload(payload);
    await this.ensureCategorieExists(data.ID_CategorieGeneriqueFk);
    return this.repository.create(data);
  }

  async updateGenerique(id, payload) {
    const generiqueId = parsePositiveInt(id, 'id');
    validateUpdatePayload(payload);

    const existing = await this.repository.findById(generiqueId);
    if (!existing) {
      throw createError('Generique introuvable.', 404, 'NOT_FOUND');
    }

    const data = toUpdatePayload(payload);

    if (Object.prototype.hasOwnProperty.call(data, 'ID_CategorieGeneriqueFk')) {
      await this.ensureCategorieExists(data.ID_CategorieGeneriqueFk);
    }

    return this.repository.update(generiqueId, data);
  }

  async deleteGenerique(id) {
    const generiqueId = parsePositiveInt(id, 'id');
    const existing = await this.repository.findById(generiqueId);

    if (!existing) {
      throw createError('Generique introuvable.', 404, 'NOT_FOUND');
    }

    return this.repository.softDelete(generiqueId);
  }

  async ensureCategorieExists(categorieId) {
    const categorie = await this.repository.findCategorieById(categorieId);

    if (!categorie || categorie.ValideCategorieGenerique === false) {
      throw createError('La categorie generique associee est introuvable ou inactive.', 409, 'CATEGORY_NOT_AVAILABLE', {
        ID_CategorieGeneriqueFk: categorieId,
      });
    }
  }
}

module.exports = {
  GeneriqueService,
};
