# Student 1 Scope — Material Request & Approval Management

**Student Name:** Peiris DPSS  
**Student ID Placeholder:** `IT24XXXXX-Peiris`  
**Assigned Component:** Component 1 — Material Request, Requisition Lifecycle & Planning  
**Git Branch:** `feature/Material-Request---Approval-Management` (or `feature/student1-material-rfq`)  
**AI Agent Owned:** `RequestAnalysisAgent` (Python FastAPI, Port `8002`)

---

## 🎯 Technical Ownership & Deliverables

### 1. ASP.NET Core Backend (10 Marks)
- **Controller:** `backend/BuildWise.Api/Controllers/MaterialRequestsController.cs`
- **Service:** `backend/BuildWise.Api/Services/MaterialRequestService.cs`
- **Endpoints Implemented:**
  - `POST /api/material-requests` (Create new requisition draft)
  - `GET /api/material-requests` (List requisitions with role & project filtering)
  - `GET /api/material-requests/{id}` (Get requisition details & line items)
  - `PUT /api/material-requests/{id}` (Update draft requisition)
  - `DELETE /api/material-requests/{id}` (Cancel/delete draft requisition)
  - `POST /api/material-requests/{id}/submit` (Transition status `Draft -> Submitted`)
  - `GET /api/material-requests/{id}/history` (Retrieve audit history of status changes)

### 2. PostgreSQL & Data Modeling (10 Marks)
- **Entities:** `MaterialRequest.cs`, `MaterialRequestItem.cs`, `MaterialRequestHistory.cs`, `Approval.cs`, `Material.cs`
- **Entity Configurations:** `MaterialRequestConfiguration.cs`, `MaterialRequestItemConfiguration.cs`
- **Key Relationships:** `Project` $\rightarrow$ 1:N `MaterialRequests` $\rightarrow$ 1:N `MaterialRequestItems` $\rightarrow$ `Material`

### 3. React Web Frontend (10 Marks)
- **Pages & Components:**
  - `web/buildwise-web/src/pages/MaterialRequestsPage.jsx`
  - `web/buildwise-web/src/pages/MaterialRequestsPage.test.jsx`
- **Features:** Material selection dropdowns, dynamic quantity and unit indicators, TRCSL Sri Lanka validation, status badges (`Draft`, `Submitted`, `Approved`).

### 4. Flutter Mobile App (10 Marks)
- **Screens & Widgets:**
  - `mobile/buildwise_mobile/lib/features/material_requests/`
  - `material_requests_screen.dart`
- **Features:** Urgent on-site material requisition creation with photo note capture and offline state handling.

### 5. Agentic AI Microservice (12 Marks)
- **Agent Service:** `backend/agent_service/request_agent.py` (Port `8002`)
- **Agent Test Suite:** `backend/agent_service/test_request_agent.py`
- **Capabilities:** Estimates requisition lead times based on material volume and flags delivery priority conflicts.

### 6. Security & RBAC (10 Marks)
- Restricts Site Engineers to view only requests belonging to their assigned construction project.
- Prevents modification of requests once submitted.

### 7. Testing & Quality (8 Marks)
- `backend/BuildWise.Api.Tests/MaterialRequestServiceTests.cs`
- `backend/BuildWise.Api.Tests/RbacAuthorizationTests.cs`

---

## 🎙️ Viva Defense Focus
- Explain the status lifecycle: `Draft` $\rightarrow$ `Submitted` $\rightarrow$ `UnderReview` $\rightarrow$ `Approved` / `Rejected`.
- Demonstrate how EF Core transactions ensure atomic creation of a request and its line items.
- Run `dotnet test --filter "MaterialRequest"` during the demonstration.
