# Submission completion and installation guide

This guide is embedded in the consolidated PDF. Submit that one PDF for written work. Deployment, personal authorship and signing fields remain unverified until the team supplies evidence.

## Group declaration review

The one consolidated group declaration template appears in Part A, section 16. All four students must review it, confirm registered names and IDs, and sign with actual dates. Do not sign for another member or present the template as a completed declaration.

## Environment variables and startup

| Service | Names | Purpose |
|---|---|---|
| Local PostgreSQL scripts | POSTGRES_HOST, POSTGRES_PORT, POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD | Local database configuration; check .env.example |
| ASP.NET Core | ConnectionStrings__DefaultConnection | PostgreSQL connection secret |
| JWT | Jwt__Key, Jwt__Issuer, Jwt__Audience | Signing secret and token identity |
| Internal agents | AgentService__Url, AgentService__RequestUrl, AgentService__DeliveryUrl, AgentService__QualityUrl | Internal service origins corresponding to ports 8001–8004 |
| SMTP | Smtp__Host, Smtp__Port, Smtp__EnableSsl, Smtp__Username, Smtp__Password, Smtp__FromAddress, Smtp__FromName | Real provider configuration; an empty host does not deliver mail |
| Optional model providers | GEMINI_API_KEY, ANTHROPIC_API_KEY, ANTHROPIC_MODEL, ANTHROPIC_TIMEOUT_S | Provider configuration used by agent source |
| React build | VITE_API_BASE_URL | API origin ending in /api |
| Flutter build | API_BASE_URL via --dart-define | API origin embedded at build time |

Never include secret values in the report, screenshots, video or Git. Keep PostgreSQL and agents private; clients call the API. Configure deployed CORS against the actual React origin.

1. Install prerequisites from README and create a private .env from .env.example. Configure PostgreSQL and JWT using environment variables or dotnet user-secrets.
2. In backend/agent_service create a Python environment and install requirements.txt. Run npm ci in web/buildwise-web and flutter pub get in mobile/buildwise_mobile.
3. Run dotnet ef database update --project backend/BuildWise.Api after configuring the database connection.
4. From the repository root run powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/start-dev.ps1 -TimeoutSeconds 30.
5. Verify local React at http://127.0.0.1:5173, health at http://127.0.0.1:5078/health, Swagger at http://127.0.0.1:5078/swagger and agent services. Local API origin is http://127.0.0.1:5078/api. Start Flutter with the appropriate device URL.

Detailed isolated startup commands: docs/component2_setup_guide.md. SMTP guidance: docs/email-setup.md. Seeded demo password is Passw0rd!; demo accounts are for evaluation, not production.

## APK installation and verification

Download: https://github.com/IT24102414/build/raw/refs/heads/main/BuildWise.apk. Fresh 5 October release-mode build from source 3b94c1e, published in commit 23d5f22. SHA-256: 7917092FC8B3C378C12920D4202AC4F04527630349ADE8453DE11ACDF055EBAD. Uses the existing development signing key; this is not a production-store signing assertion.

The supplied APK embeds http://10.0.2.2:5078/api for an Android emulator on the API host computer. Download, permit installation from that source if Android asks, install, start the API and agents, and sign in. Alternatively use adb install -r BuildWise.apk. A conflicting older signing key may require removing an old installation; preserve needed data first.

For a physical phone, obtain a reachable public HTTPS API or LAN API host and rebuild:

```powershell
cd mobile/buildwise_mobile
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR_API_HOST/api
```

YOUR_API_HOST is a placeholder, not a deployed address. Verify login, seven roles, request/approval/receiving/inspection flow, camera/gallery permissions, evidence display, notifications, invalid inputs and logout on the installed device. Record device/Android version, checksum, date and real outcomes. Widget tests do not prove physical-device behavior.

## Manual evidence still required

| Required item | Status | What the team must supply |
|---|---|---|
| Public React URL | Not supplied | Reachable app and seeded role verification |
| Public API/health and Swagger URLs | Not supplied | Accessible endpoints and sanitized hosting evidence |
| PostgreSQL deployment | Not supplied | Provider/database identity, migration success and sanitized connectivity evidence |
| Agent access/setup | Local setup available | Deployment configuration and actual persisted workflow execution |
| Four student identities | Incomplete | Confirm registered names and IDs |
| Contribution/PR evidence | Not personally verified | Actual individual attribution and reviewed PR URLs, or state that none exist |
| Individual reflections and logs | Student review required | Personally written reflections and corrected chronological logs |
| Individual/group signatures | Not supplied | Review and actual signatures/dates |
| Device APK execution | Not supplied | Installed-device evidence using reachable API |
| Ten-minute video | Not supplied | Accessible link and actual demonstrated lifecycle |

Keep evaluator access until at least 21 October 2026. The specification deadline was 30 September 2026 at 11:50 PM; this 5 October revision does not certify an on-time submission.

## Test and agent evaluation review

Observed group evidence: 307 backend, 28 Python, 163 React and 149 Flutter tests passed. Later styling verification passed 13 navigation/material-request tests, and the added administrator email-correction regression passed separately. No new aggregate Flutter count is inferred. Flutter analysis was clean and the release APK build succeeded.

Explain negative tests for invalid quantities, unauthorized roles, quotation constraints, NCR transitions, malformed agent recommendations, budget checks and email failures. Record new manual runs with input, expected result, actual result, pass/fail and artifact reference. Do not fill actual outputs before running a case.

Live local performance used 30 requests per scenario at concurrency 5. Quotation-agent p95 was 6782.05 ms against a 1000 ms target and missed it. Investigate provider/rationale latency, measure deterministic and provider-enabled modes separately, and rerun the same workload. Do not lower the threshold to disguise failure. API latency includes database work rather than an isolated SQL benchmark.

Agent evaluation must distinguish deterministic fixture tests from live provider quality. Record schema adherence, rejected invalid outputs, human decisions, permitted tools, persisted state and failure handling. No invented accuracy, baseline, token-cost or user-study result is included.

## Final four-student review and references

Each student confirms their component, reproduces positive and negative tests, explains four API operations plus its domain operation, reviews database relationships and distinct agent, then writes their own contribution statement, AI chronology, one-page reflection and signed declaration. Shared commits remain shared evidence; do not rewrite one author's Git history as four independent histories.

The group checks diagrams against current migrations, verifies deployments and device APK, records the video, signs the group declaration, regenerates and inspects the PDF. Submit one consolidated PDF instead of separate individual report PDFs.

Primary reference: user-supplied SE3090 Assignment 1 specification, Integrated Full-Stack and Agentic AI Application Development, Year 3 Semester 1, 2026, 17 pages. Sections 3–9 cover component/full-stack/agent expectations; 14–16 cover reporting/submission/rubric; 18–19 cover AI disclosure and ownership. Repository paths and actual Git history are implementation references. Historical deployment ADR proposals are not proof of hosting.
