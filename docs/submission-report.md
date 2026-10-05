# BuildWise: Consolidated SE3090 Report Draft

Group: G07 (existing package identifier; confirm before submission)

Revision date: 2026-10-05. Repository: https://github.com/IT24102414/build

Status: evidence-backed technical draft. It is not a signed final submission. The specification deadline was 2026-09-30; this revision does not assert an earlier submission. Individual reflections, signatures, deployment links and video require student input.

## Part A: Group report

### 1. Problem, objectives and scope

Construction projects need a traceable connection between requested materials, supplier offers, purchasing decisions, receiving records and quality outcomes. BuildWise records that lifecycle in one shared system. Operational staff work on mobile; desk users review data and decisions on web. The same operations are available to authorized roles in Flutter so cross-platform access does not change business rules.

The four primary business components are material request/approval, supplier/RFQ/quotation/procurement, delivery/receiving, and quality/NCR management. Suppliers are external contacts approached by email, not authenticated internal users. The seven roles and demo accounts are listed in the root README.

### 2. Functional requirements and rules

Material requests contain project, material, unit, quantity, priority, reason and dates. Typed material names accept letters and numbers and may use suggestions. Site Engineers create their requests. Site Officers track their own request records and receive deliveries. Approvers review demand; the procurement officer records supplier offers and initiates analysis; the procurement manager records the purchasing decision.

Approval creates a confirmed purchase order through the API transaction. The receiving list refreshes to make that order available. Recording deliveries maintains ordered/received/damaged/shortage context. Inspection materials must belong to the selected delivery and inspected quantities cannot exceed the corresponding received quantities.

Inspection rules: positive inspected quantity; non-negative rejected quantity; rejected no larger than inspected; accepted plus rejected equals inspected; at least one line; notes for failed checklist items; reason for rejected quantities; at most ten evidence files, each at most 10 MB. Rejected quantity zero creates no NCR. A positive rejection automatically creates an NCR. Resolved, Closed and AcceptedException require a resolution. Backend transition validation remains authoritative.

Role navigation follows the React navigation table. Flutter Site Officers use the own-request endpoint rather than the full register. Field/quality users can read purchase orders with commercial values redacted by the API. Camera/gallery evidence and local notifications are device capabilities; hardware permission behavior still requires an installed-device run.

### 3. Integrated architecture

Public clients -> ASP.NET Core API -> PostgreSQL and internal Python agent services.

React and Flutter call only the ASP.NET API. Authentication uses hashed passwords and JWTs; authorization policies protect operations. EF Core coordinates relational persistence. Controllers accept DTOs, services enforce rules, and middleware handles auditing/error concerns. Python service ports are internal deployment endpoints, not public client integration points.

| Layer | Responsibility | Evidence |
|---|---|---|
| React | Role routing, forms, dashboards, approval, workflow summaries | web/buildwise-web/src |
| Flutter | Operational forms, role workspaces, secure session, evidence capture | mobile/buildwise_mobile/lib |
| API | Identity, business rules, transactions, audits, workflow orchestration | backend/BuildWise.Api |
| PostgreSQL | Domain entities, relationships, durable workflow state | EF migrations and configurations |
| Agents | Domain analysis, structured outputs, bounded tools, failure results | backend/agent_service |

### 4. Database design

Projects relate to requests; request lines relate to materials; supplier offers relate to approved requests and quotations; approved procurement produces orders and order items; deliveries relate to orders; inspections relate to deliveries and materials; rejection produces NCR follow-up. Agent workflows relate to their steps, validation outcomes and human approvals. User/role relationships govern access.

Use the EF model and migrations as the authoritative schema. The existing ERD DBML/PDF are supporting project diagrams and should be checked against the final migration set before submission. The evidence URL storage migration supports validated inline image data as well as permitted URLs. Entity DTOs expose only the information the caller's policy allows; commercial terms are redacted for field/quality roles.

PostgreSQL stores execution summaries needed for auditability, not hidden model reasoning. High-impact approval is transactional: the recorded decision and resulting confirmed purchase order must stay consistent. State fields and related-record references let the second client observe the updated outcome.

### 5. API design and component evidence

| Component | Representative endpoints / operations | Validation and role boundary |
|---|---|---|
| Requests | GET/POST /api/material-requests; GET /api/material-requests/{id}; POST approval; POST request analysis | Required project/material/quantity; approver-only decisions |
| Procurement | Suppliers CRUD; RFQ issue/close/email; quotation create/delete/compare; workflow start/latest/decision | Officer entry/analysis; manager approval; eligibility and budget checks |
| Receiving | GET/POST /api/deliveries; confirmed purchase order read; delivery detail; discrepancy analysis | Authorized receiving; ordered/received/discrepancy business rules |
| Quality | GET/POST /api/quality-inspections; inspection risk analysis; NCR read/status operations | Delivery/material/quantity/evidence rules; valid resolution transitions |

Swagger is the authoritative route/DTO reference at /swagger. The API supplies appropriate success/failure status codes and structured validation errors; clients show field/API errors rather than hiding every failure behind a generic 400.

### 6. React design

Functional components, hooks, React Router and Context authentication provide routing/session state. Domain service modules centralize API calls. Reusable cards, fields, tables, status badges and error/loading/empty states serve the business pages. Role-filtered navigation and per-operation capabilities complement server enforcement.

The latest update removes unauthorized supplier prefetch when read-only users open purchase orders. Procurement workspaces load the latest persisted recommendation, making officer and manager sessions observe the same result. Responsive layout and phone-width tables were checked with local Playwright.

### 7. Flutter design

Flutter uses reusable widgets, StatefulWidget state, injected services for tests and secure token storage. The responsive navy menu, role labels, order and Plus Jakarta Sans typography align with React. Native operational capabilities remain camera/gallery evidence and local notifications.

Request lists refresh; procurement comparison preserves the selected request and reads the latest workflow; officers record/remove eligible offers and run analysis; managers read recommendations, edit allowed budgets and make decisions. Budget values must be non-negative or blank to clear allocation. Dashboard activity refreshes every 15 seconds while resumed and on resume. Public endpoint/status details are available without recording request bodies or secrets.

### 8. Agentic AI architecture and acceptance workflow

The assessed procurement path receives a domain objective, produces a structured plan and delegates tasks, reads allowed domain tools, ranks eligible offers, applies deterministic validation and pauses before purchase order creation. Authorized approval then produces an auditable result; failed validation or service failure is recorded safely.

| Responsibility | Contract / controls | Visible outcome |
|---|---|---|
| Planning | Structured procurement objective and read-tool inputs | Plan and delegated steps |
| Quotation analysis | Active suppliers, offered/requested quantities and totals | Eligible offer ranking and recommendation |
| Deterministic validation | Schema/business rules and budget context | Validity findings and warnings |
| Request analysis | Request/project/items context | Planning/urgency flags |
| Delivery discrepancy | Ordered, received and damaged quantities | Shortage/damage findings |
| Quality risk | Inspection quantities/reasons | Risk result and NCR recommendation |

Agents have different inputs, outputs and responsibilities. The deployed runtime may use optional LLM rationale; deterministic checks and failure behavior remain necessary when provider credentials are absent or invalid. A live golden-case walkthrough must show persisted steps, validated tool results, authorized approval and final PO, not merely a single prompt response.

### 9. Security and external integration

Secrets belong in environment variables or managed secret storage. Never include .env, provider keys, virtual environments, runtime dumps or request tokens in a submission archive. The updated packager uses git archive of a named committed revision rather than copying local folders indiscriminately.

Self-service API registration permits front-line roles; manager/administrator accounts are provisioned by an administrator. A separate Flutter registration interface was not evidenced in this maintenance run and remains a requirement check. SMTP access is backend-owned. Failed RFQ email is presented as failed with retry controls; a successful HTTP request alone is not evidence that email was sent. No SMTP provider was configured in this local verification.

### 10. Software testing report

| Suite | Observed result | Scope |
|---|---|---|
| .NET/xUnit | 307 passed | Services, validation, authorization, controllers and API integration |
| Python/pytest | 28 passed | Four domain agents and deterministic contract assertions |
| React/Vitest | 163 passed | Components, forms, API errors and role behavior |
| Flutter | 149 passed | Widgets, services, quantities, evidence, role scopes and navigation |
| Final Flutter auth/shell follow-up | 10 passed | Required credentials, login transitions, responsive menu/actions |
| Production builds | React and Flutter web passed | Bundling/compilation evidence |

An initial sandboxed .NET run failed on Windows EventLog permissions; the authorized rerun passed. React lint exits successfully but has existing warnings, which must not be described as zero warnings. Browser checks are read-only. Automated fixtures and widget tests do not establish every physical-device or cross-platform write operation.

A complete seven-role browser review made 179 checks and found a React supplier-prefetch permission defect. After fixing it, a targeted seven-role follow-up made 44 checks with no captured errors or page-width overflow. No unsupported Flutter role workspace or missing expected menu was reported.

### 11. Agent evaluation report

Evaluation combines Python contract tests with API validation and approval tests. Review test_quotation_agent.py, test_request_agent.py, test_delivery_agent.py, test_quality_agent.py, FullLifecycleScenarioTests.cs and RBAC tests. These exercise domain outputs and boundaries rather than relying solely on an LLM judge.

Before final demonstration, capture a golden procurement case, an ineligible supplier case, invalid quantities, missing revision comments, unauthorized approval, agent unavailability and prompt/tool-input rejection. Record workflow IDs, role, expected result, observed state and test version. Do not claim live provider behavior that was not exercised.

### 12. Performance report

The performance harness is scripts/performance-test.mjs. It measures concurrent API/database reads and each internal agent separately, recording success rates, p50/p95/max latency and throughput. The local output is docs/performance-results-2026-10-05.json when the run completes.

These are local Windows results, not a production SLA, network benchmark or separately isolated database latency measurement. Report concurrency, request count, timestamp and environment with the data. Repeat against deployment if production performance is claimed.

### 13. Deployment and CI report

GitHub Actions builds/tests .NET, Python, React and Flutter and uploads build/APK artifacts. Flutter is pinned to the verified 3.47.5 toolchain. The web API base URL is configurable using the VITE_API_BASE_URL repository variable. The deployment ADR records a proposal, not a verified public service. No successful Actions result should be asserted until the published run is inspected.

Required evaluator evidence: public React URL, API health/Swagger URLs, PostgreSQL host evidence, internal agent access from the API, current installed APK and accessible ten-minute video. The root BuildWise.apk is historical and is excluded from new source archives; supply a current verified APK to the package script. Keep access until at least 2026-10-21.

### 14. Demonstration sequence

1. Site Engineer creates a validated request in Flutter.
2. Site Manager opens it in React, reviews analysis and approves demand.
3. Procurement Officer records quotations and starts planning/analysis.
4. Show persisted plan, delegated steps, tool results and validation in the workflow history.
5. Procurement Manager reviews, demonstrates a missing revision-comment rejection, then approves a suitable proposal.
6. Show the confirmed purchase order and returned Flutter status.
7. Site Officer records receiving; show discrepancy analysis.
8. Quality Inspector records rejection with notes, reason and evidence; show automatic NCR.
9. Authorized manager resolves the NCR with a resolution; show rejected invalid transitions.
10. Show tests, actual Git/CI evidence and deployment links. Each member explains their component without external AI assistance.

### 15. Architecture decision records

The report renderer includes the ADR source documents as appendices: durable agent state, orchestration, React state, Flutter state, hosting proposal and external supplier boundaries. These historical decisions include current scope/deployment notes. Students must confirm they understand and own the decisions before signing.

### 16. Group AI disclosure

This maintenance and report draft were AI-assisted using Codex on 2026-10-05. Outputs and actual verification are recorded in docs/reports/2026-10-05-codex-maintenance-log.md. Existing student AI logs/declarations are historical material that the students must review and update; this report does not certify their completeness.

Consolidated group declaration — UNSIGNED TEMPLATE: We disclose all coding-assistant use in our individual logs and the group maintenance record. Each member has reviewed the work claimed under their name and can explain, test and modify it. Each personal reflection is the student's own writing. Historical claims have been checked against actual evidence. This statement becomes a declaration only after all four members verify and sign it.

Student 1 name/ID/signature/date: [complete after review]. Student 2 name/ID/signature/date: [complete after review]. Student 3 name/ID/signature/date: [complete after review]. Student 4 name/ID/signature/date: [complete after review].

## Part B: Individual report sections

The following sections describe repository-supported component work, not verified personal authorship. Each named student must confirm the assigned scope and replace unsigned personal fields. Historical AI logs are included for review; their dates, models, results and reflections are not independently certified by this report.

### Student 1: Peiris DPSS

Primary component: A — Material Request and Approval. Student ID and registered name require confirmation.

#### Contribution statement and technical work

Component responsibility proposed by the existing project ownership map: implement and integrate the API, relational entities, React screens, Flutter screens, tests and domain agent below. Student confirmation: [write the specific work you personally implemented, reviewed and tested; identify shared work and collaborators]. Repository presence alone does not establish who wrote the code.

Demand assessment and human approval beyond CRUD. The API checks required request information, role scope and approval rules; the request agent supports assessment without replacing the approver.

Database scope: MaterialRequest, MaterialRequestItem, Approval. Inspect corresponding EF configurations and migrations for primary/foreign keys, relationships, constraints and audit fields. Explain how the component consumes upstream IDs and exposes downstream records without duplicating another component's source of truth.

| Layer | Evidence file |
|---|---|
| ASP.NET Core API | backend/BuildWise.Api/Controllers/MaterialRequestsController.cs |
| Backend regression tests | backend/BuildWise.Api.Tests/MaterialRequestServiceTests.cs |
| React UI | web/buildwise-web/src/pages/MaterialRequestsPage.jsx |
| Flutter UI | mobile/buildwise_mobile/lib/features/operations/screens/material_requests_screen.dart |
| Flutter tests | mobile/buildwise_mobile/test/material_requests_test.dart |
| Distinct domain agent | backend/agent_service/request_agent.py |
| Agent tests | backend/agent_service/test_request_agent.py |

Meaningful API endpoints: GET /api/material-requests; GET /api/material-requests/my; GET /api/material-requests/{id}; POST /api/material-requests; POST /api/material-requests/{id}/approval; POST /api/agent/analyze-request/{id}. Route parameters are symbolic; inspect controller attributes for exact constraints. This supplies at least four component operations; explain authorization, input DTOs, success responses and invalid-input handling in the viva.

#### Distinct Agentic AI contribution

The component agent is `request_agent.py` with the companion `test_request_agent.py` suite. Document its input contract, permitted context/tool use, structured output and deterministic checks before a human consumes its recommendation. A model-generated rationale is advisory; the API retains business-rule enforcement. Student confirmation: [identify your personally implemented agent function, orchestration/state changes, rejected alternatives and verification]. Explain how a unavailable provider or malformed recommendation is surfaced rather than silently recorded as a valid decision.

#### Commit, pull-request and test evidence

The following is real path-based Git history, including the recorded author. It must not be relabelled as the named student's authorship. Add actual reviewed PR URLs or state that no PR evidence is available.

```
4e09d1c | Loganathan Theebika | Align React and Flutter workflows and refresh SE3090 submission documentation
c318c46 | Loganathan Theebika | Complete field mobile workspaces: approvals, review, PO, quotation entry, RBAC, validation UX
04d35a6 | Loganathan Theebika | Complete field mobile workspaces
9ab414f | IT24102414 | feat: RBAC hardening, supplier portal, budget validation and C1-C4 coverage
```

Commit URLs use https://github.com/IT24102414/build/commit/ followed by the recorded hash. Personal commit/PR attribution: [student verifies]. Tests above belong to the observed group suites; component-specific passed counts must come from a recorded focused run, not a guessed division of the group totals.

#### Challenges and learning — student input

Describe one actual cross-stack contract problem, one invalid input or role boundary you tested, and one agent output you corrected or rejected. Reference the exact change/test. Explain what you can now implement or debug without external AI assistance. Do not claim these experiences until you have personally reviewed and reproduced them.

#### Individual AI usage log

The existing log `IT24XXXXX-Peiris-ai-usage-log.md` is reproduced in the individual-log appendix under this student's label. Verify each date, tool/model, prompt/task, output, correction and test result; remove unsupported entries. Add the actual 5 October maintenance work you reviewed, distinguishing coding-assistant use from the application's own agents. Do not invent past prompts or dates.

#### Approximately one-page personal AI reflection — student authored

[Write approximately one page in your own words. Paragraph 1: tools used and stages of work. Paragraph 2: a useful output and a wrong output, tied to real evidence. Paragraph 3: what you changed, added or rejected and why. Paragraph 4: what you learned about your skills and limits, and how you verified ownership. Use your actual log and Git history. This report deliberately does not generate a first-person reflection for submission.]

#### Signed individual declaration — unsigned template

I confirm that my contribution statement and AI usage log accurately describe my work and assistance received, and that my reflection is my own writing. I can explain, test and modify the work claimed under my name. I have reviewed the evidence linked in this section.

Registered name: [student completes]. Student ID: [student completes]. Signature: [student signs after review]. Date: [actual signing date].


### Student 2: Theebika — IT24102414

Primary component: B — Procurement. Confirm full registered name.

#### Contribution statement and technical work

Component responsibility proposed by the existing project ownership map: implement and integrate the API, relational entities, React screens, Flutter screens, tests and domain agent below. Student confirmation: [write the specific work you personally implemented, reviewed and tested; identify shared work and collaborators]. Repository presence alone does not establish who wrote the code.

Quotation analysis, budget validation and human procurement decision. Officers enter offers and initiate analysis; managers approve or request changes. Successful approval creates a confirmed purchase order transactionally.

Database scope: Supplier, Rfq, Quotation, PurchaseOrder, AgentWorkflow, AgentWorkflowStep, AgentApproval. Inspect corresponding EF configurations and migrations for primary/foreign keys, relationships, constraints and audit fields. Explain how the component consumes upstream IDs and exposes downstream records without duplicating another component's source of truth.

| Layer | Evidence file |
|---|---|
| ASP.NET Core API | backend/BuildWise.Api/Controllers/ProcurementWorkflowController.cs |
| Backend regression tests | backend/BuildWise.Api.Tests/ProcurementValidationServiceTests.cs |
| React UI | web/buildwise-web/src/Features/procurement/pages/RequestWorkspace.jsx; components/QuotationEntryForm.jsx; components/QuotationComparisonView.jsx; components/ProcurementApprovalPanel.jsx |
| Flutter UI | mobile/buildwise_mobile/lib/features/procurement/screens/quotation_comparison_screen.dart |
| Flutter tests | mobile/buildwise_mobile/test/quotation_entry_test.dart |
| Distinct domain agent | backend/agent_service/quotation_agent.py |
| Agent tests | backend/agent_service/test_quotation_agent.py |

Meaningful API endpoints: POST /api/material-requests/{requestId}/procurement-workflow; GET /api/procurement-workflow/{workflowId}; GET /api/procurement-workflow/{workflowId}/history; POST /api/procurement-workflow/{workflowId}/decision. Route parameters are symbolic; inspect controller attributes for exact constraints. This supplies at least four component operations; explain authorization, input DTOs, success responses and invalid-input handling in the viva.

#### Distinct Agentic AI contribution

The component agent is `quotation_agent.py` with the companion `test_quotation_agent.py` suite. Document its input contract, permitted context/tool use, structured output and deterministic checks before a human consumes its recommendation. A model-generated rationale is advisory; the API retains business-rule enforcement. Student confirmation: [identify your personally implemented agent function, orchestration/state changes, rejected alternatives and verification]. Explain how a unavailable provider or malformed recommendation is surfaced rather than silently recorded as a valid decision.

#### Commit, pull-request and test evidence

The following is real path-based Git history, including the recorded author. It must not be relabelled as the named student's authorship. Add actual reviewed PR URLs or state that no PR evidence is available.

```
4e09d1c | Loganathan Theebika | Align React and Flutter workflows and refresh SE3090 submission documentation
c318c46 | Loganathan Theebika | Complete field mobile workspaces: approvals, review, PO, quotation entry, RBAC, validation UX
04d35a6 | Loganathan Theebika | Complete field mobile workspaces
9ab414f | IT24102414 | feat: RBAC hardening, supplier portal, budget validation and C1-C4 coverage
```

Commit URLs use https://github.com/IT24102414/build/commit/ followed by the recorded hash. Personal commit/PR attribution: [student verifies]. Tests above belong to the observed group suites; component-specific passed counts must come from a recorded focused run, not a guessed division of the group totals.

#### Challenges and learning — student input

Describe one actual cross-stack contract problem, one invalid input or role boundary you tested, and one agent output you corrected or rejected. Reference the exact change/test. Explain what you can now implement or debug without external AI assistance. Do not claim these experiences until you have personally reviewed and reproduced them.

#### Individual AI usage log

The existing log `IT24102414-ai-usage-log.md` is reproduced in the individual-log appendix under this student's label. Verify each date, tool/model, prompt/task, output, correction and test result; remove unsupported entries. Add the actual 5 October maintenance work you reviewed, distinguishing coding-assistant use from the application's own agents. Do not invent past prompts or dates.

#### Approximately one-page personal AI reflection — student authored

[Write approximately one page in your own words. Paragraph 1: tools used and stages of work. Paragraph 2: a useful output and a wrong output, tied to real evidence. Paragraph 3: what you changed, added or rejected and why. Paragraph 4: what you learned about your skills and limits, and how you verified ownership. Use your actual log and Git history. This report deliberately does not generate a first-person reflection for submission.]

#### Signed individual declaration — unsigned template

I confirm that my contribution statement and AI usage log accurately describe my work and assistance received, and that my reflection is my own writing. I can explain, test and modify the work claimed under my name. I have reviewed the evidence linked in this section.

Registered name: [student completes]. Student ID: [student completes]. Signature: [student signs after review]. Date: [actual signing date].


### Student 3: Ramya — IT24102513

Primary component: C — Delivery and Receiving. Confirm full registered name.

#### Contribution statement and technical work

Component responsibility proposed by the existing project ownership map: implement and integrate the API, relational entities, React screens, Flutter screens, tests and domain agent below. Student confirmation: [write the specific work you personally implemented, reviewed and tested; identify shared work and collaborators]. Repository presence alone does not establish who wrote the code.

Receiving and discrepancy classification beyond CRUD. Confirmed orders feed receiving; persisted received quantities establish the upper bound for downstream inspection. Supplier/material labels must use the actual DTO shape.

Database scope: Delivery, DeliveryItem, DeliveryIssue, DeliveryEvidence. Inspect corresponding EF configurations and migrations for primary/foreign keys, relationships, constraints and audit fields. Explain how the component consumes upstream IDs and exposes downstream records without duplicating another component's source of truth.

| Layer | Evidence file |
|---|---|
| ASP.NET Core API | backend/BuildWise.Api/Controllers/DeliveriesController.cs |
| Backend regression tests | backend/BuildWise.Api.Tests/DeliveryServiceTests.cs |
| React UI | web/buildwise-web/src/pages/DeliveriesPage.jsx |
| Flutter UI | mobile/buildwise_mobile/lib/features/operations/screens/delivery_receiving_screen.dart |
| Flutter tests | mobile/buildwise_mobile/test/delivery_receiving_test.dart |
| Distinct domain agent | backend/agent_service/delivery_agent.py |
| Agent tests | backend/agent_service/test_delivery_agent.py |

Meaningful API endpoints: GET /api/deliveries; GET /api/deliveries/confirmed-orders; POST /api/deliveries; POST /api/deliveries/{id}/discrepancy-analysis; GET /api/deliveries/{id}/issues. Route parameters are symbolic; inspect controller attributes for exact constraints. This supplies at least four component operations; explain authorization, input DTOs, success responses and invalid-input handling in the viva.

#### Distinct Agentic AI contribution

The component agent is `delivery_agent.py` with the companion `test_delivery_agent.py` suite. Document its input contract, permitted context/tool use, structured output and deterministic checks before a human consumes its recommendation. A model-generated rationale is advisory; the API retains business-rule enforcement. Student confirmation: [identify your personally implemented agent function, orchestration/state changes, rejected alternatives and verification]. Explain how a unavailable provider or malformed recommendation is surfaced rather than silently recorded as a valid decision.

#### Commit, pull-request and test evidence

The following is real path-based Git history, including the recorded author. It must not be relabelled as the named student's authorship. Add actual reviewed PR URLs or state that no PR evidence is available.

```
4e09d1c | Loganathan Theebika | Align React and Flutter workflows and refresh SE3090 submission documentation
04d35a6 | Loganathan Theebika | Complete field mobile workspaces
9ab414f | IT24102414 | feat: RBAC hardening, supplier portal, budget validation and C1-C4 coverage
9466c5e | Loganathan Theebika | feat: complete procurement and operations workflow
```

Commit URLs use https://github.com/IT24102414/build/commit/ followed by the recorded hash. Personal commit/PR attribution: [student verifies]. Tests above belong to the observed group suites; component-specific passed counts must come from a recorded focused run, not a guessed division of the group totals.

#### Challenges and learning — student input

Describe one actual cross-stack contract problem, one invalid input or role boundary you tested, and one agent output you corrected or rejected. Reference the exact change/test. Explain what you can now implement or debug without external AI assistance. Do not claim these experiences until you have personally reviewed and reproduced them.

#### Individual AI usage log

The existing log `IT24102513-Ramya-ai-usage-log.md` is reproduced in the individual-log appendix under this student's label. Verify each date, tool/model, prompt/task, output, correction and test result; remove unsupported entries. Add the actual 5 October maintenance work you reviewed, distinguishing coding-assistant use from the application's own agents. Do not invent past prompts or dates.

#### Approximately one-page personal AI reflection — student authored

[Write approximately one page in your own words. Paragraph 1: tools used and stages of work. Paragraph 2: a useful output and a wrong output, tied to real evidence. Paragraph 3: what you changed, added or rejected and why. Paragraph 4: what you learned about your skills and limits, and how you verified ownership. Use your actual log and Git history. This report deliberately does not generate a first-person reflection for submission.]

#### Signed individual declaration — unsigned template

I confirm that my contribution statement and AI usage log accurately describe my work and assistance received, and that my reflection is my own writing. I can explain, test and modify the work claimed under my name. I have reviewed the evidence linked in this section.

Registered name: [student completes]. Student ID: [student completes]. Signature: [student signs after review]. Date: [actual signing date].


### Student 4: Anoja

Primary component: D — Quality Inspection and NCR. Student ID and registered name require confirmation.

#### Contribution statement and technical work

Component responsibility proposed by the existing project ownership map: implement and integrate the API, relational entities, React screens, Flutter screens, tests and domain agent below. Student confirmation: [write the specific work you personally implemented, reviewed and tested; identify shared work and collaborators]. Repository presence alone does not establish who wrote the code.

Inspection quantity reconciliation, automatic NCR creation and controlled resolution. Zero rejection creates no NCR; positive rejection creates one. Failed checklist items require notes, rejected quantities require reasons, and evidence count/size limits apply.

Database scope: Inspection, InspectionItem, InspectionEvidence, NonConformance. Inspect corresponding EF configurations and migrations for primary/foreign keys, relationships, constraints and audit fields. Explain how the component consumes upstream IDs and exposes downstream records without duplicating another component's source of truth.

| Layer | Evidence file |
|---|---|
| ASP.NET Core API | backend/BuildWise.Api/Controllers/QualityInspectionsController.cs |
| Backend regression tests | backend/BuildWise.Api.Tests/QualityInspectionServiceTests.cs |
| React UI | web/buildwise-web/src/pages/QualityInspectionsPage.jsx |
| Flutter UI | mobile/buildwise_mobile/lib/features/operations/screens/quality_inspection_screen.dart |
| Flutter tests | mobile/buildwise_mobile/test/quality_inspection_test.dart |
| Distinct domain agent | backend/agent_service/quality_agent.py |
| Agent tests | backend/agent_service/test_quality_agent.py |

Meaningful API endpoints: POST /api/quality-inspections; GET /api/quality-inspections; GET /api/quality-inspections/{id}; POST /api/quality-inspections/{id}/risk-analysis; GET /api/quality-inspections/non-conformances; POST /api/quality-inspections/non-conformances/{id}/transition. Route parameters are symbolic; inspect controller attributes for exact constraints. This supplies at least four component operations; explain authorization, input DTOs, success responses and invalid-input handling in the viva.

#### Distinct Agentic AI contribution

The component agent is `quality_agent.py` with the companion `test_quality_agent.py` suite. Document its input contract, permitted context/tool use, structured output and deterministic checks before a human consumes its recommendation. A model-generated rationale is advisory; the API retains business-rule enforcement. Student confirmation: [identify your personally implemented agent function, orchestration/state changes, rejected alternatives and verification]. Explain how a unavailable provider or malformed recommendation is surfaced rather than silently recorded as a valid decision.

#### Commit, pull-request and test evidence

The following is real path-based Git history, including the recorded author. It must not be relabelled as the named student's authorship. Add actual reviewed PR URLs or state that no PR evidence is available.

```
4e09d1c | Loganathan Theebika | Align React and Flutter workflows and refresh SE3090 submission documentation
c318c46 | Loganathan Theebika | Complete field mobile workspaces: approvals, review, PO, quotation entry, RBAC, validation UX
04d35a6 | Loganathan Theebika | Complete field mobile workspaces
9ab414f | IT24102414 | feat: RBAC hardening, supplier portal, budget validation and C1-C4 coverage
```

Commit URLs use https://github.com/IT24102414/build/commit/ followed by the recorded hash. Personal commit/PR attribution: [student verifies]. Tests above belong to the observed group suites; component-specific passed counts must come from a recorded focused run, not a guessed division of the group totals.

#### Challenges and learning — student input

Describe one actual cross-stack contract problem, one invalid input or role boundary you tested, and one agent output you corrected or rejected. Reference the exact change/test. Explain what you can now implement or debug without external AI assistance. Do not claim these experiences until you have personally reviewed and reproduced them.

#### Individual AI usage log

The existing log `IT24XXXXX-Anoja-ai-usage-log.md` is reproduced in the individual-log appendix under this student's label. Verify each date, tool/model, prompt/task, output, correction and test result; remove unsupported entries. Add the actual 5 October maintenance work you reviewed, distinguishing coding-assistant use from the application's own agents. Do not invent past prompts or dates.

#### Approximately one-page personal AI reflection — student authored

[Write approximately one page in your own words. Paragraph 1: tools used and stages of work. Paragraph 2: a useful output and a wrong output, tied to real evidence. Paragraph 3: what you changed, added or rejected and why. Paragraph 4: what you learned about your skills and limits, and how you verified ownership. Use your actual log and Git history. This report deliberately does not generate a first-person reflection for submission.]

#### Signed individual declaration — unsigned template

I confirm that my contribution statement and AI usage log accurately describe my work and assistance received, and that my reflection is my own writing. I can explain, test and modify the work claimed under my name. I have reviewed the evidence linked in this section.

Registered name: [student completes]. Student ID: [student completes]. Signature: [student signs after review]. Date: [actual signing date].


## Part C: Submission links and references

Repository: https://github.com/IT24102414/build

React deployment: NOT PROVIDED. API/health/Swagger deployment: NOT PROVIDED. PostgreSQL deployment evidence: NOT PROVIDED. Current APK: https://github.com/IT24102414/build/raw/refs/heads/main/BuildWise.apk (source commit 3b94c1e, artifact commit 23d5f22; release-mode build succeeded). Physical-device installation evidence: NOT PROVIDED. API endpoint embedded in this demo APK: http://10.0.2.2:5078/api, suitable for the Android emulator only. SHA-256: 7917092FC8B3C378C12920D4202AC4F04527630349ADE8453DE11ACDF055EBAD. Existing development-key signing is used; this is not a production-store signing assertion. Ten-minute video: NOT PROVIDED.

Primary requirements source: user-supplied SE3090 Assignment 1 specification, Year 3 Semester 1, 2026. Implementation references: root README, current source, EF migrations, test suites, docs/submission-readiness.md and the listed ADRs. Library dependencies and font licensing are recorded in package manifests and assets/fonts/OFL.txt. This draft supplies no invented signatures, contribution history, performance figures or deployment results.


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
