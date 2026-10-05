# Assignment evidence and submission readiness

Reference: supplied SE3090 Assignment 1 specification, 2026. Updated 2026-10-05.

## Evidence map

| Specification | Evidence in this repository | Status / limitation |
|---|---|---|
| 2, 5: public ASP.NET API | backend/BuildWise.Api/Controllers, Services, DTOs, Security | Implemented; 307 tests passed |
| 6: PostgreSQL / EF | Data/Configurations, Data/Migrations, docs/BuildWise_ERD.dbml | Implemented; hosting evidence still required |
| 7: React and role navigation | web/buildwise-web/src/auth/accessControl.js, pages, Features | 163 tests; responsive browser review |
| 8: genuine Flutter operations | mobile/buildwise_mobile/lib, test; image_picker; secure storage | 149 tests; physical-device demonstration pending |
| 8: registration | API registration endpoint; administrator account management | Separate Flutter registration UI not evidenced; validate against evaluator expectations |
| 9: assessed agent workflow | ProcurementWorkflowService, internal agent_service, agent tests, ADR-001/002 | Plan, tools, validation, durable state and approval implemented; run live golden scenario |
| 10: cross-platform workflow | scripts/verify-full-journey.ps1; FullLifecycleScenarioTests.cs | Automated lifecycle coverage; capture client-to-client demonstration video |
| 11: third party | SmtpEmailService; RFQ email controls; docs/email-setup.md | SMTP implemented; no configured provider in current local run |
| 12: test/evaluation/performance | API, Python, React, Flutter tests; scripts/performance-test.mjs | Test results verified; fresh performance measurements required |
| 13: Git / CI | .github/workflows/ci.yml; real commit history | CI configured; verify actual run after push; do not invent historical PRs |
| 14: docs / deployment / ADR | README, docs/adr, report draft | Public URLs, deployment evidence and latest APK install not verified |
| 15: consolidated submission | docs/submission-report.md; scripts/package-submission.ps1 | Draft; member input and final signed PDF required |
| 17: viva | report demonstration sequence and verification scripts | Rehearse with every member, without external AI assistance |
| 18: AI disclosure | docs/reports/2026-10-05-codex-maintenance-log.md | Current maintenance disclosed; students must verify personal logs and write reflections |

## Concrete completion checklist

- [ ] Supply approved group number, complete student IDs and component ownership confirmation.
- [ ] Complete each individual contribution section with real commit/PR/test links.
- [ ] Write personal reflections and sign individual/group declarations; historical declarations are not proof of review of this revision.
- [ ] Configure a real SMTP provider and record a successful RFQ email without exposing credentials.
- [ ] Record a complete Flutter-originated request, React approval, agents, PostgreSQL changes and returned Flutter status.
- [ ] Run performance harness and record timestamp, machine, concurrency, latency and failure rate.
- [ ] Deploy React, API, PostgreSQL and internal agents; record and verify public URLs in an incognito browser.
- [ ] Download the current CI APK artifact, install it, and test camera/gallery and notification permissions.
- [ ] Attach the accessible 10-minute video link and preserve access until at least 2026-10-21.
- [ ] Check the pushed GitHub Actions run and complete a consolidated PDF before final submission.

FCM and a supplier self-service portal are not mandatory features in the supplied specification. BuildWise uses local device notifications and email-based external supplier interactions. Their absence should not be presented as a missing required technology, nor should unimplemented features be claimed as complete.

## Reproducible evidence

Current local results: API 307, Python 28, React 163, Flutter 149 tests passed. React and Flutter web builds passed. A complete seven-role browser review made 179 checks; a supplier prefetch defect in React was corrected and a 44-check targeted follow-up passed without captured errors or overflow. Reports are local generated evidence, deliberately excluded from Git to avoid uploading runtime dumps and bulky artifacts.

Source references and commands are preserved in README, docs/mobile-web-parity-review.md and docs/project_verification_guide.md. Re-run the documented commands at the published revision; do not present older result counts or generated APKs as current.


### Observed local performance (2026-10-05)

30 requests per scenario, concurrency 5. All scenarios returned 100% successful responses.

| Scenario | p95 ms | Target ms | Outcome |
|---|---|---|---|
| Shared ASP.NET Core API + PostgreSQL | 78.89 | 2000 | Passed |
| Agent 8001 quotation analysis | 6782.05 | 1000 | Latency target missed |
| Agent 8002 request analysis | 94.49 | 1000 | Passed |
| Agent 8003 discrepancy analysis | 82.03 | 1000 | Passed |
| Agent 8004 quality-risk analysis | 58.02 | 1000 | Passed |

Quotation analysis missed the 1000 ms local target; investigate provider/rationale latency before claiming performance acceptance. No threshold was relaxed. API/database latency is measured together, not as an isolated database benchmark.
