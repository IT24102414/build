import { Fragment, useEffect, useState } from 'react'
import { Button, Card, Drawer, EmptyState, ErrorState, LoadingState, PageHeader, StatusBadge, TextInput } from '../components/shared'
import { qualityApi } from '../services/qualityApi'
import { useAuth } from '../auth/AuthContext'
import './common/common.css'

// Severity/status → badge tone, matching the shared badge scale
// (danger/warning/info/success/neutral) used across procurement screens.
const SEVERITY_TONE = {
  Critical: 'danger',
  High: 'danger',
  Medium: 'warning',
  Low: 'neutral',
}

const STATUS_TONE = {
  Open: 'info',
  UnderReview: 'info',
  CorrectiveActionRequired: 'warning',
  Resolved: 'success',
  Closed: 'neutral',
  AcceptedException: 'warning',
}

// Quality risk level -> badge tone, matching the shared badge scale.
const RISK_TONE = {
  High: 'danger',
  Medium: 'warning',
  Low: 'success',
}

// Splits PascalCase enum values for display: "CorrectiveActionRequired" →
// "Corrective Action Required".
const humanize = (value) => value?.replace(/([A-Z])/g, ' $1').trim() ?? ''

/**
 * Renders the QualityRiskAnalysisAgent result for one inspection.
 *
 * Deliberately states the advisory boundary: the agent recommends a risk level
 * and corrective action, while the inspection decision and the NCRs below it are
 * the authoritative records produced by the backend and the inspector.
 */
function QualityRiskPanel({ analysis }) {
  const flags = analysis.riskFlags ?? []
  return (
    <div className="stack" data-testid="quality-risk-panel">
      <div>
        <strong>AI Quality Risk Analysis</strong>{' '}
        <span className="muted">
          — {analysis.agent} ({analysis.tool}). Advisory only: it does not change this
          inspection or create the NCR; the backend and inspector decide the record.
        </span>
      </div>
      <div className="detail-row"><span>Agent</span><strong>{analysis.agent}</strong></div>
      <div className="detail-row"><span>Tool</span><strong>{analysis.tool}</strong></div>
      <div className="detail-row"><span>Execution source</span><StatusBadge status="info">{analysis.executionSource}</StatusBadge></div>
      <div className="detail-row"><span>Agent status</span><StatusBadge status="success">Completed</StatusBadge></div>
      <div className="detail-row">
        <span>Risk level</span>
        <StatusBadge status={RISK_TONE[analysis.riskLevel] ?? 'neutral'}>{analysis.riskLevel}</StatusBadge>
      </div>
      <div className="detail-row">
        <span>NCR</span>
        <strong>{analysis.requiresNcr ? 'Required by this assessment' : 'Not required'}</strong>
      </div>
      <div className="detail-row"><span>Total inspected</span><strong>{analysis.totalInspected}</strong></div>
      <div className="detail-row"><span>Total rejected</span><strong>{analysis.totalRejected}</strong></div>
      <div className="detail-row"><span>Rejection rate</span><strong>{analysis.rejectionRatePct}%</strong></div>
      <div className="detail-row">
        <span>Risk flags</span>
        <strong>{flags.length ? flags.join(', ') : 'None'}</strong>
      </div>
      <div className="detail-row">
        <span>Recommended action</span>
        <strong>{analysis.suggestedCorrectiveAction}</strong>
      </div>
      <div className="detail-row">
        <span>Recorded inspection</span>
        <strong>{humanize(analysis.inspectionStatus)} · {humanize(analysis.overallDecision)}</strong>
      </div>
    </div>
  )
}

const dateTime = (value) => (value ? new Date(value).toLocaleString() : '—')
const qty = (value) => (value === null || value === undefined ? '—' : `${value} ${value === 1 ? 'unit' : 'units'}`)

// The five quality criteria, in report order, mapped to their structured field.
// These are the same five the inspector ticks on every inspection.
const CHECK_POINTS = [
  ['Quantity', 'quantityCheck'],
  ['Visual condition', 'visualConditionCheck'],
  ['Moisture', 'moistureCheck'],
  ['Packaging', 'packagingCheck'],
  ['Defects', 'defectsCheck'],
]

/**
 * Renders the structured five-point checklist for one inspection.
 *
 * The three states are deliberately distinct because they mean different
 * things:
 *   true  -> checked and passed  (✓ Pass)
 *   false -> checked and failed  (✗ Fail)
 *   null  -> never recorded      (legacy inspection predating the checklist)
 *
 * A legacy row is explicitly marked as not recorded rather than shown as a
 * pass — rendering "✓ Moisture" for an inspection that never recorded it would
 * fabricate a quality result.
 */
function QualityChecklist({ inspection }) {
  const recorded = CHECK_POINTS.filter(([, key]) => inspection[key] !== null && inspection[key] !== undefined)
  if (recorded.length === 0) {
    return <span className="muted" title="This inspection predates the structured checklist">Not recorded</span>
  }
  return (
    <ul style={{ margin: 0, paddingLeft: 0, listStyle: 'none', display: 'grid', gap: 2 }}>
      {CHECK_POINTS.map(([label, key]) => {
        const value = inspection[key]
        if (value === null || value === undefined) {
          return (
            <li key={key} className="muted" style={{ fontSize: '0.8rem' }}>
              {label} · —
            </li>
          )
        }
        return (
          <li
            key={key}
            style={{
              fontSize: '0.8rem',
              color: value ? '#15803d' : '#b91c1c',
              fontWeight: 600,
            }}
          >
            {value ? '✓' : '✗'} {label}
          </li>
        )
      })}
    </ul>
  )
}

// COMPONENT 4 — full non-conformance record. The table shows the summary, but the
// evidence chain behind an NCR (delivery → inspection → item → quantities →
// review trail) was previously unreachable. It is the record a reviewer needs
// before deciding whether to close, so it is opened on demand rather than
// rendered for every NCR at once.
function NcrRecord({ ncr }) {
  const item = ncr.inspectionItem ?? {}
  const inspection = item.inspection ?? {}
  const delivery = inspection.delivery ?? {}
  return (
    <div className="stack">
      <div className="detail-columns">
        <Card title="Non-conformance">
          <div className="detail-row"><span>NCR number</span><strong>{ncr.ncrNumber}</strong></div>
          <div className="detail-row"><span>Status</span><StatusBadge status={STATUS_TONE[ncr.status] ?? 'neutral'}>{humanize(ncr.status)}</StatusBadge></div>
          <div className="detail-row"><span>Severity</span><StatusBadge status={SEVERITY_TONE[ncr.severity] ?? 'neutral'}>{ncr.severity}</StatusBadge></div>
          <div className="detail-row"><span>Raised</span><span>{dateTime(ncr.createdAt)}</span></div>
          <div className="detail-row"><span>Quantity affected</span><span>{ncr.quantityAffected}</span></div>
        </Card>
        <Card title="Material & origin">
          <div className="detail-row"><span>Material</span><span>{item.material?.name ?? '—'}</span></div>
          <div className="detail-row"><span>Delivery</span><span>{delivery.id ? `DEL-${delivery.id}` : '—'}</span></div>
          <div className="detail-row"><span>Delivery ref</span><span>{delivery.deliveryReference ?? '—'}</span></div>
          <div className="detail-row"><span>Inspection</span><span>{inspection.id ? `INS-${inspection.id}` : '—'}</span></div>
          <div className="detail-row"><span>Decision</span><span>{humanize(inspection.overallDecision) || '—'}</span></div>
          <div className="detail-row">
            <span>Quality checklist</span>
            <span><QualityChecklist inspection={inspection} /></span>
          </div>
        </Card>
      </div>
      <Card title="Inspection quantities">
        <div className="detail-row"><span>Inspected</span><span>{qty(item.inspectedQuantity)}</span></div>
        <div className="detail-row"><span>Accepted</span><span>{qty(item.acceptedQuantity)}</span></div>
        <div className="detail-row"><span>Rejected</span><span>{qty(item.rejectedQuantity)}</span></div>
        <div className="detail-row"><span>Rejection reason</span><span>{item.rejectionReason ?? '—'}</span></div>
      </Card>
      <Card title="Issue & corrective action">
        <div className="detail-row"><span>Issue</span><span>{ncr.issueDescription ?? '—'}</span></div>
        <div className="detail-row"><span>Corrective action</span><span>{ncr.correctiveActionPlan ?? '—'}</span></div>
      </Card>
      <Card title="Review trail">
        <div className="detail-row"><span>Resolution</span><span>{ncr.resolution ?? 'Not yet resolved'}</span></div>
        <div className="detail-row"><span>Review notes</span><span>{ncr.reviewNotes ?? '—'}</span></div>
        <div className="detail-row"><span>Reviewed by</span><span>{ncr.reviewedByUserId ? `User ${ncr.reviewedByUserId}` : '—'}</span></div>
        <div className="detail-row"><span>Reviewed at</span><span>{dateTime(ncr.reviewedAt)}</span></div>
        <div className="detail-row"><span>Resolved at</span><span>{dateTime(ncr.resolvedAt)}</span></div>
        <div className="detail-row"><span>Closed at</span><span>{dateTime(ncr.closedAt)}</span></div>
      </Card>
    </div>
  )
}

export default function QualityInspectionsPage() {
  const { hasRole } = useAuth()
  const [ncrs, setNcrs] = useState([])
  const [inspections, setInspections] = useState([])
  const [review, setReview] = useState({})
  // COMPONENT 4 agent results, keyed by inspection id. Kept per inspection so
  // one analysis is never shown against a different inspection's row.
  const [analysisById, setAnalysisById] = useState({})
  const [analyzingId, setAnalyzingId] = useState(null)
  const [analysisError, setAnalysisError] = useState(null)
  // Which NCR's full record is open in the side panel, if any.
  const [openNcrId, setOpenNcrId] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  /**
   * Runs the QualityRiskAnalysisAgent over one inspection. The result is
   * advisory: it recommends risk level and corrective action, while the
   * inspection status and the NCRs remain the authoritative business records
   * created by the backend and the inspector.
   */
  async function runRiskAnalysis(inspectionId) {
    setAnalyzingId(inspectionId)
    setAnalysisError(null)
    try {
      const result = await qualityApi.analyzeQualityRisk(inspectionId)
      // Ignore a response for a different inspection rather than filing it
      // against the wrong row.
      if (result && result.inspectionId != null && result.inspectionId !== inspectionId) {
        setAnalysisError('The analysis response did not match this inspection. Please try again.')
        return
      }
      setAnalysisById((current) => ({ ...current, [inspectionId]: result }))
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
      const [ncrRows, inspectionRows] = await Promise.all([
        qualityApi.listNonConformances(),
        qualityApi.listInspections(),
      ])
      setNcrs(ncrRows)
      setInspections(inspectionRows)
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [])

  const canReview = hasRole('ProcurementManager') || hasRole('SiteManager') || hasRole('Administrator')

  // The record shown in the side panel. Derived from the already-loaded list so
  // opening a detail never needs another request, and so a transition refreshes
  // the panel automatically.
  const openNcr = ncrs.find((ncr) => ncr.id === openNcrId) ?? null

  async function transition(ncr) {
    const current = review[ncr.id] || { status: ncr.status === 'Open' ? 'UnderReview' : ncr.status === 'CorrectiveActionRequired' ? 'Resolved' : 'Closed', resolution: ncr.resolution || '', notes: '' }
    if (['Resolved', 'Closed', 'AcceptedException'].includes(current.status) && !current.resolution.trim()) {
      setError('A resolution is required for this NCR transition.')
      return
    }
    try {
      await qualityApi.transitionNonConformance(ncr.id, { status: current.status, reviewNotes: current.notes, resolution: current.resolution })
      await load()
    } catch (err) { setError(err.message) }
  }

  if (loading) return <LoadingState message="Loading quality inspections…" />
  if (error) return <ErrorState title="Could not load non-conformances" message={error} onRetry={load} />

  const openNcrs = ncrs.filter((n) => n.status !== 'Closed')
  const highSeverity = ncrs.filter((n) => n.severity === 'High' || n.severity === 'Critical')
  const resolved = ncrs.filter((n) => n.status === 'Resolved' || n.status === 'Closed')
  const inspectedItems = new Set(ncrs.map((n) => n.inspectionItemId)).size

  const summaries = [
    ['Open NCRs', String(openNcrs.length), 'Requiring attention', 'var(--color-danger-700)'],
    ['High/Critical Severity', String(highSeverity.length), 'Urgent resolution needed', 'var(--color-warning-700)'],
    ['Resolved NCRs', String(resolved.length), 'Corrective actions completed', 'var(--color-success-700)'],
    ['Flagged Inspection Items', String(inspectedItems), 'Items inspected with issues', 'var(--color-primary-700)'],
  ]

  return (
    <div className="stack">
      <PageHeader
        title="Quality Inspections & Non-Conformance"
        description="Track site inspection results, defect rates, and active Non-Conformance Reports (NCRs)."
      />

      <div className="grid grid--4">
        {summaries.map(([label, value, note, color]) => (
          <Card key={label} className="summary-card" style={{ '--summary-color': color }}>
            <div className="summary-card__label">{label}</div>
            <div className="summary-card__value">{value}</div>
            <div className="summary-card__note">{note}</div>
          </Card>
        ))}
      </div>

      {analysisError && (
        <ErrorState title="Quality risk analysis failed" message={analysisError} />
      )}

      <Card title="Inspection History" subtitle="Completed quality inspections linked to received deliveries.">
        {inspections.length === 0 ? (
          <EmptyState title="No inspections recorded" message="Completed Flutter inspections will appear here." />
        ) : (
          <div className="table-wrap">
            <table className="data-table">
              <thead><tr><th>Inspection</th><th>Delivery</th><th>Decision</th><th>Quality checklist</th><th>Result</th><th>Evidence</th><th>Inspected</th><th>AI Quality Risk</th></tr></thead>
              <tbody>
                {inspections.map((item) => {
                  const analysis = analysisById[item.id]
                  return (
                    <Fragment key={item.id}>
                      <tr>
                        <td><strong>INS-{item.id}</strong></td>
                        <td>DEL-{item.deliveryId}</td>
                        <td><StatusBadge status={item.overallDecision === 'Accepted' ? 'success' : item.overallDecision === 'Rejected' ? 'danger' : 'warning'}>{humanize(item.overallDecision)}</StatusBadge></td>
                        <td><QualityChecklist inspection={item} /></td>
                        <td>{item.observedResult || '—'}</td>
                        <td>{item.evidence?.length || 0}</td>
                        <td>{item.inspectedAt ? new Date(item.inspectedAt).toLocaleString() : '—'}</td>
                        <td>
                          <Button
                            variant="secondary"
                            onClick={() => runRiskAnalysis(item.id)}
                            disabled={analyzingId === item.id}
                          >
                            {analyzingId === item.id
                              ? 'Analyzing…'
                              : analysis ? 'Re-run Analysis' : 'Run AI Analysis'}
                          </Button>
                        </td>
                      </tr>
                      {analysis && (
                        <tr>
                          <td colSpan={8}>
                            <QualityRiskPanel analysis={analysis} />
                          </td>
                        </tr>
                      )}
                    </Fragment>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      <Card title="Active Non-Conformance Reports" subtitle="Non-conformances requiring tracking and corrective action.">
        {ncrs.length === 0 ? (
          <EmptyState
            title="No active non-conformances"
            message="All materials passed inspection — new NCRs appear here automatically when rejected quantities are recorded."
          />
        ) : (
          <div className="table-wrap">
            <table className="data-table">
              <thead>
                <tr>
                  <th>NCR</th>
                  <th>Material</th>
                  <th>Issue</th>
                  <th>Corrective Action</th>
                  <th>Created</th>
                  <th>Severity</th>
                  <th>Status</th>
                  <th>Review / Resolution</th>
                </tr>
              </thead>
              <tbody>
                {ncrs.map((ncr) => (
                  <tr key={ncr.id}>
                    <td>
                      {/* The NCR number opens the full record. Previously it was
                          plain text, so the delivery / inspection / quantity
                          chain behind an NCR was unreachable from the page. */}
                      <Button variant="secondary" onClick={() => setOpenNcrId(ncr.id)}>
                        {ncr.ncrNumber}
                      </Button>
                    </td>
                    <td>{ncr.inspectionItem?.material?.name ?? '—'}</td>
                    <td>{ncr.issueDescription}</td>
                    <td className="muted">{ncr.correctiveActionPlan}</td>
                    <td>{ncr.createdAt ? new Date(ncr.createdAt).toLocaleDateString() : '—'}</td>
                    <td>
                      <StatusBadge status={SEVERITY_TONE[ncr.severity] ?? 'neutral'}>
                        {ncr.severity} Severity
                      </StatusBadge>
                    </td>
                    <td>
                      <StatusBadge status={STATUS_TONE[ncr.status] ?? 'neutral'}>
                        {humanize(ncr.status)}
                      </StatusBadge>
                    </td>
                    <td>
                      {canReview ? (
                        <div className="stack">
                          <select
                            aria-label={`Transition status for ${ncr.ncrNumber}`}
                            value={(review[ncr.id]?.status) || (ncr.status === 'Open' ? 'UnderReview' : ncr.status === 'CorrectiveActionRequired' ? 'Resolved' : 'Closed')}
                            onChange={(e) => setReview((current) => ({ ...current, [ncr.id]: { ...current[ncr.id], status: e.target.value } }))}
                          >
                            {['UnderReview', 'CorrectiveActionRequired', 'Resolved', 'AcceptedException', 'Closed'].map((status) => <option key={status} value={status}>{humanize(status)}</option>)}
                          </select>
                          <TextInput
                            label="Resolution"
                            value={review[ncr.id]?.resolution ?? ncr.resolution ?? ''}
                            onChange={(e) => setReview((current) => ({ ...current, [ncr.id]: { ...current[ncr.id], resolution: e.target.value } }))}
                            multiline
                          />
                          <TextInput
                            label="Review notes"
                            value={review[ncr.id]?.notes ?? ''}
                            onChange={(e) => setReview((current) => ({ ...current, [ncr.id]: { ...current[ncr.id], notes: e.target.value } }))}
                          />
                          <Button variant="secondary" onClick={() => transition(ncr)}>Save transition</Button>
                        </div>
                      ) : '—'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>
      {/* Full NCR record, opened on demand from the NCR number. */}
      {openNcr && (
        <Drawer
          title={openNcr.ncrNumber}
          subtitle={`${openNcr.severity} severity · ${humanize(openNcr.status)}`}
          onClose={() => setOpenNcrId(null)}
        >
          <NcrRecord ncr={openNcr} />
        </Drawer>
      )}
    </div>
  )
}
