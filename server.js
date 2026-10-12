require('dotenv').config();
const express = require('express');
const path = require('path');

const app = express();
app.use(express.json({ limit: '10kb' }));

// Only the public/ folder is served; server code and config stay private.
app.use(express.static(path.join(__dirname, 'public')));

app.post('/api/chat', async (req, res) => {
    const { handleMacroRequest } = await import('./lib/macro-api.mjs');
    const result = await handleMacroRequest(req.body, process.env.ANTHROPIC_API_KEY);
    res.status(result.status).json(result.body);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Macro Meals running at http://localhost:${PORT}`));
