const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || process.env.FRONTEND_PORT || 3000;
const PUBLIC_DIR = path.join(__dirname, 'build', 'web');

const MIME_TYPES = {
  '.html': 'text/html; charset=UTF-8',
  '.js': 'application/javascript; charset=UTF-8',
  '.mjs': 'application/javascript; charset=UTF-8',
  '.css': 'text/css; charset=UTF-8',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.map': 'application/json'
};

const server = http.createServer((req, res) => {
  let cleanUrl = req.url.split('?')[0];
  let filePath = path.join(PUBLIC_DIR, cleanUrl === '/' ? 'index.html' : cleanUrl);

  // Fallback to index.html for SPA routing if file does not exist
  if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    const directIndexPath = path.join(filePath, 'index.html');
    if (fs.existsSync(directIndexPath)) {
      filePath = directIndexPath;
    } else {
      filePath = path.join(PUBLIC_DIR, 'index.html');
    }
  }

  const ext = path.extname(filePath).toLowerCase();
  const contentType = MIME_TYPES[ext] || 'application/octet-stream';

  fs.readFile(filePath, (err, content) => {
    if (err) {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('Server Error');
      return;
    }
    res.writeHead(200, { 'Content-Type': contentType });
    res.end(content);
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`===========================================`);
  console.log(`  LuckyWin Tournament Frontend Running!`);
  console.log(`  URL: http://localhost:${PORT}`);
  console.log(`  Backend Connected: http://localhost:5050/api`);
  console.log(`===========================================`);
});
