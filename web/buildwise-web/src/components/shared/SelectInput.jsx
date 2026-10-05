export default function SelectInput({ label, options = [], id, error, ...props }) {
  const inputId = id || props.name
  return <label className="field" htmlFor={inputId}><span className="field__label">{label}</span><select id={inputId} className="field__control" aria-invalid={Boolean(error)} {...props}>{options.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}</select>{error ? <span className="field__error">{error}</span> : null}</label>
}
