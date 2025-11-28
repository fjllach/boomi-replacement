const express = require('express');
const app = express();
const port = 3000;

app.get('/services/data/v50.0/query', (req, res) => {
    console.log('Salesforce Query Received:', req.query.q);
    res.json({
        totalSize: 2,
        done: true,
        records: [
            {Id: '001', Name: 'Acme Corp', Type: 'Customer'},
            {Id: '002', Name: 'Global Supplies', Type: 'Partner'}
        ]
    });
});

app.listen(port, () => {
    console.log(`Mock Salesforce listening at http://localhost:${port}`);
});
