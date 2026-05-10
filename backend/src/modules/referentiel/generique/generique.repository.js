class GeneriqueRepository {
  constructor(prisma) {
    this.prisma = prisma;
    this.delegate = prisma.t_Generique;
    this.categorieDelegate = prisma.t_CategorieGenerique;
  }

  buildWhereClause({ searchTerm, includeInactive, categorieId }) {
    const where = {};

    if (!includeInactive) {
      where.ValideGenerique = true;
    }

    if (categorieId) {
      where.ID_CategorieGeneriqueFk = categorieId;
    }

    if (searchTerm) {
      where.AND = [
        ...(where.AND || []),
        {
          OR: [
            {
              NomGenerique: {
                contains: searchTerm,
                mode: 'insensitive',
              },
            },
            {
              AbrGenerique: {
                contains: searchTerm,
                mode: 'insensitive',
              },
            },
            {
              ObsGenerique: {
                contains: searchTerm,
                mode: 'insensitive',
              },
            },
          ],
        },
      ];
    }

    return where;
  }

  findMany(filters = {}) {
    return this.delegate.findMany({
      where: this.buildWhereClause(filters),
      skip: filters.skip,
      take: filters.take,
      orderBy: { ID_Generique: 'asc' },
    });
  }

  findById(id) {
    return this.delegate.findUnique({
      where: { ID_Generique: id },
    });
  }

  create(data) {
    return this.delegate.create({ data });
  }

  update(id, data) {
    return this.delegate.update({
      where: { ID_Generique: id },
      data,
    });
  }

  softDelete(id) {
    return this.delegate.update({
      where: { ID_Generique: id },
      data: { ValideGenerique: false },
    });
  }

  findCategorieById(id) {
    return this.categorieDelegate.findUnique({
      where: { ID_CategorieGenerique: id },
    });
  }
}

module.exports = {
  GeneriqueRepository,
};
