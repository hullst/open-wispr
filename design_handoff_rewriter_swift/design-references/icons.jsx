// icons.jsx — Rewriter icon system: app-icon (squircle) explorations, glyph set, menu-bar
// Exports to window: AppIcon, MARKS, IconShowcase, MenuBar

// True Apple-style squircle (superellipse) path for CSS clip-path, in px space.
function squircle(size, n = 4.8) {
  const a = size / 2, N = 80, pts = [];
  for (let i = 0; i <= N; i++) {
    const th = (2 * Math.PI * i) / N;
    const c = Math.cos(th), s = Math.sin(th);
    const x = a + a * Math.sign(c) * Math.pow(Math.abs(c), 2 / n);
    const y = a + a * Math.sign(s) * Math.pow(Math.abs(s), 2 / n);
    pts.push((i ? 'L' : 'M') + x.toFixed(2) + ' ' + y.toFixed(2));
  }
  return pts.join(' ') + ' Z';
}

// ── Marks (drawn in a 100×100 viewBox) ──────────────────────────────────
const MARKS = {
  // pencil at -38°, optional brackets
  pencil: (c, { brackets = true, accent } = {}) => (
    <g>
      {brackets && <g stroke={c} strokeWidth="5.5" strokeLinecap="round" fill="none" opacity="0.92">
        <path d="M30 24 C 18 40, 18 60, 30 76" />
        <path d="M70 24 C 82 40, 82 60, 70 76" />
      </g>}
      <g transform="rotate(-38 50 50)">
        <rect x="43" y="30" width="14" height="34" rx="3.5" fill={c} />
        <polygon points="43,30 57,30 50,17" fill={c} />
        <polygon points="46.5,23.5 53.5,23.5 50,17" fill={accent || '#fff'} opacity={accent ? 1 : 0.0} />
        <rect x="43" y="58" width="14" height="6" rx="1" fill={accent || c} opacity={accent ? 0.9 : 0.55} />
      </g>
    </g>
  ),
  // fountain-pen nib
  nib: (c, { accent } = {}) => (
    <g>
      <path d="M50 16 C 63 31, 67 54, 50 86 C 33 54, 37 31, 50 16 Z" fill={c} />
      <line x1="50" y1="40" x2="50" y2="74" stroke={accent || '#0a6cff'} strokeWidth="3.4" strokeLinecap="round" />
      <circle cx="50" cy="35" r="4.2" fill={accent || '#0a6cff'} />
    </g>
  ),
  // parentheses embracing messy→clean lines
  brackets: (c, { accent } = {}) => (
    <g fill="none" strokeLinecap="round">
      <path d="M30 22 C 18 40, 18 60, 30 78" stroke={c} strokeWidth="5.5" />
      <path d="M70 22 C 82 40, 82 60, 70 78" stroke={c} strokeWidth="5.5" />
      <path d="M40 40 q 5 -5 10 0 t 10 0" stroke={c} strokeWidth="4.5" opacity="0.55" />
      <path d="M40 51 q 5 -3 10 0 t 10 0" stroke={c} strokeWidth="4.5" opacity="0.8" />
      <line x1="40" y1="61" x2="60" y2="61" stroke={accent || c} strokeWidth="4.5" />
    </g>
  ),
  // squiggle resolving into a clean line + sparkle
  transform: (c, { accent } = {}) => (
    <g fill="none" strokeLinecap="round">
      <path d="M22 44 q 6 -9 12 0 t 12 0 t 12 0" stroke={c} strokeWidth="5" opacity="0.6" />
      <line x1="22" y1="64" x2="70" y2="64" stroke={c} strokeWidth="5.5" />
      <path d="M74 26 l 2.6 7 7 2.6 -7 2.6 -2.6 7 -2.6 -7 -7 -2.6 7 -2.6 z" fill={accent || c} stroke="none" />
    </g>
  ),
};

// ── App icon tile (true squircle, depth / flat / glass finishes) ────────
function AppIcon({ size = 200, bg, finish = 'depth', mark, markColor = '#fff', markOpts = {} }) {
  const path = squircle(size);
  const overlays = [];
  if (finish === 'depth') {
    overlays.push(
      <div key="hi" style={{ position: 'absolute', inset: 0,
        background: 'linear-gradient(180deg, rgba(255,255,255,0.28) 0%, rgba(255,255,255,0) 42%)' }} />,
      <div key="sh" style={{ position: 'absolute', inset: 0,
        boxShadow: 'inset 0 -' + (size * 0.06) + 'px ' + (size * 0.12) + 'px rgba(0,0,0,0.18), inset 0 0 0 1px rgba(255,255,255,0.10)' }} />,
    );
  } else if (finish === 'glass') {
    overlays.push(
      <div key="g" style={{ position: 'absolute', inset: 0,
        background: 'linear-gradient(150deg, rgba(255,255,255,0.55), rgba(255,255,255,0.12) 55%)',
        boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.8), inset 0 0 0 1px rgba(255,255,255,0.5)' }} />,
    );
  } else {
    overlays.push(<div key="f" style={{ position: 'absolute', inset: 0, boxShadow: 'inset 0 0 0 1px rgba(0,0,0,0.04)' }} />);
  }
  return (
    <div style={{ filter: `drop-shadow(0 ${size * 0.05}px ${size * 0.12}px rgba(0,0,0,0.22))` }}>
      <div style={{ width: size, height: size, position: 'relative', background: bg,
        clipPath: `path('${path}')`, WebkitClipPath: `path('${path}')` }}>
        {overlays}
        <svg viewBox="0 0 100 100" width={size} height={size} style={{ position: 'absolute', inset: 0 }}>
          {mark(markColor, markOpts)}
        </svg>
      </div>
    </div>
  );
}

// One labelled app-icon option: big tile + scaled-down row
function AppOption({ title, sub, bg, finish, mark, markColor, markOpts }) {
  const small = [64, 32, 16];
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 18, width: 248,
      fontFamily: UI }}>
      <AppIcon size={196} bg={bg} finish={finish} mark={mark} markColor={markColor} markOpts={markOpts} />
      <div style={{ textAlign: 'center' }}>
        <div style={{ fontSize: 14, fontWeight: 620, color: '#1d1d1f' }}>{title}</div>
        <div style={{ fontSize: 12, color: '#86868b', marginTop: 2 }}>{sub}</div>
      </div>
      <div style={{ display: 'flex', alignItems: 'flex-end', gap: 16, height: 64 }}>
        {small.map((s) => (
          <div key={s} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 7 }}>
            <AppIcon size={s} bg={bg} finish={finish === 'glass' ? 'glass' : finish} mark={mark} markColor={markColor} markOpts={markOpts} />
            <span style={{ fontFamily: MONO, fontSize: 9.5, color: '#b0b0b5' }}>{s}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
window.AppIcon = AppIcon; window.AppOption = AppOption; window.MARKS = MARKS; window.squircle = squircle;

// ── In-app glyph showcase ───────────────────────────────────────────────
// extra glyphs beyond chrome.jsx Icon set
const Glyph = {
  send: (c, s = 22) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none"><path d="M4 12l16-7-7 16-2.5-6.5L4 12z" stroke={c} strokeWidth="1.6" strokeLinejoin="round"/></svg>,
  trash: (c, s = 22) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none"><path d="M5 7h14M10 7V5h4v2M7 7l1 12h8l1-12" stroke={c} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/></svg>,
  gear: (c, s = 22) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="3" stroke={c} strokeWidth="1.6"/><path d="M12 2v3M12 19v3M22 12h-3M5 12H2M19 5l-2 2M7 17l-2 2M19 19l-2-2M7 7L5 5" stroke={c} strokeWidth="1.6" strokeLinecap="round"/></svg>,
  undo: (c, s = 22) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none"><path d="M8 8L4 12l4 4M4 12h10a5 5 0 010 10" stroke={c} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/></svg>,
  download: (c, s = 22) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none"><path d="M12 4v11M8 11l4 4 4-4M5 19h14" stroke={c} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/></svg>,
  wave: (c, s = 22) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none"><path d="M4 12h2M8 8v8M12 5v14M16 8v8M20 12h-2" stroke={c} strokeWidth="1.7" strokeLinecap="round"/></svg>,
};

function IconShowcase() {
  const ink = '#1d1d1f';
  const items = [
    ['Mic', Icon.mic(ink, 22)], ['Waveform', Glyph.wave(ink, 22)], ['Rewrite', MARKsvg('transform', ink)],
    ['Variants', Icon.spark(ink, 22)], ['Copy', Icon.copy(ink, 22)], ['Done', Icon.check(ink, 22)],
    ['Reply', Icon.reply(ink, 22)], ['History', Icon.clock(ink, 22)], ['Export', Glyph.download(ink, 22)],
    ['Send', Glyph.send(ink, 22)], ['Undo', Glyph.undo(ink, 22)], ['Clear', Glyph.trash(ink, 22)],
    ['Help', Icon.help(ink, 22)], ['Settings', Glyph.gear(ink, 22)], ['Light', Icon.sun(ink, 22)], ['Dark', Icon.moon(ink, 22)],
  ];
  return (
    <div style={{ width: 880, fontFamily: UI, background: '#fff', borderRadius: 16,
      border: '0.5px solid rgba(0,0,0,0.08)', boxShadow: '0 1px 2px rgba(0,0,0,0.03)', padding: 26 }}>
      <div style={{ fontSize: 11, fontWeight: 600, letterSpacing: '0.09em', textTransform: 'uppercase', color: '#9b9ba1', marginBottom: 20 }}>In-app glyphs · 1.6 stroke, 22px</div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(8, 1fr)', gap: 14 }}>
        {items.map(([label, g]) => (
          <div key={label} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 9,
            padding: '16px 6px', borderRadius: 12, border: '0.5px solid rgba(0,0,0,0.06)', background: '#fbfbfd' }}>
            {g}
            <span style={{ fontSize: 10.5, color: '#86868b' }}>{label}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
function MARKsvg(name, c) {
  return <svg width="22" height="22" viewBox="0 0 100 100">{MARKS[name](c, {})}</svg>;
}
window.IconShowcase = IconShowcase;

// ── Menu-bar template (monochrome) ──────────────────────────────────────
function MenuBar({ dark }) {
  const fg = dark ? 'rgba(255,255,255,0.92)' : 'rgba(0,0,0,0.82)';
  const bg = dark ? '#2b2b2d' : '#f3f3f4';
  return (
    <div style={{ width: 640, fontFamily: UI }}>
      <div style={{ height: 40, borderRadius: 10, background: bg, display: 'flex', alignItems: 'center',
        padding: '0 16px', gap: 20, border: `0.5px solid ${dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.08)'}`,
        boxShadow: '0 1px 2px rgba(0,0,0,0.06)' }}>
        <span style={{ fontSize: 13, fontWeight: 600, color: fg }}></span>
        <div style={{ flex: 1 }} />
        <span style={{ fontSize: 12.5, color: fg, opacity: 0.7 }}>100%</span>
        <span style={{ fontSize: 12.5, color: fg, opacity: 0.7 }}>Wed 3:24</span>
        {/* tray icon */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
          <svg width="17" height="17" viewBox="0 0 100 100">{MARKS.pencil(fg, { brackets: true })}</svg>
        </div>
      </div>
      <div style={{ fontSize: 11.5, color: '#9b9ba1', marginTop: 10, textAlign: 'center' }}>
        {dark ? 'Dark menu bar · white template' : 'Light menu bar · black template'}
      </div>
    </div>
  );
}
window.MenuBar = MenuBar;
