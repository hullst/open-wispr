// screen.jsx — spec-complete Rewriter column in the redesign language.
// <Screen mode state /> covers every state in the brief. Also exports ToastShowcase.

function Screen({ mode = 'light', state = 'result' }) {
  const t = tok(mode);
  const S = state;
  const fullInput = "so um i was thinking like maybe we could uh push the launch to next week cuz the QA stuff isnt really done and i dont wanna ship something thats gonna break for people you know";
  const partialInput = "so um i was thinking like maybe we could uh push the launch to next week cuz the QA stuff isnt really";
  const output = "I think we should push the launch to next week. QA isn't quite finished, and I'd rather not ship something that breaks for people.";
  const streaming = "I think we should push the launch to next week. QA isn't quite";

  const showInput = !['empty', 'transcribing'].includes(S);
  const inputText = S === 'recording' ? partialInput : showInput ? fullInput : '';
  const recording = S === 'recording';
  const transcribing = S === 'transcribing';
  const rewriting = S === 'rewriting';
  const offline = S === 'offline';
  const isVariants = S === 'variants';
  const isHistory = S === 'history';
  const replyingOpen = S === 'replying';
  const modal = S === 'modal';
  const hasResult = ['result', 'variants', 'history', 'modal', 'replying'].includes(S);
  const status = rewriting ? 'generating' : offline ? 'offline' : 'ready';
  const fixedOutput = isVariants || isHistory;

  const height = isHistory ? 952 : isVariants ? 912 : replyingOpen ? 856 : 772;

  const pill = { height: 30, display: 'inline-flex', alignItems: 'center', gap: 7, padding: '0 11px',
    borderRadius: 8, border: `0.5px solid ${t.borderMid}`, background: t.surface, fontSize: 12.5, color: t.text2, fontWeight: 500 };
  const badge = (txt) => <span style={{ fontSize: 10, fontWeight: 600, color: t.text2, background: t.panel,
    border: `0.5px solid ${t.border}`, borderRadius: 5, padding: '2px 7px' }}>{txt}</span>;

  // ── input region ──
  const inputBox = (
    <div style={{ marginTop: 18 }}>
      <Label t={t} right={
        recording
          ? <span style={{ display: 'flex', alignItems: 'center', gap: 6, fontFamily: MONO, fontSize: 11.5, color: '#ff453a' }}>
              <span className="vp-pulse" style={{ width: 7, height: 7, borderRadius: '50%', background: '#ff453a' }} />Recording · 0:23</span>
          : transcribing
            ? <span style={{ fontFamily: MONO, fontSize: 11.5, color: t.accent }}>Transcribing…</span>
            : <span style={{ fontFamily: MONO, fontSize: 11.5, color: t.text3 }}>{inputText.length} chars</span>
      }>Input</Label>
      <div style={{ position: 'relative', borderRadius: 12, background: t.inputBg,
        borderLeft: recording ? '3px solid #ff453a' : `0.5px solid ${t.borderMid}`,
        border: recording ? undefined : `0.5px solid ${t.borderMid}`,
        boxShadow: recording ? '0 0 0 3px rgba(255,69,58,0.08)' : (t.dark ? 'none' : '0 1px 2px rgba(0,0,0,0.03)') }}>
        <div style={{ padding: '15px 16px', minHeight: 92, fontSize: 14.5, lineHeight: 1.55,
          color: showInput ? t.text : t.text3, fontWeight: 450, fontStyle: transcribing ? 'italic' : 'normal' }}>
          {transcribing ? 'Transcribing…' : showInput ? inputText : 'Paste your garbled voice-to-text here… or click the mic to dictate'}
          {recording && <span className="vp-caret" style={{ display: 'inline-block', width: 2, height: 16, background: '#ff453a', marginLeft: 2, verticalAlign: 'text-bottom' }} />}
        </div>
        {recording ? (
          <div style={{ position: 'absolute', right: 12, bottom: 12, display: 'flex', alignItems: 'center', gap: 8 }}>
            <div style={{ display: 'flex', alignItems: 'flex-end', gap: 2, height: 18 }}>
              {[10, 16, 7, 14, 9].map((h, i) => <span key={i} className="vp-eq" style={{ width: 2.5, height: h, borderRadius: 2, background: '#ff453a', animationDelay: `${i * 0.12}s` }} />)}
            </div>
            <div style={{ width: 36, height: 36, borderRadius: '50%', background: '#ff453a', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <div style={{ width: 12, height: 12, borderRadius: 3, background: '#fff' }} />
            </div>
          </div>
        ) : (
          <div className={transcribing ? 'vp-pulse' : ''} style={{ position: 'absolute', right: 12, bottom: 12, width: 36, height: 36, borderRadius: '50%',
            background: t.accentSoft, border: `0.5px solid ${t.accentLine}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            {Icon.mic(t.accent, 16)}
          </div>
        )}
      </div>
    </div>
  );

  // ── output region content ──
  const outputInner = rewriting
    ? <span>{streaming}<span className="vp-caret" style={{ display: 'inline-block', width: 2, height: 17, background: t.accent, marginLeft: 1, verticalAlign: 'text-bottom' }} /></span>
    : hasResult ? output
    : recording ? 'Listening… release the mic, then Rewrite.'
    : transcribing ? 'Transcribing your dictation…'
    : 'Clean version will appear here…';
  const outputFilled = rewriting || hasResult;

  const outputBox = (
    <div className={rewriting ? 'vp-streamborder' : ''} style={{
      borderRadius: 12, padding: '15px 16px',
      height: fixedOutput ? 86 : undefined, flex: fixedOutput ? '0 0 auto' : 1, overflow: 'hidden',
      background: outputFilled && !rewriting ? t.accentSoft : t.panelSoft,
      border: `0.5px solid ${outputFilled && !rewriting ? t.accentLine : t.border}`,
      fontSize: 15, lineHeight: 1.6, color: outputFilled ? t.text : t.text3,
      fontWeight: 450, fontStyle: outputFilled ? 'normal' : 'italic' }}>
      {outputInner}
    </div>
  );

  // ── variants grid ──
  const variantCards = [
    { tag: 'Direct', text: "Let's push the launch to next week — QA isn't done.", on: false },
    { tag: 'Warmer', text: "I think we should push the launch to next week. QA isn't quite finished.", on: true },
    { tag: 'Shorter', text: "Let's move the launch a week — QA needs more time.", on: false },
  ];
  const variantsGrid = (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minHeight: 0, marginTop: 16 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
        <span style={{ fontSize: 10.5, fontWeight: 600, letterSpacing: '0.09em', textTransform: 'uppercase', color: t.text3 }}>Variants</span>
        <span style={{ fontSize: 12.5, color: t.text2 }}>Close</span>
      </div>
      <div style={{ flex: 1, display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 10 }}>
        {variantCards.map((v) => (
          <div key={v.tag} style={{ borderRadius: 11, padding: '12px 13px', display: 'flex', flexDirection: 'column', gap: 8,
            background: v.on ? t.accentSoft : t.panelSoft, border: `${v.on ? 1.5 : 0.5}px solid ${v.on ? t.accent : t.border}` }}>
            <span style={{ fontSize: 10, fontWeight: 600, letterSpacing: '0.06em', textTransform: 'uppercase', color: v.on ? t.accent : t.text3 }}>{v.tag}</span>
            <span style={{ fontSize: 13, lineHeight: 1.5, color: t.text, fontWeight: 450, flex: 1 }}>{v.text}</span>
            <span style={{ fontSize: 11, color: v.on ? t.accent : t.text3 }}>{v.on ? '✓ Applied' : 'Click to use'}</span>
          </div>
        ))}
      </div>
    </div>
  );

  // ── history list ──
  const historyItems = [
    { time: 'Jun 4, 2:14 PM', voice: true, style: 'Informal', inp: 'so um i was thinking like maybe we could push the launch…', out: "I think we should push the launch to next week. QA isn't quite finished." },
    { time: 'Jun 4, 11:02 AM', voice: false, style: 'Formal', inp: 'hey can u send me that doc when u get a sec thx', out: 'Could you send me that document when you have a moment? Thank you.' },
  ];
  const historyList = (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minHeight: 0, marginTop: 16, paddingTop: 16, borderTop: `0.5px solid ${t.hair}` }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12 }}>
        {Icon.clock(t.text3, 14)}
        <span style={{ fontSize: 11.5, fontWeight: 600, letterSpacing: '0.06em', textTransform: 'uppercase', color: t.text3 }}>History</span>
        <span style={{ fontFamily: MONO, fontSize: 11.5, color: t.text3 }}>2</span>
        <div style={{ marginLeft: 'auto', display: 'flex', gap: 18, fontSize: 12.5, color: t.text2 }}><span>Export</span><span>Clear all</span></div>
      </div>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 10, overflow: 'hidden' }}>
        {historyItems.map((h, i) => (
          <div key={i} style={{ borderRadius: 11, padding: '13px 15px', background: t.panelSoft, border: `0.5px solid ${t.border}` }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
              <span style={{ fontFamily: MONO, fontSize: 11, color: t.text3 }}>{h.time}</span>
              {h.voice && Icon.mic(t.text3, 12)}
              {badge(h.style)}{badge('gemma2:9b')}
            </div>
            <div style={{ fontSize: 12.5, color: t.text2, lineHeight: 1.45, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{h.inp}</div>
            <div style={{ borderTop: `1px dashed ${t.border}`, margin: '9px 0' }} />
            <div style={{ fontSize: 12.5, color: t.text, lineHeight: 1.45 }}>{h.out}</div>
          </div>
        ))}
      </div>
    </div>
  );

  // ── actions ──
  const variantsBtn = isVariants
    ? <div style={{ height: 36, display: 'inline-flex', alignItems: 'center', gap: 7, padding: '0 16px', borderRadius: 9, fontSize: 13.5, fontWeight: 560, color: t.accent, background: t.accentSoft, border: `0.5px solid ${t.accentLine}` }}>{Icon.spark(t.accent, 15)}<span>Variants</span></div>
    : <div style={{ opacity: hasResult ? 1 : 0.4 }}><Btn t={t} kind="secondary" icon={Icon.spark(t.text2, 15)}>Variants</Btn></div>;
  const rewriteBtn = rewriting
    ? <div style={{ height: 36, display: 'inline-flex', alignItems: 'center', gap: 8, padding: '0 16px', borderRadius: 9, fontSize: 13.5, fontWeight: 560, color: '#fff', background: t.accent, opacity: 0.85 }}><span className="vp-spin" style={{ width: 13, height: 13, borderRadius: '50%', border: '2px solid rgba(255,255,255,0.4)', borderTopColor: '#fff' }} />Rewriting…</div>
    : <Btn t={t} kind="primary" hint="⌘↵">Rewrite</Btn>;

  return (
    <MacFrame width={600} height={height} mode={mode} title="Rewriter">
      <div style={{ padding: '22px 28px 0', height: '100%', boxSizing: 'border-box', display: 'flex', flexDirection: 'column', background: t.appBg, position: 'relative' }}>
        {/* header */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <ModelChip t={t} status={status} />
          <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
            <div style={pill}>{Icon.mic(t.text2, 14)}<span>Default Mic</span>{Icon.chevron(t.text3, 13)}</div>
            <div style={{ width: 30, height: 30, borderRadius: 8, border: `0.5px solid ${t.borderMid}`, background: t.surface, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{t.dark ? Icon.moon(t.text2, 15) : Icon.sun(t.text2, 15)}</div>
          </div>
        </div>

        {/* replying to */}
        <div style={{ marginTop: 18, paddingBottom: replyingOpen ? 0 : 16, borderBottom: replyingOpen ? 'none' : `0.5px solid ${t.hair}` }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, color: t.text3 }}>
            {Icon.reply(t.text3, 13)}
            <span style={{ fontSize: 11.5, fontWeight: 600, letterSpacing: '0.06em', textTransform: 'uppercase' }}>Replying to</span>
            {replyingOpen && <span style={{ fontSize: 11, color: t.accent, fontWeight: 600 }}>· active</span>}
            {!replyingOpen && <span style={{ fontSize: 12.5, color: t.text3, fontWeight: 450 }}>— nothing yet</span>}
            <span style={{ marginLeft: 'auto', transform: replyingOpen ? 'rotate(180deg)' : 'none' }}>{Icon.chevron(t.text3, 14)}</span>
          </div>
          {replyingOpen && (
            <div style={{ marginTop: 10, marginBottom: 16 }}>
              <div style={{ borderRadius: 10, background: t.panelSoft, border: `0.5px solid ${t.border}`, padding: '12px 14px', fontSize: 13.5, color: t.text2, lineHeight: 1.5 }}>
                Hey — are we still good to launch Thursday? Want to make sure QA signed off before I tell the team.
              </div>
              <div style={{ fontSize: 11.5, color: t.text3, marginTop: 7 }}>Optional. Helps the model write a direct reply instead of a standalone message.</div>
            </div>
          )}
        </div>

        {inputBox}

        {/* style + length */}
        <div style={{ display: 'flex', gap: 14, marginTop: 18 }}>
          <div style={{ flex: 1.15 }}>
            <Label t={t}>Style</Label>
            <div style={{ display: 'flex', gap: 8 }}>
              <div style={{ flex: 1 }}><Dropdown t={t} value="Informal (Everyday)" w="100%" /></div>
              <IconBtn t={t} glyph={<span style={{ fontSize: 19, color: t.text2, fontWeight: 300, lineHeight: 1 }}>+</span>} size={36} />
            </div>
          </div>
          <div style={{ flex: 1 }}>
            <Label t={t}>Length</Label>
            <Segmented t={t} options={['Shorter', 'Same', 'Longer']} active="Same" />
          </div>
        </div>
        <div style={{ fontSize: 11.5, color: t.text3, marginTop: 9, lineHeight: 1.4 }}>Warm, direct internal messages — uses contractions and a relaxed tone.</div>

        {/* actions */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 18 }}>
          {rewriteBtn}{variantsBtn}<Btn t={t} kind="ghost">Clear</Btn>
          <div style={{ marginLeft: 'auto' }}><IconBtn t={t} glyph={Icon.help(t.text2, 15)} size={36} /></div>
        </div>

        {/* error panel */}
        {offline && (
          <div style={{ marginTop: 16, borderLeft: '2px solid #ff453a', background: t.panelSoft, padding: '11px 14px', borderRadius: '0 8px 8px 0' }}>
            <div style={{ fontSize: 13, color: t.text, fontWeight: 500 }}>Couldn't reach Ollama.</div>
            <div style={{ fontSize: 12.5, color: t.text2, marginTop: 2, fontFamily: MONO }}>Is the model running?  ollama run gemma2:9b</div>
          </div>
        )}

        {/* output */}
        <div style={{ marginTop: 20, display: 'flex', flexDirection: 'column', flex: fixedOutput ? '0 0 auto' : 1, minHeight: 0 }}>
          <Label t={t} right={
            S === 'result' ? <span style={{ display: 'flex', alignItems: 'center', gap: 5, fontFamily: MONO, fontSize: 11, color: t.online }}>{Icon.check(t.online, 11)} 3.2s</span>
            : rewriting ? <span style={{ fontFamily: MONO, fontSize: 11, color: t.accent }}>streaming…</span> : null
          }>Output</Label>
          {outputBox}
        </div>

        {/* output footer */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 14 }}>
          <Btn t={t} kind="secondary" icon={Icon.copy(t.text, 15)}>Copy</Btn>
          <Checkbox t={t} label="Auto-copy" checked />
        </div>

        {isVariants && variantsGrid}
        {isHistory && historyList}

        {/* collapsed history (only when not expanded / variants) */}
        {!isHistory && !isVariants && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 16, padding: '14px 0', borderTop: `0.5px solid ${t.hair}`, color: t.text2 }}>
            {Icon.clock(t.text3, 14)}
            <span style={{ fontSize: 11.5, fontWeight: 600, letterSpacing: '0.06em', textTransform: 'uppercase', color: t.text3 }}>History</span>
            <span style={{ fontFamily: MONO, fontSize: 11.5, color: t.text3 }}>2</span>
            <div style={{ marginLeft: 'auto', display: 'flex', gap: 18, fontSize: 12.5, color: t.text2 }}><span>Export</span><span>Clear all</span></div>
          </div>
        )}

        {/* toast */}
        {S === 'result' && (
          <div style={{ position: 'absolute', left: 0, right: 0, bottom: 22, display: 'flex', justifyContent: 'center' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '9px 16px', borderRadius: 999, background: '#1d1d1f', color: '#fff', fontSize: 13, fontWeight: 500, boxShadow: '0 8px 24px rgba(0,0,0,0.25)' }}>
              {Icon.check('#30d158', 13)} Auto-copied to clipboard
            </div>
          </div>
        )}

        {/* custom style modal */}
        {modal && <CustomStyleModal t={t} />}
      </div>
    </MacFrame>
  );
}

function CustomStyleModal({ t }) {
  const field = (label, value, ph, area) => (
    <div style={{ marginBottom: 16 }}>
      <Label t={t}>{label}</Label>
      <div style={{ borderRadius: 9, background: t.inputBg, border: `0.5px solid ${t.borderMid}`, padding: area ? '11px 13px' : '0 13px',
        height: area ? 92 : 38, display: 'flex', alignItems: area ? 'flex-start' : 'center', fontSize: 13.5,
        color: value ? t.text : t.text3, lineHeight: 1.5, fontFamily: area ? MONO : UI }}>{value || ph}</div>
    </div>
  );
  return (
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.45)', backdropFilter: 'blur(3px)', WebkitBackdropFilter: 'blur(3px)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 28 }}>
      <div style={{ width: '100%', borderRadius: 14, background: t.appBg, border: `0.5px solid ${t.borderMid}`, boxShadow: '0 24px 60px rgba(0,0,0,0.4)', padding: 24 }}>
        <div style={{ fontSize: 16, fontWeight: 640, color: t.text, marginBottom: 18 }}>New custom style</div>
        {field('Name', 'Board Summary', 'e.g. Board Summary')}
        {field('Hint', 'Crisp executive summary, no fluff', 'Short description shown under the dropdown')}
        {field('Style Prompt', 'Style: Board Summary\n- Executive audience, lead with the decision\n- No filler, max 3 sentences', '', true)}
        <div style={{ fontSize: 11.5, color: t.text3, marginTop: -6, marginBottom: 18 }}>Written as instructions to the model. Start with “Style: Name”, then bullet the rules.</div>
        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10 }}>
          <Btn t={t} kind="ghost">Cancel</Btn>
          <Btn t={t} kind="primary">Save style</Btn>
        </div>
      </div>
    </div>
  );
}

function ToastShowcase() {
  const t = tok('light');
  const toasts = ['Copied to clipboard', 'Auto-copied to clipboard', 'Transcribed in 2.1s', 'Style saved', 'Variant applied', 'Loaded from history', 'History exported'];
  return (
    <div style={{ width: 460, fontFamily: UI, display: 'flex', flexDirection: 'column', gap: 12, alignItems: 'center', padding: 24 }}>
      {toasts.map((m) => (
        <div key={m} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '9px 16px', borderRadius: 999, background: '#1d1d1f', color: '#fff', fontSize: 13, fontWeight: 500, boxShadow: '0 8px 24px rgba(0,0,0,0.22)' }}>
          {Icon.check('#30d158', 13)} {m}
        </div>
      ))}
    </div>
  );
}

Object.assign(window, { Screen, CustomStyleModal, ToastShowcase });
