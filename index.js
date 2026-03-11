const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/health', (req, res) => res.send('OK'));

app.get('/', (req, res) => {
  res.json({ message: "Hello from Node.js app running on Kubernetes!" });
});

// Only start the server when run directly — not when required by tests
if (require.main === module) {
  app.listen(port, () => {
    console.log(`App listening on port ${port}`);
  });
}

module.exports = app;