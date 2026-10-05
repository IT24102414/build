import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Button, Card, ErrorState, LoadingState, PageHeader, StatusBadge } from '../components/shared'
import { qualityApi } from '../services/qualityApi'
import { useAuth } from '../auth/AuthContext'
import './common/common.css'

const ROLE_COPY = {
  SiteEngineer: { title: 'Site Engineer Dashboard', description: 'Track your site material demand and request approval progress.', eyebrow: 'Site operations' },
  SiteOfficer: { title: 'Site Officer Dashboard', description: 'Reconcile today’s arrivals and record delivery evidence at the site.', eyebrow: 'Site operations' },
  ProcurementOfficer: { title: 'Procurement Officer Dashboard', description: 'Move approved requests through RFQ, quotation and agent evaluation.', eyebrow: 'Procurement office' },
  ProcurementManager: { title: 'Procurement Manager Dashboard', description: 'Review recommendations at the human approval boundary and oversee purchasing.', eyebrow: 'Executive control center' },
  QualityInspector: { title: 'Quality Inspector Dashboard', description: 'Inspect received materials and manage corrective actions for open NCRs.', eyebrow: 'Quality operations' },
  SiteManager: { title: 'Site Manager Dashboard', description: 'Monitor procurement approvals, site delivery and operational exceptions.', eyebrow: 'Management control center' },
  Administrator: { title: 'Administrator Dashboard', description: 'Monitor system-wide operational activity and access the administration workspace.', eyebrow: 'System operations' },
}

const FALLBACK_COPY = { title: 'BuildWise Dashboard', description: 'Your role-aware operations overview.', eyebrow: 'Workspace' }
/**
 * Single display format for audit timestamps across every dashboard and
 * workspace: `02 Oct 2026 · 12:02 PM`.
 *
 * The stored value is UTC and is never modified — this only formats it. Using
 * one helper means two dashboards can never disagree about how the same moment
 * is written, and the raw value stays available in the API for anything that
 * needs to reason about time.
 */
export function formatTimestamp(value) {
  if (!value) return ''
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return ''

  const day = String(date.getDate()).padStart(2, '0')
  const month = date.toLocaleString('en-GB', { month: 'short' })
  const year = date.getFullYear()

  let hours = date.getHours()
  const minutes = String(date.getMinutes()).padStart(2, '0')
  const suffix = hours >= 12 ? 'PM' : 'AM'
  hours = hours % 12 || 12

  return `${day} ${month} ${year} · ${hours}:${minutes} ${suffix}`
}

const formatValue = (metric) => `${Number(metric.value ?? 0).toLocaleString()}${metric.suffix ? ` ${metric.suffix}` : ''}`

// Outcome badge tone, driven by the recorded HTTP status so a refused call is
// visually distinct from a completed one.
const outcomeTone = (statusCode) => {
  if (statusCode >= 200 && statusCode < 300) return 'success'
  if (statusCode === 401 || statusCode === 403) return 'warning'
  return 'danger'
}

export default function DashboardPage() {
  const { roles, user } = useAuth()
  const navigate = useNavigate()
  const [dashboard, setDashboard] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const primaryRole = dashboard?.primaryRole ?? roles[0] ?? 'TeamMember'
  const copy = ROLE_COPY[primaryRole] ?? FALLBACK_COPY

  useEffect(() => {
    let active = true
    setLoading(true)
    qualityApi.dashboard()
      .then((data) => { if (active) setDashboard(data) })
      .catch((err) => { if (active) setError(err.message) })
      .finally(() => { if (active) setLoading(false) })
    return () => { active = false }
  }, [])

  const metricMap = useMemo(() => new Map((dashboard?.metrics ?? []).map((metric) => [metric.key, metric])), [dashboard])
  const metricKeys = {
    SiteEngineer: ['activeRequests', 'awaitingProcurement'],
    SiteOfficer: ['deliveriesExpectedToday', 'deliveriesReconciled', 'discrepanciesLogged'],
    ProcurementOfficer: ['awaitingProcurement', 'activeRfqs', 'quotationsToday'],
    ProcurementManager: ['proposalsAwaitingApproval', 'confirmedPurchaseOrders', 'monthlySpend'],
    QualityInspector: ['deliveriesAwaitingQuality', 'qualityPassRate', 'activeNcrs'],
    SiteManager: ['proposalsAwaitingApproval', 'confirmedPurchaseOrders', 'activeNcrs'],
    Administrator: ['activeRequests', 'activeNcrs', 'proposalsAwaitingApproval'],
  }[primaryRole] ?? ['activeRequests', 'awaitingProcurement', 'proposalsAwaitingApproval']

  if (loading) return <LoadingState message="Loading your role-aware dashboard…" />
  if (error) return <ErrorState message={error} onRetry={() => window.location.reload()} />

  return (
    <div className="stack">
      <PageHeader eyebrow={copy.eyebrow} title={copy.title} description={copy.description} actions={<StatusBadge tone="info">{user?.fullName ?? 'Signed in'}</StatusBadge>} />
      <div className="metric-grid">
        {metricKeys.map((key, index) => {
          const metric = metricMap.get(key)
          const label = key.replace(/([a-z0-9])([A-Z])/g, '$1 $2').replace(/^./, letter => letter.toUpperCase())
          const color = ['var(--color-primary-700)', 'var(--color-warning-700)', 'var(--color-success-700)', '#7040d8'][index % 4]
          const backgroundColor = ['#edf5ff', '#fff6e5', '#ecfaf4', '#f4efff'][index % 4]
          return <Card key={key} className="summary-card" title={metric?.label ?? label} style={{ '--summary-color': color, backgroundColor }}><div className="summary-card__value" style={{ color }}>{formatValue(metric ?? { value: 0 })}</div><div className="summary-card__note">Live from the authenticated API</div></Card>
        })}
      </div>
      <div className="dashboard-columns">
        <Card title="Quick actions" subtitle={`Actions available to ${primaryRole}`}>
          <div className="dashboard-task-list">{(dashboard?.tasks ?? []).map((task) => <div className="dashboard-task" key={task.key}><div><strong>{task.title}</strong><p>{task.description}</p></div><Button variant={task.priority === 'High' ? 'primary' : 'secondary'} onClick={() => navigate(task.route)}>Open</Button></div>)}</div>
        </Card>
        <Card title="Attention required" subtitle="Alerts generated from current workflow state">
          {dashboard?.alerts?.length ? <ul className="activity-list">{dashboard.alerts.map((alert) => <li className="activity-item" key={`${alert.title}-${alert.detail}`}><span className="activity-dot" /><div><strong>{alert.title}</strong><p>{alert.detail}</p><Button variant="secondary" onClick={() => navigate(alert.route)}>Review</Button></div></li>)}</ul> : <p className="empty-copy">No active alerts for this role.</p>}
        </Card>
      </div>
      <Card title="Recent activity" subtitle="Your activity, mapped to the business records it touched">
        {dashboard?.activity?.length ? <ul className="activity-list">{dashboard.activity.map((item) => <li className="activity-item" key={item.id}>
          <span className="activity-dot" />
          <div>
            <strong>{item.title}</strong>
            <p>{item.reference}</p>
            {item.relatedRecords?.length ? <p className="activity-related">{item.relatedRecords.join(' · ')}</p> : null}
            {/* The outcome comes from the recorded HTTP status, so a call the
                backend refused is never presented as a success. */}
            <StatusBadge tone={outcomeTone(item.statusCode)}>{item.outcome}</StatusBadge>
            <span className="activity-time">{formatTimestamp(item.occurredAtUtc)}</span>
            {/* The raw endpoint stays available for debugging without cluttering
                the summary line. */}
            {item.endpoint ? <details className="activity-details"><summary>Technical details</summary><code>{item.endpoint} &rarr; HTTP {item.statusCode}</code></details> : null}
          </div>
        </li>)}</ul> : <p className="empty-copy">No recent activity recorded.</p>}
      </Card>
    </div>
  )
}
