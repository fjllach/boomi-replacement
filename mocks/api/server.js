const express = require('express');
const bodyParser = require('body-parser');
const app = express();
const port = 3000;

app.use(bodyParser.json());

app.post('/ingest', (req, res) => {
    console.log('External API Received Data:', JSON.stringify(req.body, null, 2));
    res.status(200).json({status: 'received', timestamp: new Date().toISOString()});
});

app.listen(port, () => {
    console.log(`Mock API listening at http://localhost:${port}`);
});
