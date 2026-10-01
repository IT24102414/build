# Student 2 Scope — Supplier, RFQ & Procurement Management

**Student Name:** Theebika  
**Student ID:** `IT24102414`  
**Assigned Component:** Component 2 — Supplier Registry, Quotation Evaluation & PO Issuance  
**Git Branch:** `feature/component2-procurement-workflow` (or `feature/student2-vendor-quotation`)  
**AI Agent Owned:** `QuotationSupplierAnalysisAgent` (Python FastAPI, Port `8001`)

---

## 🎯 Technical Ownership & Deliverables

### 1. ASP.NET Core Backend (10 Marks)
- **Controllers:**
  - `backend/BuildWise.Api/Controllers/SuppliersController.cs`
  - `backend/BuildWise.Api/Controllers/QuotationsController.cs`
  - `backend/BuildWise.Api/Controllers/RfqsController.cs`
  - `backend/BuildWise.Api/Controllers/ProcurementWorkflowController.cs`
  - `backend/BuildWise.Api/Controllers/PurchaseOrdersController.cs`
  - `backend/BuildWise.Api/Controllers/SupplierPortalController.cs`
- **Services:** `IntegratedProcurementService.cs`, `ProcurementValidationService.cs`, `QuotationAgentClient.cs`
- **Endpoints Implemented:**
  - `POST /api/suppliers` & `GET /api/suppliers` (Vendor registry)
  - `POST /api/rfqs` (Publish Request for Quotation)
  - `POST /api/quotations` (Submit supplier bids)
  - `GET /api/quotations/compare/{rfqId}` (Quotation comparison matrix)
  - `POST /api/procurement-workflow/evaluate-and-plan` (AI analysis trigger)
  - `POST /api/purchase-orders` (PO issuance after human approval)

### 2. PostgreSQL & Data Modeling (10 Marks)
- **Entities:** `Supplier.cs`, `Quotation.cs`, `QuotationItem.cs`, `Rfq.cs`, `PurchaseOrder.cs`, `PurchaseOrderItem.cs`, `AgentWorkflow.cs`, `AgentWorkflowStep.cs`
- **Entity Configurations:** `SupplierConfiguration.cs`, `QuotationConfiguration.cs`, `PurchaseOrderConfiguration.cs`
- **Key Relationships:** `Rfq` $\rightarrow$ 1:N `Quotations` $\rightarrow$ Selected $\rightarrow$ `PurchaseOrder`

### 3. React Web Frontend (10 Marks)
- **Pages & Components:**
  - `web/buildwise-web/src/pages/ProcurementWorkspacePage.jsx`
  - `web/buildwise-web/src/pages/SupplierPortalPage.jsx`
  - `web/buildwise-web/src/Features/procurement/`
- **Features:** Quotation comparison grid, multi-criteria AI recommendation summary card, budget variance warning box, Sri Lankan TRCSL supplier telephone validation.

### 4. Flutter Mobile App (10 Marks)
- **Screens & Widgets:**
  - `mobile/buildwise_mobile/lib/features/procurement/`
  - `procurement_home_screen.dart`, `quotation_comparison_screen.dart`
- **Features:** Vendor bid review on mobile, quotation PDF viewing, and procurement status tracker.

### 5. Agentic AI Microservice (12 Marks)
- **Agent Service:** `backend/agent_service/quotation_agent.py` (Port `8001`, 16 KB microservice)
- **Agent Test Suite:** `backend/agent_service/test_quotation_agent.py`
- **Capabilities:** Evaluates vendor pricing outliers, delivery lead times, reliability metrics, and returns structured recommendations.

### 6. Security & RBAC (10 Marks)
- Strict Supplier Portal isolation: external suppliers can only view RFQs assigned to them and submit quotes; internal cost models and rival quotes are redacted.
- Budget boundary enforcement (14 specialized tests in `BudgetValidationTests.cs`).

### 7. Testing & Quality (8 Marks)
- `backend/BuildWise.Api.Tests/BudgetValidationTests.cs`
- `backend/BuildWise.Api.Tests/ProcurementPlanningAgentServiceTests.cs`
- `backend/BuildWise.Api.Tests/SupplierPortalIsolationTests.cs`

---

## 🎙️ Viva Defense Focus
- Walk through the Human-in-the-Loop boundary: explain why the agent recommends a quotation, but ASP.NET Core checks project budget before allowing PO issuance.
- Demonstrate prompt-injection resilience in `test_quotation_agent.py`.
- Run `dotnet test --filter "BudgetValidation|Procurement"` during the demonstration.
