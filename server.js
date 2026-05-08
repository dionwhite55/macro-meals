require('dotenv').config();
const express = require('express');
const path = require('path');

const app = express();
app.use(express.json());

// Block sensitive files from being served as static assets
app.use((req, res, next) => {
    const blocked = ['.env', 'server.js', 'package.json', 'package-lock.json'];
    if (blocked.some(f => req.path === '/' + f)) {
        return res.status(404).end();
    }
    next();
});

app.use(express.static(path.join(__dirname)));

app.post('/api/chat', async (req, res) => {
    const apiKey = process.env.ANTHROPIC_API_KEY;
    if (!apiKey) {
        return res.status(500).json({ error: 'ANTHROPIC_API_KEY not set in .env' });
    }

    try {
        const response = await fetch('https://api.anthropic.com/v1/messages', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-api-key': apiKey,
                'anthropic-version': '2023-06-01'
            },
            body: JSON.stringify(req.body)
        });

        const data = await response.json();
        res.status(response.status).json(data);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Macro Meals running at http://localhost:${PORT}`));
