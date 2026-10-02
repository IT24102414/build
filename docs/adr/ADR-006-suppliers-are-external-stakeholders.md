# Suppliers are external stakeholders — ADR

## Status

Accepted. Supersedes the earlier supplier-portal design.

## Context

An earlier iteration of BuildWise modelled a `Supplier` **role**: a login bound to
one supplier record through `User.SupplierId`, a signed `supplier_id` JWT claim, a
`/api/supplier-portal/*` API surface, a `SupplierPortalController`, a React portal
page and a Flutter portal.

That design was rejected because it does not reflect how construction procurement
actually works, and it widened the authentication boundary to parties that are not
BuildWise employees.

## Decision

**A supplier is an external stakeholder, not a BuildWise user.**

Suppliers do **not**:

- log into BuildWise, or hold an account, JWT, role or password
- have a dashboard, portal or mobile app
- access the BuildWise database directly
- see other suppliers' quotations or any internal procurement data

Communication is external, by email:

```text
BuildWise ──RFQ email──▶ External Supplier
External Supplier ──quotation email──▶ Procurement Officer
Procurement Officer ──records quotation──▶ BuildWise
BuildWise ──PO email──▶ External Supplier
External Supplier ──physical delivery──▶ Site Officer (mobile)
BuildWise ──NCR / corrective-action email──▶ External Supplier
```

## What is kept — the business entity

`Supplier` remains a first-class **business entity**, because procurement still
needs the supplier's contact details to send RFQs, record returned quotations,
award purchase orders and raise corrective actions. It is referenced by:

- `RfqSupplier` — which suppliers an RFQ was emailed to
- `Quotation` — which supplier submitted the recorded quotation
- `PurchaseOrder` — which supplier the order was placed with
- `NonConformance` — which supplier a corrective action concerns

`POST /api/material-requests/{id}/quotations` is the officer-side endpoint that
records a quotation **received by email**. It is gated by
`Policies.SupplierAdministrationOnly` (Procurement Officer / Administrator).

## Roles

BuildWise has exactly seven internal roles:

```text
SiteEngineer → SiteManager → ProcurementOfficer → ProcurementManager
             → SiteOfficer → QualityInspector → Administrator
```

### Retired legacy roles

Two earlier aliases were removed once it was verified they were **permission
subsets** of the roles that replaced them:

| Legacy role | Policies it had | Replaced by | Why it was safe |
|---|---|---|---|
| `ReceivingOfficer` | InternalStaff, DeliveryParticipants | **`SiteOfficer`** | SiteOfficer holds both of those plus SiteOperations, QualityReaders and MaterialRequestReaders — a strict superset |
| `ProjectManager` | InternalStaff only | **`SiteManager`** | SiteManager holds InternalStaff plus both approval policies, procurement reads and delivery — a strict superset |

Because each target was a superset, the migration could only *widen* access, never
narrow it unexpectedly.

The `ConsolidateLegacyRoles` migration re-points any account still holding a legacy
role before deleting the role rows, and de-duplicates so a user already holding the
target role is not double-granted. The redundant `receiving.officer@buildwise.demo`
demo login is removed; `site.officer@buildwise.demo` is the Site Officer account.

The Flutter shell keeps a short-lived `legacyAliases` map in `buildwise_roles.dart`
purely so a JWT minted *before* the migration resolves to the right role instead of
locking its holder out. It can be deleted once every client has re-authenticated.

## Client split

| Client | Roles | Surfaces |
|---|---|---|
| React web | all seven | Procurement, approvals, administration |
| Flutter mobile | Site Engineer, Site Officer, Quality Inspector | Field operations only |

Procurement roles signing in on mobile are shown a web-only explainer rather than
a partial procurement UI. This keeps purchase orders raisable in exactly one place.

## Consequences

**Accepted trade-off:** a supplier cannot self-serve a quotation. Every quotation is
transcribed by the Procurement Officer. That is manual work, but it is the real
process, and it keeps authentication limited to internal staff.

**Enforced by tests:** a token carrying a legacy `Supplier` role is refused by every
endpoint (`RbacAuthorizationTests.cs`), the role is not seeded, and no user row is
bound to a supplier.

## Migration

Two migrations were applied to the development database:

**`20261002104811_RemoveSupplierUserAccount`** — deletes legacy supplier login rows
and the `Supplier` role, then drops the `users.SupplierId` foreign key. It **never
touches the `suppliers` table**, so all supplier business records and every
RFQ / quotation / purchase-order relationship are preserved.

**`20261002113029_ConsolidateLegacyRoles`** — re-points accounts holding a retired
role at their canonical replacement (de-duplicated), deletes the now-unused demo
login, and removes the `ProjectManager`, `ReceivingOfficer` and `Supplier` role
rows.

Verified after applying: `roles` holds exactly seven rows, no `users.SupplierId`
column remains, and supplier / RFQ / quotation / purchase-order counts are intact.
