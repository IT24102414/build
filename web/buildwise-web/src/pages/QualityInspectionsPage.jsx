import { useEffect, useState } from 'react'
import { Button, Card, Drawer, EmptyState, ErrorState, LoadingState, PageHeader, SelectInput, StatusBadge, TextInput } from '../components/shared'
import { qualityApi } from '../services/qualityApi'
import QualityRiskPanel from '../Features/quality/components/QualityRiskPanel'
import QualityChecklist from '../Features/quality/components/QualityChecklist'
import { useAuth } from '../auth/AuthContext'
import { hasAnyRole, ROLES } from '../auth/accessControl'

import './common/common.css'

const INITIAL_INSPECTION_FORM = {
  deliveryId: '',
  materialId: 1,
  materialName: 'OPC Cement (50kg bag)',
  inspectedQuantity: 250,
  rejectedQuantity: 0,
  rejectionReason: '',
  quantityCheck: true,
  visualConditionCheck: true,
  moistureCheck: true,
  packagingCheck: true,
  defectsCheck: true,
  inspectionCriteria: 'Quantity, visual condition, moisture, and packaging verification per site QC protocol',
  observedResult: 'Material inspected and acceptable.',
  notes: '',
  evidenceFileName: '',
  evidenceFileUrl: '',
}

/**
 * COMPONENT 4 (first half) — quality inspections.
 *
 * Split from the former single "Quality Inspections & Non-Conformance" page so
 * that inspecting a delivery and resolving a non-conformance become two
 * distinct jobs for two distinct audiences: a Quality Inspector records the
 * inspection, a Procurement Manager or Site Manager closes the NCR.
 */
export default function QualityInspectionsPage() {
  const { roles } = useAuth()
  const canInspect = hasAnyRole(roles, [ROLES.QualityInspector, ROLES.Administrator])

  const [inspections, setInspections] = useState([])
  const [analysisById, setAnalysisById] = useState({})
  const [activeAnalysis, setActiveAnalysis] = useState(null)
  const [analyzingId, setAnalyzingId] = useState(null)
  const [analysisError, setAnalysisError] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  // Record Inspection Form state
  const [isRecordOpen, setIsRecordOpen] = useState(false)
  const [deliveries, setDeliveries] = useState([])
  const [submittingInspection, setSubmittingInspection] = useState(false)
  const [recordError, setRecordError] = useState(null)
  const [recordNotice, setRecordNotice] = useState(null)
  const [form, setForm] = useState(INITIAL_INSPECTION_FORM)

  async function runRiskAnalysis(inspectionId) {
    if (analysisById[inspectionId]) {
      setActiveAnalysis(analysisById[inspectionId])
      return
    }
    setAnalyzingId(inspectionId)
    setAnalysisError(null)
    try {
      const result = await qualityApi.analyzeQualityRisk(inspectionId)
      if (result && result.inspectionId != null && result.inspectionId !== inspectionId) {
        setAnalysisError('The analysis response did not match this inspection. Please try again.')
        return
      }
      setAnalysisById((current) => ({ ...current, [inspectionId]: result }))
      setActiveAnalysis(result)
    } catch (err) {
      setAnalysisError(err.message)
    } finally {
      setAnalyzingId(null)
    }
  }

  const load = async () => {
    setLoading(true)
    setError(null)
    try {
      setInspections(await qualityApi.listInspections())
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [])

  if (loading) return <LoadingState message="Loading quality inspections…" />
  if (error) return <ErrorState title="Could not load inspections" message={error} onRetry={load} />

  async function openRecordModal() {
    setIsRecordOpen(true)
    setRecordError(null)
    try {
      const delList = await qualityApi.listDeliveries()
      const normalized = Array.isArray(delList) ? delList : (delList.deliveries ?? [])
      setDeliveries(normalized)
      if (normalized.length > 0 && !form.deliveryId) {
        setForm((prev) => ({ ...prev, deliveryId: String(normalized[0].id) }))
      }
    } catch {
      setDeliveries([])
    }
  }

  async function handleRecordSubmit(e) {
    e.preventDefault()
    setRecordError(null)
    const inspected = Number(form.inspectedQuantity)
    const rejected = Number(form.rejectedQuantity)

    if (!form.deliveryId) {
      setRecordError('Please select a received delivery to inspect.')
      return
    }
    if (inspected <= 0) {
      setRecordError('Inspected quantity must be greater than zero.')
      return
    }
    if (rejected < 0 || rejected > inspected) {
      setRecordError('Rejected quantity cannot be negative or exceed inspected quantity.')
      return
    }
    if (rejected > 0 && !form.rejectionReason.trim()) {
      setRecordError('A rejection reason is required when rejecting material.')
      return
    }

    setSubmittingInspection(true)
    try {
      const payload = {
        deliveryId: Number(form.deliveryId),
        inspectionCriteria: form.inspectionCriteria,
        observedResult: form.observedResult,
        notes: form.notes,
        quantityCheck: Boolean(form.quantityCheck),
        visualConditionCheck: Boolean(form.visualConditionCheck),
        moistureCheck: Boolean(form.moistureCheck),
        packagingCheck: Boolean(form.packagingCheck),
        defectsCheck: Boolean(form.defectsCheck),
        items: [
          {
            materialId: Number(form.materialId) || 1,
            inspectedQuantity: inspected,
            acceptedQuantity: inspected - rejected,
            rejectedQuantity: rejected,
            rejectionReason: rejected > 0 ? form.rejectionReason.trim() : '',
          },
        ],
        evidence: form.evidenceFileName && form.evidenceFileUrl ? [
          {
            fileName: form.evidenceFileName.trim(),
            fileUrl: form.evidenceFileUrl.trim(),
            contentType: 'image/jpeg',
            fileSizeBytes: 102400,
          },
        ] : [],
      }
      const created = await qualityApi.completeInspection(payload)
      setRecordNotice(`Inspection INS-${created.id} recorded successfully!${rejected > 0 ? ' Non-conformance report (NCR) raised automatically.' : ''}`)
      setIsRecordOpen(false)
      setForm(INITIAL_INSPECTION_FORM)
      await load()
    } catch (err) {
      setRecordError(err.message)
    } finally {
      setSubmittingInspection(false)
    }
  }

  const items = (i) => i.items ?? []
  const totalInspected = inspections.reduce((sum, i) => sum + items(i).reduce((s, it) => s + (it.inspectedQuantity ?? 0), 0), 0)
  const totalRejected = inspections.reduce((sum, i) => sum + items(i).reduce((s, it) => s + (it.rejectedQuantity ?? 0), 0), 0)
  const notFullyAccepted = inspections.filter((i) => i.overallDecision && i.overallDecision !== 'Accepted').length

  const summaryCards = [
    ['Inspections', inspections.length, 'Completed quality records', '#2563eb'],
    ['Not fully accepted', notFullyAccepted, 'Partial or rejected result', '#b45309'],
    ['Units inspected', totalInspected, 'Across all recorded lines', '#0f766e'],
    ['Units rejected', totalRejected, 'Rejected inspection lines automatically raise NCRs', '#b91c1c'],
  ]

  const inspectedNum = Number(form.inspectedQuantity || 0)
  const rejectedNum = Number(form.rejectedQuantity || 0)
  const acceptedNum = Math.max(0, inspectedNum - rejectedNum)
  const isAllChecksPassed = form.quantityCheck && form.visualConditionCheck && form.moistureCheck && form.packagingCheck && form.defectsCheck
  const previewResult = rejectedNum === 0 && isAllChecksPassed ? 'Accepted' : (rejectedNum === inspectedNum || !isAllChecksPassed && rejectedNum > 0) ? 'Rejected' : 'PartiallyAccepted'

  return (
    <div className="stack">
      <PageHeader
        title="Quality Inspections"
        description="Material accepted, partially accepted or rejected on site. Rejected lines automatically raise a non-conformance."
        actions={canInspect ? <Button onClick={openRecordModal}>+ Record Inspection</Button> : null}
      />

      {recordNotice && (
        <Card style={{ backgroundColor: '#f0fdf4', borderColor: '#bbf7d0', color: '#166534' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span>✓ <strong>{recordNotice}</strong></span>
            <Button variant="secondary" onClick={() => setRecordNotice(null)} style={{ fontSize: '0.8rem', padding: '0.2rem 0.6rem' }}>Dismiss</Button>
          </div>
        </Card>
      )}

      <div className="grid grid--4">
        {summaryCards.map(([label, value, note, color]) => (
          <Card key={label} className="summary-card" style={{ '--summary-color': color }}>
            <div className="summary-card__label">{label}</div>
            <div className="summary-card__value">{value}</div>
            <div className="summary-card__note">{note}</div>
          </Card>
        ))}
      </div>

      {analysisError && <div className="field__error" role="alert">{analysisError}</div>}

      <Card title="Inspection History" subtitle="Completed quality inspections linked to received deliveries.">
        {inspections.length === 0 ? (
          <EmptyState
            title="No inspections recorded"
            message="Inspections appear here once a Quality Inspector records a result against a received delivery."
            actionLabel={canInspect ? '+ Record Inspection' : undefined}
            onAction={canInspect ? openRecordModal : undefined}
          />
        ) : (
          <div className="table-wrap">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Inspection</th>
                  <th>Delivery</th>
                  <th>Criteria</th>
                  <th>Result</th>
                  <th>Checklist</th>
                  <th>Inspected</th>
                  <th>Recorded</th>
                  <th>AI</th>
                </tr>
              </thead>
              <tbody>
                {inspections.map((inspection) => {
                  const inspected = items(inspection).reduce((s, it) => s + (it.inspectedQuantity ?? 0), 0)
                  const rejected = items(inspection).reduce((s, it) => s + (it.rejectedQuantity ?? 0), 0)
                  return (
                    <tr key={inspection.id}>
                      <td><strong>INS-{inspection.id}</strong></td>
                      <td>DEL-{inspection.deliveryId}</td>
                      <td className="muted">{inspection.inspectionCriteria || '—'}</td>
                      <td>
                        <StatusBadge status={inspection.overallDecision === 'Accepted' ? 'success' : 'warning'}>
                          {inspection.overallDecision || '—'}
                        </StatusBadge>
                      </td>
                      <td><QualityChecklist inspection={inspection} /></td>
                      <td>
                        {inspected}
                        {rejected > 0 && <div className="muted">{rejected} rejected</div>}
                      </td>
                      <td>{inspection.inspectedAt ? new Date(inspection.inspectedAt).toLocaleDateString() : '—'}</td>
                      <td>
                        <Button
                          variant="secondary"
                          onClick={() => runRiskAnalysis(inspection.id)}
                          disabled={analyzingId === inspection.id}
                        >
                          {analyzingId === inspection.id ? 'Analysing…' : 'Run AI Analysis'}
                        </Button>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      {/* ── AI Risk Assessment Drawer ── */}
      <Drawer
        open={activeAnalysis != null}
        title={`AI Quality Risk — INS-${activeAnalysis?.inspectionId}`}
        subtitle="QualityRiskAnalysisAgent advisory risk assessment"
        onClose={() => setActiveAnalysis(null)}
      >
        {activeAnalysis && <QualityRiskPanel analysis={activeAnalysis} />}
      </Drawer>

      {/* ── Record Inspection Drawer Form ── */}
      <Drawer
        open={isRecordOpen}
        title="Record Quality Inspection"
        subtitle="Complete the 5-point quality checklist. Rejections automatically raise an NCR."
        onClose={() => setIsRecordOpen(false)}
      >
        <form className="stack" onSubmit={handleRecordSubmit}>
          {recordError && <div className="field__error" role="alert">⚠ {recordError}</div>}

          <Card title="1. Delivery & Material">
            <div className="form-grid">
              <SelectInput
                label="Target Delivery"
                value={form.deliveryId}
                onChange={(e) => setForm((p) => ({ ...p, deliveryId: e.target.value }))}
                options={[
                  { value: '', label: 'Select a received delivery…' },
                  ...deliveries.map((d) => ({
                    value: String(d.id),
                    label: `DEL-${d.id} · ${d.deliveryReference || 'Delivery'} (PO-${d.purchaseOrderId})`,
                  })),
                ]}
              />

              <TextInput
                label="Material Description"
                value={form.materialName}
                onChange={(e) => setForm((p) => ({ ...p, materialName: e.target.value }))}
                disabled
              />
            </div>
          </Card>

          <Card title="2. 5-Point Quality Checklist" subtitle="Every criterion must be evaluated before completing the inspection.">
            <div className="stack" style={{ gap: '0.75rem' }}>
              {[
                ['quantityCheck', '1. Quantity verified against delivery invoice & PO'],
                ['visualConditionCheck', '2. Visual condition acceptable (no physical damage / bag tears)'],
                ['moistureCheck', '3. Moisture check passed (dry, lump-free, unhardened)'],
                ['packagingCheck', '4. Packaging intact and standard manufacturer seal verified'],
                ['defectsCheck', '5. No visible structural or transit defects detected'],
              ].map(([key, labelText]) => (
                <label
                  key={key}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '0.6rem',
                    padding: '0.5rem 0.75rem',
                    borderRadius: '6px',
                    border: '1px solid var(--color-border)',
                    background: form[key] ? 'var(--color-success-50, #f0fdf4)' : 'var(--color-danger-50, #fef2f2)',
                    cursor: 'pointer',
                    fontSize: 'var(--font-sm)',
                    fontWeight: 600,
                  }}
                >
                  <input
                    type="checkbox"
                    checked={Boolean(form[key])}
                    onChange={(e) => setForm((p) => ({ ...p, [key]: e.target.checked }))}
                  />
                  <span>{labelText}</span>
                </label>
              ))}
            </div>
          </Card>

          <Card title="3. Quantities & Outcome">
            <div className="form-grid">
              <TextInput
                label="Inspected Quantity"
                type="number"
                min="1"
                value={String(form.inspectedQuantity)}
                onChange={(e) => setForm((p) => ({ ...p, inspectedQuantity: Number(e.target.value) }))}
              />
              <TextInput
                label="Rejected Quantity"
                type="number"
                min="0"
                max={String(form.inspectedQuantity)}
                value={String(form.rejectedQuantity)}
                onChange={(e) => setForm((p) => ({ ...p, rejectedQuantity: Number(e.target.value) }))}
              />
            </div>

            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: '0.75rem', padding: '0.75rem', background: 'var(--color-surface-muted)', borderRadius: '6px' }}>
              <span>Accepted Quantity: <strong>{acceptedNum} units</strong></span>
              <span>Result: <StatusBadge status={previewResult === 'Accepted' ? 'success' : previewResult === 'PartiallyAccepted' ? 'warning' : 'danger'}>{previewResult}</StatusBadge></span>
            </div>

            {rejectedNum > 0 && (
              <div style={{ marginTop: '0.75rem' }}>
                <TextInput
                  label="Rejection Reason (Required for NCR)"
                  value={form.rejectionReason}
                  onChange={(e) => setForm((p) => ({ ...p, rejectionReason: e.target.value }))}
                  placeholder="e.g. 40 bags wet and hardened due to rain during transit"
                  required
                />
              </div>
            )}
          </Card>

          <Card title="4. Evidence & Inspector Comments">
            <div className="form-grid">
              <TextInput
                label="Evidence File Name (Optional)"
                value={form.evidenceFileName}
                onChange={(e) => setForm((p) => ({ ...p, evidenceFileName: e.target.value }))}
                placeholder="e.g. moisture-test-cert.jpg"
              />
              <TextInput
                label="Evidence File URL (Optional)"
                value={form.evidenceFileUrl}
                onChange={(e) => setForm((p) => ({ ...p, evidenceFileUrl: e.target.value }))}
                placeholder="e.g. https://storage.buildwise.demo/qc/img-01.jpg"
              />
            </div>

            <div style={{ marginTop: '0.75rem' }}>
              <TextInput
                label="Inspector Comments / Notes"
                multiline
                value={form.notes}
                onChange={(e) => setForm((p) => ({ ...p, notes: e.target.value }))}
                placeholder="Site condition notes or re-inspection remarks..."
              />
            </div>
          </Card>

          <div className="form-actions">
            <Button variant="secondary" type="button" onClick={() => setIsRecordOpen(false)}>
              Cancel
            </Button>
            <Button type="submit" disabled={submittingInspection || !form.deliveryId}>
              {submittingInspection ? 'Submitting Inspection…' : 'Submit Inspection'}
            </Button>
          </div>
        </form>
      </Drawer>
    </div>
  )
}
