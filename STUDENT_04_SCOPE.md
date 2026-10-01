# Student 4 Scope — Quality Inspection & Non-Conformance Management

**Student Name:** Anoja  
**Student ID Placeholder:** `IT24XXXXX-Anoja`  
**Assigned Component:** Component 4 — Quality Inspection, Checklists, Non-Conformance Reports (NCR)  
**Git Branch:** `feature/quality-inspection` (or `feature/student4-delivery-quality`)  
**AI Agent Owned:** `QualityRiskAnalysisAgent` (Python FastAPI, Port `8004`)

---

## 🎯 Technical Ownership & Deliverables

### 1. ASP.NET Core Backend (10 Marks)
- **Controller:** `backend/BuildWise.Api/Controllers/QualityInspectionsController.cs`
- **Service:** `backend/BuildWise.Api/Services/QualityInspectionService.cs`
- **Endpoints Implemented:**
  - `POST /api/quality-inspections` (Initiate QA inspection on delivered batch)
  - `GET /api/quality-inspections` (List inspections with status & pass/fail filters)
  - `GET /api/quality-inspections/{id}` (Get 5-point checklist details)
  - `POST /api/quality-inspections/{id}/complete` (Submit inspector pass/fail disposition)
  - `POST /api/quality-inspections/{id}/analyze-risk` (Call AI agent on Port 8004)
  - `POST /api/non-conformances` & `GET /api/non-conformances` (NCR lifecycle)
  - `POST /api/non-conformances/{id}/resolve` (Close NCR with resolution proof)

### 2. PostgreSQL & Data Modeling (10 Marks)
- **Entities:** `Inspection.cs`, `InspectionItem.cs`, `InspectionEvidence.cs`, `NonConformance.cs`
- **Enums:** `InspectionDecision.cs`, `InspectionStatus.cs`, `NonConformanceSeverity.cs`, `NonConformanceStatus.cs`
- **Entity Configurations:** `InspectionConfiguration.cs`, `InspectionItemConfiguration.cs`, `NonConformanceConfiguration.cs`
- **Key Relationships:** `Delivery` $\rightarrow$ `Inspection` $\rightarrow$ 1:N `InspectionItems` & (if failed) $\rightarrow$ `NonConformance`

### 3. React Web Frontend (10 Marks)
- **Pages & Components:**
  - `web/buildwise-web/src/pages/QualityInspectionsPage.jsx`
  - `web/buildwise-web/src/pages/QualityInspectionsPage.test.jsx`
  - `web/buildwise-web/src/pages/NonConformancesPage.jsx`
  - `web/buildwise-web/src/Features/quality/` (`NcrRecord.jsx`, `QualityRiskPanel.jsx`, etc.)
- **Features:** 5-point QA checklist evaluator, visual defect risk gauge, NCR tracking dashboard.

### 4. Flutter Mobile App (10 Marks)
- **Screens & Widgets:**
  - `mobile/buildwise_mobile/lib/features/quality/`
  - `quality_inspection_screen.dart`
- **Features:** **QR Scanner** for scanning delivery batch barcodes, checklist grading, and camera upload for defective raw material evidence.

### 5. Agentic AI Microservice (12 Marks)
- **Agent Service:** `backend/agent_service/quality_agent.py` (Port `8004`, largest agent)
- **Agent Test Suite:** `backend/agent_service/test_quality_agent.py`
- **Capabilities:** Analyzes defect percentages ($>5\%$ triggers NCR), assesses structural risk severity (`Critical`, `Major`, `Minor`), and suggests corrective actions (Quarantine, Return, Rework).

### 6. Security & RBAC (10 Marks)
- Restricts QA inspection submissions exclusively to authenticated `QualityInspector` roles.
- Guards NCR closure: Critical NCRs cannot be resolved without verified resolution notes and inspector approval.

### 7. Testing & Quality (8 Marks)
- `backend/BuildWise.Api.Tests/QualityInspectionServiceTests.cs`
- `backend/BuildWise.Api.Tests/FullLifecycleScenarioTests.cs`

---

## 🎙️ Viva Defense Focus
- Explain the 5-point quality checklist: Quantity, Packaging, Material Condition, Technical Specifications, Documentation.
- Show the mathematical validation rule: $\text{Inspected} = \text{Accepted} + \text{Rejected}$.
- Run `dotnet test --filter "QualityInspection"` and `pytest test_quality_agent.py -v`.
