import { useEffect, useState } from 'react'
import { Button, Card, Drawer, EmptyState, ErrorState, LoadingState, PageHeader, StatusBadge, TextInput, SelectInput } from '../components/shared'
import { procurementApi } from '../Features/procurement/services/procurementApi'
import { statusTone } from '../Features/procurement/components/statusTone'
import './common/common.css'

// Returns today's date as YYYY-MM-DD (local timezone)
const todayStr = () => new Date().toISOString().slice(0, 10)
// Returns n days from now as YYYY-MM-DD
const plusDays = (n) => {
  const d = new Date()
  d.setDate(d.getDate() + n)
  return d.toISOString().slice(0, 10)
}

// Validate that a date string is strictly in the future (after today)
function isFutureDate(dateStr) {
  if (!dateStr) return false
  return dateStr > todayStr()
}

export default function RfqPage() {
  const [rfqs, setRfqs] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [statusFilter, setStatusFilter] = useState('all')
  const [selected, setSelected] = useState(null)
  const [creating, setCreating] = useState(false)
  const [requests, setRequests] = useState([])
  const [suppliers, setSuppliers] = useState([])
  const [form, setForm] = useState({
    materialRequestId: '',
    requiredResponseDate: plusDays(7),
    notes: '',
    supplierIds: [],
  })
  const [formError, setFormError] = useState('')

  async function load() {
    setLoading(true)
    setError('')
    try {
      setRfqs(await procurementApi.listRfqs(statusFilter === 'all' ? undefined : statusFilter))
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [statusFilter])

  async function openCreate() {
    setCreating(true)
    setFormError('')
    setError('')
    try {
      const [rs, ss] = await Promise.all([
        procurementApi.listApprovedMaterialRequests(),
        procurementApi.listSuppliers({ pageSize: 100 }),
      ])
      setRequests(rs)
      setSuppliers(ss.items ?? ss)
      setForm({
        materialRequestId: rs[0]?.id ?? '',
        requiredResponseDate: plusDays(7),
        notes: '',
        supplierIds: [],
      })
    } catch (err) {
      setError(err.message)
    }
  }

  function toggleSupplier(id) {
    setForm((c) => ({
      ...c,
      supplierIds: c.supplierIds.includes(id)
        ? c.supplierIds.filter((v) => v !== id)
        : [...c.supplierIds, id],
    }))
  }

  async function create(event) {
    event.preventDefault()
    setFormError('')

    // Date must be strictly future
    if (!isFutureDate(form.requiredResponseDate)) {
      setFormError('Required response date must be a future date (after today).')
      return
    }
    if (form.supplierIds.length === 0) {
      setFormError('Select at least one supplier to invite.')
      return
    }

    setError('')
    try {
      await procurementApi.createRfq({
        ...form,
        materialRequestId: Number(form.materialRequestId),
      })
      setCreating(false)
      await load()
    } catch (err) {
      setFormError(err.message)
    }
  }

  async function closeRfq(id) {
    try {
      await procurementApi.closeRfq(id, 'Closed from RFQ workspace.')
      setSelected(null)
      await load()
    } catch (err) {
      setError(err.message)
    }
  }

  const filteredRfqs = statusFilter === 'all'
    ? rfqs
    : rfqs.filter((r) => r.status === statusFilter)

  if (loading) return <LoadingState message="Loading RFQs…" />
  if (error && !creating) return <ErrorState message={error} onRetry={load} />

  return (
    <div className="stack">
      <PageHeader
        eyebrow="Procurement office"
        title="Requests for Quotation"
        description="Issue supplier requests for quotation, track invitations, and close the quotation window."
        actions={<Button onClick={openCreate}>+ Issue RFQ</Button>}
      />

      {error && <ErrorState message={error} />}

      {/* ── Create form ── */}
      {creating && (
        <Card title="Issue New RFQ" subtitle="RFQs can only be created for Approved material requests">
          <form className="stack" onSubmit={create}>
            <div className="form-grid">
              <SelectInput
                label="Approved material request"
                value={form.materialRequestId}
                onChange={(e) => setForm((c) => ({ ...c, materialRequestId: e.target.value }))}
                options={requests.map((r) => ({ value: r.id, label: `Request #${r.id} · ${r.projectName}` }))}
              />
              <div className="field">
                <label className="field__label">
                  Required response date
                  <span className="field__required"> *</span>
                </label>
                <input
                  className="field__control"
                  type="date"
                  required
                  min={plusDays(1)}
                  value={form.requiredResponseDate}
                  onChange={(e) => {
                    setForm((c) => ({ ...c, requiredResponseDate: e.target.value }))
                    setFormError('')
                  }}
                  aria-invalid={form.requiredResponseDate && !isFutureDate(form.requiredResponseDate) ? 'true' : undefined}
                />
                {form.requiredResponseDate && !isFutureDate(form.requiredResponseDate) && (
                  <span className="field__error">⚠ Response date must be after today.</span>
                )}
                <span className="field__hint">Suppliers must respond by this date (must be in the future).</span>
              </div>
            </div>

            <TextInput
              label="Notes"
              multiline
              value={form.notes}
              onChange={(e) => setForm((c) => ({ ...c, notes: e.target.value }))}
              hint="Optional notes for suppliers."
            />

            <div>
              <strong className="field__label">Invite Active Suppliers</strong>
              {suppliers.filter((s) => s.status === 'Active').length === 0 && (
                <p style={{ color: 'var(--color-text-muted)', fontSize: 'var(--font-sm)', marginTop: '0.5rem' }}>
                  No active suppliers found.
                </p>
              )}
              <div className="toolbar__filters" style={{ marginTop: '0.5rem', flexWrap: 'wrap', gap: '0.75rem' }}>
                {suppliers.filter((s) => s.status === 'Active').map((supplier) => (
                  <label
                    key={supplier.id}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '0.4rem',
                      padding: '0.4rem 0.8rem',
                      borderRadius: '8px',
                      border: form.supplierIds.includes(supplier.id)
                        ? '1.5px solid var(--color-primary-600)'
                        : '1.5px solid var(--color-border)',
                      background: form.supplierIds.includes(supplier.id)
                        ? 'var(--color-primary-50)'
                        : 'var(--color-white)',
                      cursor: 'pointer',
                      fontSize: 'var(--font-sm)',
                      fontWeight: 600,
                      transition: 'all 150ms',
                    }}
                  >
                    <input
                      type="checkbox"
                      checked={form.supplierIds.includes(supplier.id)}
                      onChange={() => toggleSupplier(supplier.id)}
                    />
                    {supplier.name}
                  </label>
                ))}
              </div>
            </div>

            {formError && <span className="field__error" style={{ fontSize: '0.9rem' }}>⚠ {formError}</span>}

            <div className="form-actions">
              <Button variant="secondary" type="button" onClick={() => setCreating(false)}>Cancel</Button>
              <Button
                type="submit"
                disabled={!form.materialRequestId || form.supplierIds.length === 0 || !isFutureDate(form.requiredResponseDate)}
              >
                Issue RFQ
              </Button>
            </div>
          </form>
        </Card>
      )}

      {/* ── Filters + table ── */}
      <Card
        title="RFQ Register"
        subtitle={`${filteredRfqs.length} of ${rfqs.length} RFQs`}
      >
        <div className="toolbar" style={{ marginBottom: '1rem' }}>
          <SelectInput
            label="Filter by status"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            options={[
              { value: 'all', label: 'All statuses' },
              { value: 'Issued', label: 'Issued' },
              { value: 'Closed', label: 'Closed' },
              { value: 'Cancelled', label: 'Cancelled' },
            ]}
          />
        </div>

        {filteredRfqs.length === 0 ? (
          <EmptyState
            title="No RFQs"
            message={statusFilter === 'all' ? 'Issue an RFQ from an approved material request.' : `No RFQs with status "${statusFilter}".`}
          />
        ) : (
          <div className="table-wrap">
            <table className="data-table">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Project</th>
                  <th>Response Date</th>
                  <th>Suppliers</th>
                  <th>Status</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {filteredRfqs.map((rfq) => (
                  <tr key={rfq.id}>
                    <td style={{ fontWeight: 700, color: 'var(--color-primary-700)' }}>#{rfq.id}</td>
                    <td>{rfq.projectName}</td>
                    <td>{rfq.requiredResponseDate}</td>
                    <td>
                      <span
                        style={{
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: '0.3rem',
                          background: 'var(--color-primary-50)',
                          color: 'var(--color-primary-800)',
                          borderRadius: '999px',
                          padding: '0.2rem 0.65rem',
                          fontWeight: 700,
                          fontSize: '0.8rem',
                        }}
                      >
                        {(rfq.suppliers || []).length} invited
                      </span>
                    </td>
                    <td>
                      <StatusBadge status={statusTone(rfq.status)}>{rfq.status}</StatusBadge>
                    </td>
                    <td>
                      <button className="table-action" onClick={() => setSelected(rfq)}>View</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      {/* ── Detail Drawer ── */}
      <Drawer
        open={selected != null}
        title={selected ? `RFQ #${selected.id}` : ''}
        subtitle={selected ? `Linked to Material Request #${selected.materialRequestId} · ${selected.projectName}` : ''}
        onClose={() => setSelected(null)}
      >
        {selected && (
          <div className="stack">
            <div className="actions">
              <StatusBadge status={statusTone(selected.status)}>{selected.status}</StatusBadge>
            </div>

            <Card title="RFQ Information">
              <div className="detail-row">
                <span className="detail-row__label">Project</span>
                <span className="detail-row__value">{selected.projectName}</span>
              </div>
              <div className="detail-row">
                <span className="detail-row__label">Material Request</span>
                <span className="detail-row__value">Request #{selected.materialRequestId}</span>
              </div>
              <div className="detail-row">
                <span className="detail-row__label">Required response date</span>
                <span className="detail-row__value">{selected.requiredResponseDate}</span>
              </div>
              <div className="detail-row">
                <span className="detail-row__label">Created at</span>
                <span className="detail-row__value">{selected.createdAt ? new Date(selected.createdAt).toLocaleDateString() : '—'}</span>
              </div>
              <div className="detail-row">
                <span className="detail-row__label">Notes</span>
                <span className="detail-row__value">{selected.notes || '—'}</span>
              </div>
            </Card>

            <Card title="Invited Suppliers" subtitle={`${(selected.suppliers || []).length} suppliers invited to submit quotations`}>
              {(!selected.suppliers || selected.suppliers.length === 0) ? (
                <EmptyState title="No suppliers invited" message="No suppliers recorded for this RFQ." />
              ) : (
                <div className="table-wrap">
                  <table className="data-table">
                    <thead>
                      <tr>
                        <th>Supplier</th>
                        <th>Supplier Status</th>
                        <th>Invitation</th>
                      </tr>
                    </thead>
                    <tbody>
                      {selected.suppliers.map((s) => (
                        <tr key={s.id || s.supplierId}>
                          <td><strong>{s.supplierName}</strong></td>
                          <td>
                            <StatusBadge status={statusTone(s.supplierStatus || 'Active')}>
                              {s.supplierStatus || 'Active'}
                            </StatusBadge>
                          </td>
                          <td>
                            <StatusBadge status={s.invitationStatus === 'Accepted' || s.status === 'Accepted' ? 'success' : 'neutral'}>
                              {s.invitationStatus || s.status || 'Invited'}
                            </StatusBadge>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </Card>

            {selected.status === 'Issued' && (
              <div className="form-actions">
                <Button
                  variant="danger"
                  onClick={() => closeRfq(selected.id)}
                >
                  Close RFQ Window
                </Button>
              </div>
            )}
          </div>
        )}
      </Drawer>
    </div>
  )
}
