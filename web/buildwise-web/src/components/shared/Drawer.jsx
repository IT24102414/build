import { useEffect } from 'react'
import Button from './Button'

// Closes the panel on Escape. Kept separate so the Drawer stays declarative.
function useEscapeToClose(onClose) {
  useEffect(() => {
    const onKeyDown = (event) => { if (event.key === 'Escape') onClose() }
    document.addEventListener('keydown', onKeyDown)
    return () => document.removeEventListener('keydown', onKeyDown)
  }, [onClose])
}

/**
 * Side panel for detail views that would otherwise occupy a whole page section
 * (delivery detail, non-conformance detail). Reuses the app's `.dialog-backdrop`
 * overlay so Escape and click-outside behave like every other modal.
 *
 * The panel forces its own single-column layout: its width is fixed and
 * unrelated to the viewport, so viewport media queries cannot lay it out
 * correctly on a wide monitor.
 */
export default function Drawer({ title, subtitle, onClose, children, footer }) {
  useEscapeToClose(onClose)
  return (
    <div
      className="dialog-backdrop"
      role="presentation"
      onMouseDown={(event) => event.target === event.currentTarget && onClose()}
    >
      <div className="app-drawer" role="dialog" aria-modal="true" aria-label={title}>
        <header className="app-drawer__head">
          <div>
            <h2>{title}</h2>
            {subtitle && <p>{subtitle}</p>}
          </div>
          <Button variant="secondary" onClick={onClose}>Close</Button>
        </header>
        <div className="app-drawer__body">{children}</div>
        {footer && <div className="app-drawer__foot">{footer}</div>}
      </div>
    </div>
  )
}