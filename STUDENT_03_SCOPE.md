# Student 3 Scope — Delivery Logistics & Material Receiving

**Student Name:** Ramya  
**Student ID:** `IT24102513`  
**Assigned Component:** Component 3 — Delivery Schedules, Receiving Logistics & GRN Reconciliation  
**Git Branch:** `feature/Delivery-And-Material-Receiving-Ramya-IT24102513` (or `feature/student3-budget-approval`)  
**AI Agent Owned:** `DeliveryDiscrepancyAgent` (Python FastAPI, Port `8003`)

---

## 🎯 Technical Ownership & Deliverables

### 1. ASP.NET Core Backend (10 Marks)
- **Controller:** `backend/BuildWise.Api/Controllers/DeliveriesController.cs`
- **Services:** `backend/BuildWise.Api/Services/DeliveryService.cs`, `DeliveryAgentService.cs`
- **Endpoints Implemented:**
  - `POST /api/deliveries` (Schedule vendor delivery based on approved PO)
  - `GET /api/deliveries` (List deliveries with project & status filters)
  - `GET /api/deliveries/{id}` (Get full delivery docket & line items)
  - `POST /api/deliveries/{id}/receive` (Site Officer gate receipt confirmation)
  - `POST /api/deliveries/{id}/issues` (Record shortage or damaged goods)
  - `POST /api/deliveries/{id}/analyze` (Call DeliveryDiscrepancyAgent on Port 8003)

### 2. PostgreSQL & Data Modeling (10 Marks)
- **Entities:** `Delivery.cs`, `DeliveryItem.cs`, `DeliveryIssue.cs`, `DeliveryEvidence.cs`, `DeliverySchedule.cs`
- **Entity Configurations:** `DeliveryConfiguration.cs`, `DeliveryItemConfiguration.cs`
- **Key Relationships:** `PurchaseOrder` $\rightarrow$ 1:N `Deliveries` $\rightarrow$ 1:N `DeliveryItems` & `DeliveryIssues`

### 3. React Web Frontend (10 Marks)
- **Pages & Components:**
  - `web/buildwise-web/src/pages/DeliveriesPage.jsx`
  - `web/buildwise-web/src/pages/DeliveriesPage.test.jsx`
  - `web/buildwise-web/src/pages/DeliveriesPage.css`
- **Features:** Delivery timeline visualization, expected vs actual quantity variance highlights, Goods Received Note (GRN) generator.

### 4. Flutter Mobile App (10 Marks)
- **Screens & Widgets:**
  - `mobile/buildwise_mobile/lib/features/deliveries/`
  - `delivery_receiving_screen.dart`
- **Features:** **Camera capture** for physical delivery notes, site gate entry confirmation, and photographic evidence for broken cement bags/bent steel.

### 5. Agentic AI Microservice (12 Marks)
- **Agent Service:** `backend/agent_service/delivery_agent.py` (Port `8003`)
- **Agent Test Suite:** `backend/agent_service/test_delivery_agent.py`
- **Capabilities:** Computes quantity variances between PO dockets and gate receipts, detects recurring supplier delivery delays, and formats discrepancy alerts.

### 6. Security & RBAC (10 Marks)
- Ensures Site Officers can record delivery receiving, but cannot mutate purchase order prices or bypass quality gates.
- Evidence attachment security with MIME-type and size validation.

### 7. Testing & Quality (8 Marks)
- `backend/BuildWise.Api.Tests/DeliveryServiceTests.cs`
- `backend/BuildWise.Api.Tests/DeliveryAgentServiceTests.cs`

---

## 🎙️ Viva Defense Focus
- Explain how the delivery receiving flow ensures partial deliveries update PO line item balances without prematurely closing the PO.
- Show the camera integration in Flutter for capturing physical delivery evidence.
- Run `dotnet test --filter "Delivery"` during the demonstration.
