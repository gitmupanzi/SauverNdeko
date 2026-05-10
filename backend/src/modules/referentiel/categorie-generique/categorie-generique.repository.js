class CategorieGeneriqueRepository {
  constructor(prisma) {
    this.prisma = prisma;
    this.delegate = prisma.t_CategorieGenerique;
  }

  buildWhereClause({ searchTerm, includeInactive }) {
    const where = {};

    if (!includeInactive) {
      where.OR = [
        { ValideCategorieGenerique: true },
        { ValideCategorieGenerique: null },
      ];
    }

    if (searchTerm) {
      where.AND = [
        ...(where.AND || []),
        {
          OR: [
            {
              NomCategorieGenerique: {
                contains: searchTerm,
                mode: 'insensitive',
              },
            },
            {
              ModuleCategorieGenerique: {
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
    const where = this.buildWhereClause(filters);

    return this.delegate.findMany({
      where,
      skip: filters.skip,
      take: filters.take,
      orderBy: { ID_CategorieGenerique: 'asc' },
    });
  }

  findById(id) {
    return this.delegate.findUnique({
      where: { ID_CategorieGenerique: id },
    });
  }

  create(data) {
    return this.delegate.create({ data });
  }

  update(id, data) {
    return this.delegate.update({
      where: { ID_CategorieGenerique: id },
      data,
    });
  }

  softDelete(id) {
    return this.delegate.update({
      where: { ID_CategorieGenerique: id },
      data: { ValideCategorieGenerique: false },
    });
  }
}

module.exports = {
  CategorieGeneriqueRepository,
};
