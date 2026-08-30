const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || process.env.ADMIN_PORT || 4000;
const PUBLIC_DIR = __dirname;

const MIME_TYPES = {
  '.html': 'text/html; charset=UTF-8',
  '.js': 'application/javascript; charset=UTF-8',
  '.css': 'text/css; charset=UTF-8',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon'
};

const server = http.createServer((req, res) => {
  try {
    const rawPath = (req.url || '/').split('?')[0];
    const safeRelPath = path.normalize(rawPath).replace(/^(\.\.[\/\\])+/, '');
    let filePath = path.resolve(PUBLIC_DIR, safeRelPath === '/' || safeRelPath === '.' ? 'index.html' : safeRelPath.replace(/^\//, ''));

    // Prevent path traversal outside PUBLIC_DIR
    if (!filePath.startsWith(PUBLIC_DIR)) {
      filePath = path.join(PUBLIC_DIR, 'index.html');
    }

    try {
      if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
        filePath = path.join(PUBLIC_DIR, 'index.html');
      }
    } catch (_) {
      filePath = path.join(PUBLIC_DIR, 'index.html');
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
  } catch (err) {
    res.writeHead(500, { 'Content-Type': 'text/plain' });
    res.end('Server Internal Error');
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`===========================================`);
  console.log(`  LuckyWin Admin Dashboard Server Running!`);
  console.log(`  URL: http://localhost:${PORT}`);
  console.log(`  Default Login: admin / admin`);
  console.log(`  Backend Connected: http://localhost:5050/api`);
  console.log(`===========================================`);
});
