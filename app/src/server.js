const express = require("express");
const { createLogger, transports, format } = require("winston");

const logger = createLogger({
  level: process.env.LOG_LEVEL || "info",
  format: format.combine(
    format.timestamp(),
    format.errors({ stack: true }),
    format.json()
  ),
  transports: [
    new transports.Console(),
    // Uncomment when running in AWS with CloudWatch Logs agent installed.
    // new transports.File({ filename: "/var/log/app/app.log" }),
  ],
});

const app = express();
const PORT = process.env.PORT || 8080;

app.use(express.json());

app.get("/", (req, res) => {
  logger.info("root endpoint hit");
  res.json({ status: "ok", message: "Welcome to the sample app", timestamp: new Date().toISOString() });
});

app.get("/health", (req, res) => {
  logger.info("health check");
  res.status(200).json({ status: "healthy", uptime: process.uptime() });
});

app.get("/metrics", (req, res) => {
  res.json({
    request_count: global.__requestCount || 0,
    memory: process.memoryUsage(),
    cpu: process.cpuUsage(),
  });
});

// Simple in-memory request counter with periodic CloudWatch-style metric.
app.use((req, res, next) => {
  const start = process.hrtime();
  res.on("finish", () => {
    global.__requestCount = (global.__requestCount || 0) + 1;
    const diff = process.hrtime(start);
    const latencyMs = (diff[0] * 1e3 + diff[1] / 1e6).toFixed(2);
    logger.info("request", {
      method: req.method,
      path: req.path,
      status: res.statusCode,
      latency_ms: latencyMs,
    });
  });
  next();
});

app.get("/error", (req, res) => {
  logger.error("sample error triggered");
  res.status(500).json({ error: "Intentional error for monitoring" });
});

if (require.main === module) {
  app.listen(PORT, "0.0.0.0", () => {
    logger.info(`app listening on port ${PORT}`);
  });
}

module.exports = app;
