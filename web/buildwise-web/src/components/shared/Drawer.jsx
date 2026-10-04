import { useEffect } from 'react'

// Closes the panel on Escape. Kept separate so the Drawer stays declarative.
function useEscapeToClose(open, onClose) {
  useEffect(() => {
    if (!open) return
    const onKeyDown = (event) => { if (event.key === 'Escape') onClose() }
    document.addEventListener('keydown', onKeyDown)
    return () => document.removeEventListener('keydown', onKeyDown)
  }, [open, onClose])
}

/**
 * Detail panel for views that would otherwise occupy a whole page section
 * (delivery detail, non-conformance detail). Reuses the app's `.dialog-backdrop`
 * overlay so Escape and click-outside behave like every other modal.
 *
 * `placement` picks the layout:
 *   'center' (default) - a centred modal card, capped in height so it scrolls internally.
 *   'side'   - legacy full-height panel pinned to the right edge.
 *
 * `open` prop gates rendering — if false, nothing is mounted so the page
 * beneath is fully interactive and the white overlay bug is gone.
 */
export default function Drawer({ open, title, subtitle, onClose, children, footer, placement = 'center' }) {
  useEscapeToClose(open, onClose)

  // Do not mount at all when closed — avoids the "white panel always visible" bug
  if (!open) return null

  // A centred panel must be free inside the backdrop's centering grid, so the
  // side-panel overrides (stretch/zero padding/push right) apply only to 'side'.
  const isCentered = placement === 'center'

  return (
    <div
      className="dialog-backdrop"
      role="presentation"
      style={isCentered ? undefined : { alignItems: 'stretch', padding: 0 }}
      onMouseDown={(event) => event.target === event.currentTarget && onClose()}
    >
      <div
        className={isCentered ? 'app-drawer app-drawer--center' : 'app-drawer'}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        style={isCentered ? undefined : { marginLeft: 'auto' }}
      >
        <header className="app-drawer__head">
          <div>
            <h2>{title}</h2>
            {subtitle && <p>{subtitle}</p>}
          </div>
          <button
            type="button"
            className="app-drawer__close-btn"
            onClick={onClose}
            aria-label="Close"
            title="Close"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
              <line x1="18" y1="6" x2="6" y2="18" />
              <line x1="6" y1="6" x2="18" y2="18" />
            </svg>
          </button>
        </header>
        <div className="app-drawer__body">{children}</div>
        {footer && <div className="app-drawer__foot">{footer}</div>}
      </div>
    </div>
  )
}