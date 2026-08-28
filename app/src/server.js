// Datadog tracer must be required before other modules to instrument them.
require("./tracer");

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
    // Datadog log injection (trace_id/span_id) is enabled when DD_LOGS_INJECTION=true.
  ],
});

const app = express();
const PORT = process.env.PORT || 8080;

// Optional Datadog StatsD client for custom metrics (request rate, latency, error rate).
// Falls back gracefully when the Datadog agent/dd-trace is not available.
function getStatsd() {
  try {
    const tracer = require("dd-trace");
    return tracer.dogstatsd();
  } catch (_) {
    return null;
  }
}
const statsd = getStatsd();
const tags = ["env:" + (process.env.DD_ENV || "dev"), "service:" + (process.env.DD_SERVICE || "sample-app")];

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
    error_count: global.__errorCount || 0,
    memory: process.memoryUsage(),
    cpu: process.cpuUsage(),
  });
});

// Per-request middleware: logs + emits Datadog metrics (request rate, latency, error rate).
app.use((req, res, next) => {
  const start = process.hrtime();
  res.on("finish", () => {
    global.__requestCount = (global.__requestCount || 0) + 1;
    if (res.statusCode >= 500) global.__errorCount = (global.__errorCount || 0) + 1;

    const diff = process.hrtime(start);
    const latencyMs = (diff[0] * 1e3 + diff[1] / 1e6).toFixed(2);

    logger.info("request", {
      method: req.method,
      path: req.path,
      status: res.statusCode,
      latency_ms: latencyMs,
    });

    // --- Datadog custom metrics ---
    if (statsd) {
      try {
        statsd.increment("http.request.count", 1, tags.concat(["method:" + req.method]));
        statsd.distribution("http.request.latency", parseFloat(latencyMs), tags);
        if (res.statusCode >= 500) {
          statsd.increment("http.request.errors", 1, tags.concat(["status:" + res.statusCode]));
        }
      } catch (_) {
        /* metric emission is best-effort */
      }
    }
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
