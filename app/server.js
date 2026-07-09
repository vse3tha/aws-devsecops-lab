const express = require('express');
const { MongoClient } = require('mongodb');
const fs = require('fs');

const app = express();
const port = process.env.PORT || 3000;
const mongoUri = process.env.MONGO_URI;
const dbName = process.env.MONGO_DB || 'appdb';

if (!mongoUri) {
  console.error('MONGO_URI environment variable is required');
  process.exit(1);
}

app.use(express.urlencoded({ extended: true }));
app.use(express.json());

let todos;

async function connectMongo() {
  const client = new MongoClient(mongoUri, {
    serverSelectionTimeoutMS: 5000
  });
  await client.connect();
  const db = client.db(dbName);
  todos = db.collection('todos');
  await todos.createIndex({ createdAt: -1 });
  console.log(`Connected to MongoDB database ${dbName}`);
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

app.get('/healthz', async (_req, res) => {
  try {
    await todos.findOne({});
    res.status(200).json({ ok: true, database: 'reachable' });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

app.get('/debug/file', (_req, res) => {
  try {
    const content = fs.readFileSync('/app/wizexercise.txt', 'utf8');
    res.type('text/plain').send(content);
  } catch (err) {
    res.status(500).send(err.message);
  }
});

app.get('/api/todos', async (_req, res) => {
  const items = await todos.find({}).sort({ createdAt: -1 }).limit(50).toArray();
  res.json(items);
});

app.post('/todos', async (req, res) => {
  const text = (req.body.text || '').trim();
  if (text) {
    await todos.insertOne({ text, createdAt: new Date(), source: 'kubernetes-web-app' });
  }
  res.redirect('/');
});

app.get('/', async (_req, res) => {
  const items = await todos.find({}).sort({ createdAt: -1 }).limit(50).toArray();
  const list = items.map((item) => `<li>${escapeHtml(item.text)} <small>${item.createdAt?.toISOString?.() || ''}</small></li>`).join('\n');
  res.type('html').send(`<!doctype html>
<html>
<head>
  <title>Wiz AWS DevSecOps Todo Lab</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; max-width: 900px; }
    input { padding: 8px; width: 360px; }
    button { padding: 8px 12px; }
    code { background: #f5f5f5; padding: 2px 5px; }
  </style>
</head>
<body>
  <h1>Wiz AWS DevSecOps Todo Lab</h1>
  <p>This containerized app is running on EKS and persists todos into MongoDB on an EC2 virtual machine.</p>
  <form method="POST" action="/todos">
    <input name="text" placeholder="Add a todo item" />
    <button type="submit">Save to MongoDB</button>
  </form>
  <h2>Todos from MongoDB</h2>
  <ul>${list || '<li>No todos yet. Add one above.</li>'}</ul>
  <p>Validation endpoint: <code>/debug/file</code> returns the container file content.</p>
</body>
</html>`);
});

connectMongo()
  .then(() => app.listen(port, () => console.log(`App listening on ${port}`)))
  .catch((err) => {
    console.error('Startup failed:', err);
    process.exit(1);
  });
