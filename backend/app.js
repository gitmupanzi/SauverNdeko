const express = require('express');
const cors = require('cors');
const routes = require('./routes/index.routes');
const domainRoutes = require('./routes/domain.routes');
const viewsRoutes = require('./routes/views.routes');
const authRoutes = require('./routes/auth.routes');
const publicRoutes = require('./routes/public.routes');
const discussionRoutes = require('./routes/discussion.routes');
const logistiqueRoutes = require('./routes/logistique.routes');
const registerModuleRoutes = require('./src/modules/register-module-routes');
const errorHandler = require('./middlewares/errorHandler');

const app = express();

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get('/health', (req, res) => {
  res.status(200).json({
    success: true,
    message: 'SauverNdeko backend is running.',
  });
});

app.use('/api/public', publicRoutes);
app.use('/api/discussions', discussionRoutes);
registerModuleRoutes(app);
app.use('/api/logistique', logistiqueRoutes);
app.use('/api', domainRoutes);
app.use('/api', routes);
app.use('/api/views', viewsRoutes);
app.use('/SauverNdeko', authRoutes);
app.use(errorHandler);

module.exports = app;
