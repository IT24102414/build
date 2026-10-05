import { useEffect, useState } from 'react'
import { Card, ErrorState, LoadingState, PageHeader, StatusBadge } from '../../../components/shared'
import { procurementApi } from '../services/procurementApi'
import { statusTone } from '../components/statusTone'
import { useAuth } from '../../../auth/AuthContext'
import { canSeeCommercialTerms } from '../../../auth/accessControl'

export default function PurchaseOrderDetail({ orderId, onBack }) {
  const { roles } = useAuth()
  const showCommercials = canSeeCommercialTerms(roles)

  const [order, setOrder] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  const load = async () => {
    setLoading(true)
    setError(null)
    try {
      const data = await procurementApi.getPurchaseOrder(orderId)
      setOrder(data)
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    load()
  }, [orderId])

  if (loading) return <LoadingState message="Loading purchase order…" />
  if (error) return <ErrorState message={error} onRetry={load} />
  if (!order) return null

  const links = [
    order.quotationId ? `quotation #${order.quotationId}` : null,
    order.materialRequestId ? `material request #${order.materialRequestId}` : null,
  ].filter(Boolean)
  const description = links.length > 0 ? `Linked to ${links.join(' and ')}.` : 'Purchase order detail.'

  const infoRows = [
    ['Order date', order.orderDate || '—'],
    ['Expected delivery', order.expectedDeliveryDate || 'Not set'],
  ]
  if (showCommercials) {
    infoRows.push(['Total amount', order.totalAmount != null ? `LKR ${Number(order.totalAmount).toLocaleString()}` : '—'])
  }
  infoRows.push(['Created', order.createdAt ? new Date(order.createdAt).toLocaleString() : '—'])

  return (
    <div className="stack">
      <button type="button" className="proc-back" onClick={onBack}>
        ← Back to purchase orders
      </button>
      <PageHeader
        eyebrow={`PO-${order.id}`}
        title={order.supplierName || `Purchase Order #${order.id}`}
        description={description}
      />
      <div className="actions">
        <StatusBadge status={statusTone(order.status)}>{order.status}</StatusBadge>
      </div>

      <div className="stack">
        <Card title="Order information">
          {infoRows.map(([label, value]) => (
            <div className="detail-row" key={label}>
              <span className="detail-row__label">{label}</span>
              <span className="detail-row__value">{value}</span>
            </div>
          ))}
        </Card>
      </div>

      <Card title="Order items">
        <div className="table-wrap">
          <table className="data-table">
            <thead>
              <tr>
                <th>Material</th>
                <th>Quantity</th>
                {showCommercials && <th>Unit price</th>}
                {showCommercials && <th>Line total</th>}
              </tr>
            </thead>
            <tbody>
              {(order.items || []).map((item) => (
                <tr key={item.id}>
                  <td><strong>{item.materialName}</strong></td>
                  <td>{item.orderedQuantity} {item.unit}</td>
                  {showCommercials && (
                    <td>{item.unitPrice != null ? `LKR ${Number(item.unitPrice).toLocaleString()}` : '—'}</td>
                  )}
                  {showCommercials && (
                    <td>{item.lineTotal != null ? `LKR ${Number(item.lineTotal).toLocaleString()}` : '—'}</td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>
    </div>
  )
}
