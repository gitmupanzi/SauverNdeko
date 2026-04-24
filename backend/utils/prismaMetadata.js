const { Prisma } = require('../generated/prisma');

const toDelegateName = (modelName) => modelName.charAt(0).toLowerCase() + modelName.slice(1);

const getRawModels = () => Prisma.dmmf.datamodel.models;

const getModelInfo = (modelName) => {
  const model = getRawModels().find((item) => item.name.toLowerCase() === modelName.toLowerCase());

  if (!model) {
    const error = new Error(`Modèle "${modelName}" introuvable.`);
    error.statusCode = 404;
    throw error;
  }

  const idFields = model.fields.filter((field) => field.isId);

  if (idFields.length !== 1) {
    const error = new Error(`Le modèle "${model.name}" doit avoir une clé primaire simple pour utiliser ce CRUD.`);
    error.statusCode = 400;
    throw error;
  }

  return {
    name: model.name,
    schema: model.schema || model.dbSchema || 'public',
    delegate: toDelegateName(model.name),
    primaryKey: idFields[0].name,
    primaryKeyType: idFields[0].type,
  };
};

const listModels = () =>
  getRawModels()
    .filter((model) => model.fields.some((field) => field.isId))
    .map((model) => getModelInfo(model.name));

const resolveModelName = (value) => {
  const model = getRawModels().find((item) => item.name.toLowerCase() === value.toLowerCase());

  if (!model) {
    const error = new Error(`Modèle "${value}" introuvable.`);
    error.statusCode = 404;
    throw error;
  }

  return model.name;
};

const getDelegateByModelName = (prisma, modelName) => {
  const modelInfo = getModelInfo(modelName);
  const delegate = prisma[modelInfo.delegate];

  if (!delegate) {
    const error = new Error(`Delegate Prisma introuvable pour le modèle "${modelName}".`);
    error.statusCode = 500;
    throw error;
  }

  return delegate;
};

const coercePrimaryKeyValue = (modelInfo, rawValue) => {
  if (modelInfo.primaryKeyType === 'Int' || modelInfo.primaryKeyType === 'BigInt') {
    const parsed = Number(rawValue);

    if (Number.isNaN(parsed)) {
      const error = new Error(`L'identifiant "${rawValue}" est invalide pour le modèle "${modelInfo.name}".`);
      error.statusCode = 400;
      throw error;
    }

    return parsed;
  }

  return rawValue;
};

module.exports = {
  coercePrimaryKeyValue,
  getDelegateByModelName,
  getModelInfo,
  listModels,
  resolveModelName,
  toDelegateName,
};
