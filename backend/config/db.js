const path = require('path');

require('dotenv').config({
  path: path.join(__dirname, '..', '.env'),
});

const { PrismaClient } = require('../generated/prisma');

const globalForPrisma = globalThis;

const prisma =
  globalForPrisma.__sauverNdekoPrisma ||
  new PrismaClient({
    log: process.env.NODE_ENV === 'development' ? ['query', 'info', 'warn', 'error'] : ['error'],
  });

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.__sauverNdekoPrisma = prisma;
}

module.exports = prisma;
