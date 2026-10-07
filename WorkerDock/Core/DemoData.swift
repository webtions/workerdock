import Foundation

/// Invented projects used for marketing screenshots (env WORKERDOCK_DEMO=1). Nothing here touches the disk or real projects.
enum DemoData {
    struct Entry {
        var name: String
        var folder: String
        var status: ProjectStatus
        var port: Int?
        var mode: RunModeKind = .wrangler
        var framework: String?
        var cms: String?
        var pages: String?
        var entry: String?
        var wrangler = "4.147.0"
        var bindings: [WorkerBinding] = []
        var vars: [String] = []
        var memoryMB: Double = 0
        var config = "wrangler.jsonc"
        var date = "2026-07-11"
        var pm: PackageManager = .pnpm
    }

    static func b(_ kind: BindingKind, _ name: String, _ detail: String? = nil) -> WorkerBinding {
        WorkerBinding(kind: kind, name: name, detail: detail)
    }

    static let entries: [Entry] = [
        Entry(name: "aurora-api", folder: "~/Sites/aurora/api", status: .running, port: 8787, entry: "src/index.ts",
              bindings: [b(.d1, "DB", "aurora-prod"), b(.kv, "CACHE"), b(.r2, "UPLOADS", "aurora-uploads"),
                         b(.queue, "JOBS", "email-jobs"), b(.workflow, "ONBOARDING", "user-onboarding"), b(.service, "AUTH", "ember-auth")],
              vars: ["API_URL", "LOG_LEVEL", "FEATURE_FLAGS"], memoryMB: 184.6),
        Entry(name: "nimbus-journal", folder: "~/Sites/nimbus", status: .running, port: 4321, mode: .devScript, framework: "Astro", cms: "EmDash",
              entry: "./src/worker.ts", bindings: [b(.d1, "DB", "nimbus-journal"), b(.kv, "SESSION"), b(.r2, "MEDIA", "nimbus-media")],
              vars: ["SITE_URL"], memoryMB: 241.3),
        Entry(name: "lumen-checkout", folder: "~/Sites/lumen/checkout", status: .running, port: 8788, entry: "src/worker.ts",
              bindings: [b(.d1, "ORDERS_DB", "lumen-orders"), b(.durableObject, "CART", "Cart"), b(.queue, "ORDERS", "order-events"),
                         b(.service, "PAYMENTS", "ledgerly-payments"), b(.hyperdrive, "PG")],
              vars: ["CURRENCY", "STRIPE_MODE"], memoryMB: 156.9),
        Entry(name: "quartz-search", folder: "~/Sites/quartz", status: .running, port: 8789, entry: "src/search.ts",
              bindings: [b(.vectorize, "INDEX", "docs-embeddings"), b(.ai, "AI"), b(.kv, "SYNONYMS")], vars: ["MODEL"], memoryMB: 133.2),
        Entry(name: "pixel-forge", folder: "~/Sites/pixel-forge", status: .stopped, mode: .devScript, framework: "Astro", pages: "dist",
              bindings: [b(.r2, "RENDERS", "pixel-renders"), b(.kv, "PRESETS")], vars: ["MAX_UPLOAD_MB"], config: "wrangler.toml"),
        Entry(name: "tidepool-analytics", folder: "~/Sites/tidepool", status: .stopped, entry: "src/ingest.ts",
              bindings: [b(.analytics, "EVENTS", "tidepool_events"), b(.d1, "REPORTS", "tidepool-reports"), b(.queue, "INGEST", "raw-events")]),
        Entry(name: "ember-auth", folder: "~/Sites/ember/auth", status: .stopped, entry: "src/auth.ts",
              bindings: [b(.kv, "SESSIONS"), b(.durableObject, "RATE_LIMITER", "RateLimiter"), b(.d1, "USERS", "ember-users")], vars: ["JWT_ISSUER"]),
        Entry(name: "orbit-queue", folder: "~/Sites/orbit", status: .error("Exited with code 1"), entry: "src/consumer.ts",
              bindings: [b(.queue, "orders", "consumer"), b(.r2, "ARCHIVE", "orbit-archive")]),
        Entry(name: "meridian-docs", folder: "~/Sites/meridian-docs", status: .stopped, mode: .devScript, framework: "Astro", pages: "dist",
              bindings: [b(.assets, "assets", "./dist")], config: "wrangler.toml"),
        Entry(name: "halcyon-gateway", folder: "~/Sites/halcyon", status: .stopped, mode: .vite, entry: "src/gateway.ts",
              bindings: [b(.ai, "AI"), b(.browser, "BROWSER"), b(.kv, "RULES")], vars: ["UPSTREAM"]),
    ]

    static let aLogs = [
        "▶ pnpm exec wrangler dev --port 8787 --inspector-port 9230",
        "⛅️ wrangler 4.147.0",
        "Your Worker has access to the following bindings:",
        "env.DB (aurora-prod)                       D1 Database          local",
        "env.CACHE                                  KV Namespace         local",
        "env.UPLOADS (aurora-uploads)               R2 Bucket            local",
        "env.JOBS (email-jobs)                      Queue                local",
        "env.ONBOARDING (user-onboarding)           Workflow             local",
        "[wrangler:info] Ready on http://localhost:8787",
        "[wrangler:info] GET /api/v1/projects 200 OK (14ms)",
        "[wrangler:info] GET /api/v1/projects/prj_9f2c 200 OK (9ms)",
        "[wrangler:info] POST /api/v1/uploads 201 Created (42ms)",
        "queue: email-jobs received batch of 3 messages",
        "[wrangler:info] GET /api/v1/me 200 OK (6ms)",
        "warn: KV CACHE read took 120ms (cold start)",
        "[wrangler:info] POST /api/v1/auth/session 200 OK (18ms)",
        "workflow: user-onboarding started instance onb_2d41",
        "[wrangler:info] GET /api/v1/projects?limit=20 200 OK (11ms)",
        "[wrangler:info] DELETE /api/v1/uploads/upl_71 204 No Content (21ms)",
        "[wrangler:info] GET /healthz 200 OK (2ms)",
    ]
}
