// chrome.jsx — shared design tokens, window chrome, icons, and UI atoms
// Exports to window: tok, UI, MONO, MacFrame, and atoms (Label, Field, Dropdown,
// Segmented, Btn, Checkbox, ModelChip, Disclosure) + Icon.* glyphs.

const UI = '-apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro Display", "Helvetica Neue", sans-serif';
const MONO = '"SF Mono", ui-monospace, "JetBrains Mono", Menlo, monospace';

// ── Tokens ──────────────────────────────────────────────────────────────
function tok(mode) {
  const dark = mode === 'dark';
  return {
    dark,
    appBg:      dark ? '#1c1c1e' : '#ffffff',
    canvasBg:   dark ? '#161618' : '#fbfbfd',
    panel:      dark ? '#2c2c2e' : '#f5f5f7',
    panelSoft:  dark ? '#202022' : '#fafafa',
    surface:    dark ? '#242426' : '#ffffff',
    inputBg:    dark ? '#212123' : '#ffffff',
    border:     dark ? 'rgba(255,255,255,0.10)' : 'rgba(0,0,0,0.08)',
    borderMid:  dark ? 'rgba(255,255,255,0.16)' : 'rgba(0,0,0,0.13)',
    hair:       dark ? 'rgba(255,255,255,0.07)' : 'rgba(0,0,0,0.06)',
    text:       dark ? '#f5f5f7' : '#1d1d1f',
    text2:      dark ? '#a1a1a6' : '#6e6e73',
    text3:      dark ? '#6e6e73' : '#9b9ba1',
    accent:     '#0a6cff',
    accentText: '#ffffff',
    accentSoft: dark ? 'rgba(10,108,255,0.22)' : 'rgba(10,108,255,0.10)',
    accentLine: dark ? 'rgba(10,108,255,0.5)'  : 'rgba(10,108,255,0.35)',
    online:     '#30d158',
    titlebar:   dark ? '#2a2a2c' : '#f6f6f8',
    shadow:     dark ? '0 24px 70px rgba(0,0,0,0.55)' : '0 26px 64px rgba(0,0,0,0.13)',
  };
}

// ── Icons ───────────────────────────────────────────────────────────────
const Icon = {
  pencil: (c, s = 16) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M4 20l1-4L16 5l3 3L8 19l-4 1z" stroke={c} strokeWidth="1.6" strokeLinejoin="round"/>
      <path d="M14.5 6.5l3 3" stroke={c} strokeWidth="1.6"/>
    </svg>
  ),
  brackets: (c, s = 16) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M8 4C5.5 6.5 5.5 17.5 8 20" stroke={c} strokeWidth="1.6" strokeLinecap="round"/>
      <path d="M16 4c2.5 2.5 2.5 13.5 0 16" stroke={c} strokeWidth="1.6" strokeLinecap="round"/>
    </svg>
  ),
  mic: (c, s = 16) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <rect x="9" y="3" width="6" height="11" rx="3" stroke={c} strokeWidth="1.6"/>
      <path d="M5.5 11a6.5 6.5 0 0013 0" stroke={c} strokeWidth="1.6" strokeLinecap="round"/>
      <path d="M12 17.5V21M9 21h6" stroke={c} strokeWidth="1.6" strokeLinecap="round"/>
    </svg>
  ),
  chevron: (c, s = 14) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M7 10l5 5 5-5" stroke={c} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  ),
  caret: (c, s = 12) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M9 6l6 6-6 6" stroke={c} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  ),
  copy: (c, s = 15) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <rect x="9" y="9" width="11" height="11" rx="2.5" stroke={c} strokeWidth="1.6"/>
      <path d="M5 15V6a2 2 0 012-2h8" stroke={c} strokeWidth="1.6" strokeLinecap="round"/>
    </svg>
  ),
  check: (c, s = 13) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M5 12.5l4 4 10-10" stroke={c} strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  ),
  help: (c, s = 15) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <circle cx="12" cy="12" r="9" stroke={c} strokeWidth="1.5"/>
      <path d="M9.4 9.2c.2-1.4 1.3-2.2 2.6-2.2 1.4 0 2.5.8 2.5 2.1 0 1.6-1.7 1.8-2.4 3" stroke={c} strokeWidth="1.5" strokeLinecap="round"/>
      <circle cx="12" cy="16.4" r="0.9" fill={c}/>
    </svg>
  ),
  arrow: (c, s = 18) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M4 12h15M13 6l6 6-6 6" stroke={c} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  ),
  spark: (c, s = 15) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M12 3l1.6 5.4L19 10l-5.4 1.6L12 17l-1.6-5.4L5 10l5.4-1.6L12 3z" stroke={c} strokeWidth="1.4" strokeLinejoin="round"/>
    </svg>
  ),
  clock: (c, s = 14) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <circle cx="12" cy="12" r="9" stroke={c} strokeWidth="1.6"/>
      <path d="M12 7v5l3.5 2" stroke={c} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  ),
  sun: (c, s = 15) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <circle cx="12" cy="12" r="4" stroke={c} strokeWidth="1.6"/>
      <path d="M12 2v2M12 20v2M4 12H2M22 12h-2M5 5l1.5 1.5M17.5 17.5L19 19M19 5l-1.5 1.5M6.5 17.5L5 19" stroke={c} strokeWidth="1.6" strokeLinecap="round"/>
    </svg>
  ),
  moon: (c, s = 15) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M20 14.5A8 8 0 119.5 4a6.5 6.5 0 0010.5 10.5z" stroke={c} strokeWidth="1.6" strokeLinejoin="round"/>
    </svg>
  ),
  reply: (c, s = 13) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M9 7L4 12l5 5M4 12h10a5 5 0 015 5v1" stroke={c} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  ),
};

// ── Window chrome ───────────────────────────────────────────────────────
function TrafficLights() {
  const dot = (bg) => (
    <div style={{ width: 12, height: 12, borderRadius: '50%', background: bg }} />
  );
  return (
    <div style={{ display: 'flex', gap: 8 }}>
      {dot('#ff5f57')}{dot('#febc2e')}{dot('#28c840')}
    </div>
  );
}

function MacFrame({ width, height, mode, title, children, titleRight }) {
  const t = tok(mode);
  return (
    <div style={{
      width, height, borderRadius: 12, overflow: 'hidden', background: t.appBg,
      border: `0.5px solid ${t.dark ? 'rgba(255,255,255,0.14)' : 'rgba(0,0,0,0.10)'}`,
      boxShadow: t.shadow, display: 'flex', flexDirection: 'column', fontFamily: UI,
    }}>
      <div style={{
        height: 42, flexShrink: 0, display: 'flex', alignItems: 'center',
        padding: '0 14px', background: t.titlebar,
        borderBottom: `0.5px solid ${t.border}`, position: 'relative',
      }}>
        <TrafficLights />
        <div style={{
          position: 'absolute', left: 0, right: 0, textAlign: 'center',
          fontSize: 13, fontWeight: 600, color: t.text2, letterSpacing: '-0.01em',
          pointerEvents: 'none',
        }}>{title}</div>
        <div style={{ marginLeft: 'auto', position: 'relative', zIndex: 1 }}>{titleRight}</div>
      </div>
      <div style={{ flex: 1, overflow: 'hidden', background: t.appBg, minHeight: 0 }}>
        {children}
      </div>
    </div>
  );
}

// ── Atoms ───────────────────────────────────────────────────────────────
function Label({ t, children, right }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 9 }}>
      <span style={{
        fontSize: 10.5, fontWeight: 600, letterSpacing: '0.09em',
        textTransform: 'uppercase', color: t.text3,
      }}>{children}</span>
      {right}
    </div>
  );
}

function ModelChip({ t, status = 'ready' }) {
  const cfg = {
    ready:      { c: t.online,   ring: 'rgba(48,209,88,0.16)',  label: 'gemma2:9b', pulse: false },
    generating: { c: '#9b9ba1',  ring: 'rgba(155,155,161,0.18)', label: 'Generating…', pulse: true },
    offline:    { c: '#ff453a',  ring: 'rgba(255,69,58,0.16)',  label: 'Offline',   pulse: false },
  }[status];
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
      <span className={cfg.pulse ? 'vp-pulse' : ''} style={{ width: 7, height: 7, borderRadius: '50%',
        background: cfg.c, boxShadow: `0 0 0 3px ${cfg.ring}` }} />
      <span style={{ fontFamily: MONO, fontSize: 12, color: status === 'offline' ? '#ff453a' : t.text2, letterSpacing: '-0.01em' }}>{cfg.label}</span>
    </div>
  );
}

function Dropdown({ t, value, w }) {
  return (
    <div style={{
      height: 36, width: w, display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '0 11px 0 13px', borderRadius: 9, background: t.inputBg,
      border: `0.5px solid ${t.borderMid}`, fontSize: 13.5, color: t.text, fontWeight: 450,
      boxShadow: t.dark ? 'none' : '0 1px 1.5px rgba(0,0,0,0.04)',
    }}>
      <span style={{ whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{value}</span>
      {Icon.chevron(t.text3, 15)}
    </div>
  );
}

function Segmented({ t, options, active }) {
  return (
    <div style={{
      display: 'flex', height: 36, padding: 3, borderRadius: 9,
      background: t.panel, border: `0.5px solid ${t.border}`, gap: 2,
    }}>
      {options.map((o) => {
        const on = o === active;
        return (
          <div key={o} style={{
            flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 12.5, fontWeight: on ? 590 : 460, borderRadius: 7,
            color: on ? t.text : t.text2, whiteSpace: 'nowrap', padding: '0 12px',
            background: on ? t.surface : 'transparent',
            boxShadow: on ? (t.dark ? '0 1px 2px rgba(0,0,0,0.4)' : '0 1px 2px rgba(0,0,0,0.10)') : 'none',
          }}>{o}</div>
        );
      })}
    </div>
  );
}

function Btn({ t, kind = 'secondary', children, icon, hint, w, h = 36 }) {
  const base = {
    height: h, width: w, display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
    gap: 7, borderRadius: 9, fontSize: 13.5, fontWeight: 560, padding: '0 16px',
    whiteSpace: 'nowrap', letterSpacing: '-0.01em',
  };
  const styles = {
    primary: { ...base, background: t.accent, color: '#fff',
      boxShadow: '0 1px 2px rgba(10,108,255,0.35), inset 0 1px 0 rgba(255,255,255,0.18)' },
    secondary: { ...base, background: t.surface, color: t.text,
      border: `0.5px solid ${t.borderMid}`, boxShadow: t.dark ? 'none' : '0 1px 1.5px rgba(0,0,0,0.04)' },
    ghost: { ...base, background: 'transparent', color: t.text2 },
  };
  return (
    <div style={styles[kind]}>
      {icon}
      <span>{children}</span>
      {hint && <span style={{ fontFamily: MONO, fontSize: 12, opacity: 0.72, marginLeft: 2 }}>{hint}</span>}
    </div>
  );
}

function IconBtn({ t, glyph, size = 34 }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: 9, display: 'flex', alignItems: 'center',
      justifyContent: 'center', border: `0.5px solid ${t.borderMid}`, background: t.surface,
    }}>{glyph}</div>
  );
}

function Checkbox({ t, label, checked }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
      <div style={{
        width: 17, height: 17, borderRadius: 5, display: 'flex', alignItems: 'center', justifyContent: 'center',
        background: checked ? t.accent : 'transparent',
        border: checked ? 'none' : `1.2px solid ${t.borderMid}`,
      }}>{checked && Icon.check('#fff', 12)}</div>
      <span style={{ fontSize: 13, color: t.text2 }}>{label}</span>
    </div>
  );
}

Object.assign(window, {
  UI, MONO, tok, Icon, MacFrame, TrafficLights,
  Label, ModelChip, Dropdown, Segmented, Btn, IconBtn, Checkbox,
});
