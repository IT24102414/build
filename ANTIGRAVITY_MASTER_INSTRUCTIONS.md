# BuildWise – SE3090 Master Development Instructions

You are working on an existing academic software engineering project called:
**BuildWise – Construction Procurement & Quality Platform**.

The system satisfies the **SE3090 Software Engineering Frameworks Assignment 1** requirements (BSc Hons in IT, Specializing in SE / AI).

---

## 🛠️ Mandatory Technology Stack

- **Backend:** C#, ASP.NET Core 8 Web API, Entity Framework Core, PostgreSQL, REST API, JWT Authentication, Role-based Authorization (RBAC), DTOs, Service Layer, Dependency Injection, Validation, Global Error Handling, Serilog Logging, Swagger OpenAPI, Health Endpoints.
- **Web:** React 18, Vite, Functional Components, Hooks, React Router 6, Tailwind CSS, Protected Routes, Role-based UI Filtering, REST API Integration.
- **Mobile:** Flutter 3, Dart, Reusable Widgets, GoRouter / Navigator, State Management, Secure Token Storage, Camera / Image Upload for Field Evidence, QR Scanner, Location Recording.
- **Agentic AI:** Python FastAPI Microservices (Ports 8001–8004), Domain-Specific Multi-Agent Architecture, Structured JSON Outputs, Allow-listed Tool Execution, Durable Workflow State in PostgreSQL, Human-in-the-Loop Approval Gate, Full Audit Logging.
- **Client Integration Rule:** React and Flutter clients MUST NEVER call the Python AI microservices directly. ASP.NET Core acts as the unified gateway and orchestrator.

---

## 🏛️ System Architecture

```text
React Web (5173) ──┐
                   ├──> ASP.NET Core Web API (5078) ──> PostgreSQL Database (5432)
Flutter App (8080) ┘                 │
                                     ▼
                        Agentic AI Microservices
                         ├── PlannerAgent (8002)
                         ├── VendorAnalysisAgent (8001)
                         ├── BudgetValidationAgent (8001/8003)
                         └── DeliveryDiscrepancyAgent / QualityAgent (8003/8004)
```

---

## 👥 4-Member Component & Agent Ownership

| Student | Owned Component | Primary AI Agent & Microservice | Key Responsibilities |
| :--- | :--- | :--- | :--- |
| **Student 1 (Peiris DPSS)** | Material Request & Approval | **PlannerAgent** (Port 8002) | Requisition lifecycle, draft-to-submit guards, project isolation, approval histories |
| **Student 2 (Theebika IT24102414)** | Supplier, RFQ & Procurement | **VendorAnalysisAgent** (Port 8001) | Supplier registry, RFQ bidding, AI quotation multi-factor scoring, PO generation |
| **Student 3 (Ramya IT24102513)** | Delivery & Receiving Logistics | **DeliveryDiscrepancyAgent** (Port 8003) | Gate receiving, PO line item reconciliation, shortage detection, damage photos |
| **Student 4 (Anoja)** | Quality Inspection & NCR | **QualityRiskAnalysisAgent** (Port 8004) | 5-point quality checklist, pass/fail thresholds, defect risk scoring, NCR resolution |

---

## 🛡️ Security & AI Safety Principles

1. **Deterministic Boundaries:** AI models provide structured advisory evaluation only. They NEVER mutate financial balances, approve budgets, or bypass business logic autonomously.
2. **Human Approval Gates:** Any quotation causing a budget variance requires explicit, authenticated sign-off from a `ProcurementManager` in ASP.NET Core.
3. **Allow-listed Tools:** All agent tool executions are strictly validated against Pydantic schemas and logged into `AgentToolExecutions`.
4. **Zero Hardcoded Secrets:** Connection strings, JWT signing keys, and service URLs are loaded via environment variables (`.env`).

---

## 🌿 Git Branching Strategy

- `main` — Production-ready, stable releases.
- `develop` — Shared staging and integration branch.
- `feature/student1-material-rfq` — Student 1 active workspace.
- `feature/student2-vendor-quotation` — Student 2 active workspace.
- `feature/student3-budget-approval` — Student 3 active workspace.
- `feature/student4-delivery-quality` — Student 4 active workspace.

---

## 🧪 Verification Protocol

Before opening a Pull Request into `develop`, verify:
1. `dotnet test backend/BuildWise.Api.Tests/BuildWise.Api.Tests.csproj` (230/230 Passing)
2. `cd backend/agent_service && pytest -v` (28/28 Passing)
3. `cd web/buildwise-web && npm test -- --run` (109/109 Passing)
4. `cd mobile/buildwise_mobile && flutter test`
5. No uncommitted API keys, credentials, or transient files (`bin/obj`, `node_modules`).
