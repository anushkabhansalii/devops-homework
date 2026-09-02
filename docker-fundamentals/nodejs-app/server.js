const http = require("http");
const PORT = 3000;
http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/html" });
  res.end("<h1>Hello World from Node.js in Docker</h1>");
}).listen(PORT, () => console.log(`Node app running on port ${PORT}`));
