// Datadog tracing/APM bootstrap. Must be the FIRST require in the app so it can
// instrument Node.js modules (http, express, etc.) before they load.
//
// It only *starts* if DD_API_KEY / a tracer is configured; otherwise it is a
// no-op so the app still runs on environments without Datadog.
if (process.env.DD_API_KEY || process.env.DD_AGENT_HOST || process.env.DD_TRACE_ENABLED === "true") {
  try {
    require("dd-trace").init({
      env: process.env.DD_ENV || process.env.NODE_ENV || "dev",
      service: process.env.DD_SERVICE || "sample-app",
      version: process.env.APP_VERSION || "1.0.0",
      logInjection: process.env.DD_LOGS_INJECTION === "true",
      startupLogs: true,
    });
  } catch (err) {
    // If dd-trace is not installed or fails to init, continue without tracing.
    /* eslint-disable no-console */
    console.warn("dd-trace not initialised:", err && err.message);
  }
}

module.exports = true;
