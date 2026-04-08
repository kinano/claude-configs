---
layout: default
title: Farty Bobo
---

<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  :root {
    --lime:    #97C459;
    --purple:  #7F77DD;
    --indigo:  #534AB7;
    --navy:    #26215C;
    --bg:      #0d0b1e;
    --bg2:     #120f28;
    --bg3:     #1a1640;
    --border:  #2e2860;
    --text:    #f0eeff;
    --sub:     #c4bef0;
    --dim:     #9089c4;
    --font-display: 'Bebas Neue', Impact, sans-serif;
    --font-body:    'JetBrains Mono', 'Courier New', monospace;
  }

  html, body { width: 100%; overflow-x: hidden; background: var(--bg); }

  .fb { font-family: var(--font-body); color: var(--text); background: var(--bg); }

  /* ── noise grain overlay ── */
  .fb::before {
    content: '';
    position: fixed;
    inset: 0;
    background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 200 200' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='1'/%3E%3C/svg%3E");
    opacity: 0.035;
    pointer-events: none;
    z-index: 0;
  }

  /* ── HERO ── */
  .fb-hero {
    position: relative;
    z-index: 1;
    width: 100%;
    min-height: 100svh;
    display: grid;
    grid-template-columns: 1fr auto;
    align-items: center;
    border-bottom: 2px solid var(--border);
    overflow: hidden;
  }

  /* radial glow behind mascot */
  .fb-hero::after {
    content: '';
    position: absolute;
    right: -5vw;
    top: 50%;
    transform: translateY(-50%);
    width: 60vw;
    height: 60vw;
    background: radial-gradient(ellipse, rgba(127,119,221,0.18) 0%, transparent 70%);
    pointer-events: none;
  }

  .fb-left {
    padding: 64px 5vw 64px 6vw;
    display: flex;
    flex-direction: column;
    gap: 0;
    z-index: 2;
  }

  .fb-wordmark {
    width: clamp(200px, 30vw, 480px);
    margin-bottom: 16px;
    opacity: 0;
    animation: fb-slide-up 0.6s cubic-bezier(0.22,1,0.36,1) 0.1s forwards;
  }

  .fb-tagline {
    font-family: var(--font-display);
    font-size: clamp(3.5rem, 8.5vw, 9rem);
    line-height: 0.92;
    color: var(--lime);
    text-transform: uppercase;
    letter-spacing: -0.01em;
    margin-bottom: 32px;
    opacity: 0;
    animation: fb-slam 0.5s cubic-bezier(0.22,1,0.36,1) 0.3s forwards;
  }

  .fb-desc {
    font-size: clamp(0.8rem, 1.3vw, 0.95rem);
    color: var(--sub);
    max-width: 440px;
    line-height: 1.8;
    opacity: 0;
    animation: fb-slide-up 0.6s cubic-bezier(0.22,1,0.36,1) 0.5s forwards;
  }

  .fb-desc a {
    color: var(--lime);
    text-decoration: none;
    border-bottom: 1px solid rgba(151,196,89,0.4);
  }
  .fb-desc a:hover { border-bottom-color: var(--lime); }

  /* mascot column */
  .fb-mascot-wrap {
    position: relative;
    z-index: 2;
    display: flex;
    align-items: flex-end;
    justify-content: flex-end;
    padding-right: 0;
    opacity: 0;
    animation: fb-mascot-in 0.7s cubic-bezier(0.22,1,0.36,1) 0.2s forwards;
  }

  .fb-mascot {
    width: clamp(280px, 36vw, 580px);
    display: block;
    filter: drop-shadow(0 0 60px rgba(127,119,221,0.5));
  }

  /* ── STRIPE ── */
  .fb-stripe {
    position: relative;
    z-index: 1;
    width: 100%;
    background: var(--purple);
    padding: 10px 6vw;
    overflow: hidden;
    white-space: nowrap;
  }

  .fb-marquee {
    display: inline-block;
    font-family: var(--font-display);
    font-size: 1.1rem;
    letter-spacing: 0.15em;
    color: var(--bg);
    animation: fb-marquee 18s linear infinite;
  }

  @keyframes fb-marquee {
    from { transform: translateX(0); }
    to   { transform: translateX(-50%); }
  }

  /* ── CONTENT ── */
  .fb-content {
    position: relative;
    z-index: 1;
    width: 100%;
    display: grid;
    grid-template-columns: 1fr 1fr;
  }

  .fb-section {
    background: var(--bg2);
    border-right: 1px solid var(--border);
    border-bottom: 1px solid var(--border);
    padding: 48px 5vw;
    transition: background 0.2s;
  }

  .fb-section:last-child { border-right: none; }
  .fb-section:hover { background: var(--bg3); }

  .fb-section h2 {
    font-family: var(--font-display);
    font-size: clamp(1.6rem, 2.5vw, 2.2rem);
    color: var(--lime);
    letter-spacing: 0.06em;
    text-transform: uppercase;
    margin-bottom: 24px;
    padding-bottom: 12px;
    border-bottom: 1px solid var(--border);
  }

  .fb-items { list-style: none; }

  .fb-items li {
    display: flex;
    gap: 20px;
    padding: 13px 0;
    border-bottom: 1px solid var(--border);
    font-size: clamp(0.78rem, 1vw, 0.85rem);
    line-height: 1.6;
  }

  .fb-items li:last-child { border-bottom: none; }

  .fb-item-key {
    flex: 0 0 120px;
    color: var(--purple);
    font-weight: 700;
  }

  .fb-item-val { color: var(--sub); }

  .fb-codeblock {
    background: #000;
    border: 1px solid var(--border);
    border-left: 3px solid var(--lime);
    padding: 20px 24px;
    font-size: clamp(0.75rem, 1vw, 0.82rem);
    line-height: 2.1;
    color: var(--sub);
    overflow-x: auto;
    margin-bottom: 28px;
  }

  .fb-codeblock .cmd { color: var(--lime); }
  .fb-codeblock .arg { color: var(--dim); }

  .fb-link {
    display: inline-block;
    font-family: var(--font-display);
    font-size: 1.15rem;
    letter-spacing: 0.1em;
    color: var(--bg);
    background: var(--lime);
    padding: 12px 32px;
    text-decoration: none;
    text-transform: uppercase;
    transition: background 0.15s, transform 0.15s;
  }
  .fb-link:hover { background: #aad96a; transform: translateY(-2px); }

  /* ── FOOTER ── */
  .fb-footer {
    position: relative;
    z-index: 1;
    width: 100%;
    text-align: center;
    padding: 20px;
    font-size: 0.65rem;
    color: var(--dim);
    border-top: 1px solid var(--border);
    letter-spacing: 0.14em;
    text-transform: uppercase;
  }

  /* ── ANIMATIONS ── */
  @keyframes fb-slide-up {
    from { opacity: 0; transform: translateY(24px); }
    to   { opacity: 1; transform: translateY(0); }
  }

  @keyframes fb-slam {
    from { opacity: 0; transform: translateY(40px) scaleY(1.04); }
    to   { opacity: 1; transform: translateY(0) scaleY(1); }
  }

  @keyframes fb-mascot-in {
    from { opacity: 0; transform: translateX(40px) rotate(3deg); }
    to   { opacity: 1; transform: translateX(0) rotate(0deg); }
  }

  /* ── MOBILE ── */
  @media (max-width: 720px) {
    .fb-hero {
      grid-template-columns: 1fr;
      grid-template-rows: auto auto;
      min-height: unset;
    }

    .fb-mascot-wrap {
      order: -1;
      justify-content: center;
      padding: 48px 0 0;
    }

    .fb-mascot { width: clamp(200px, 70vw, 340px); }

    .fb-left { padding: 32px 6vw 56px; }

    .fb-tagline { font-size: clamp(3rem, 14vw, 5rem); }

    .fb-desc { font-size: 0.9rem; max-width: 100%; }

    .fb-content { grid-template-columns: 1fr; }

    .fb-section { border-right: none; }

    .fb-item-key { flex: 0 0 100px; }

    .fb-items li { font-size: 0.85rem; }

    .fb-item-val { color: var(--text); }
  }
</style>

<div class="fb">

  <section class="fb-hero">
    <div class="fb-left">
      <img
        class="fb-wordmark"
        src="{{ '/logos/fartybobo_angry_wordmark.svg' | relative_url }}"
        alt="Farty Bobo"
      />
      <p class="fb-tagline">We Got the<br>F***ing Gas</p>
      <p class="fb-desc">
        Every machine you own is a different hellscape of broken configs and
        missing context. This fixes that. It's <a href="https://docs.anthropic.com/en/docs/claude-code">Claude Code</a>
        — but opinionated, angry, and actually set up right.
        Clone it. Symlink it. Stop suffering.
      </p>
    </div>
    <div class="fb-mascot-wrap">
      <img
        class="fb-mascot"
        src="{{ '/logos/fartybobo_angry_mascot.svg' | relative_url }}"
        alt="Farty Bobo mascot"
      />
    </div>
  </section>

  <div class="fb-stripe">
    <span class="fb-marquee">
      WE GOT THE F***ING GAS &nbsp;✦&nbsp; WE GOT THE F***ING GAS &nbsp;✦&nbsp; WE GOT THE F***ING GAS &nbsp;✦&nbsp; WE GOT THE F***ING GAS &nbsp;✦&nbsp; WE GOT THE F***ING GAS &nbsp;✦&nbsp; WE GOT THE F***ING GAS &nbsp;✦&nbsp; WE GOT THE F***ING GAS &nbsp;✦&nbsp; WE GOT THE F***ING GAS &nbsp;✦&nbsp;
    </span>
  </div>

  <div class="fb-content">

    <div class="fb-section">
      <h2>What the Hell's In Here</h2>
      <ul class="fb-items">
        <li>
          <span class="fb-item-key">CLAUDE.md</span>
          <span class="fb-item-val">Tells Claude who the f*** it is and how to behave. Non-negotiable.</span>
        </li>
        <li>
          <span class="fb-item-key">settings.json</span>
          <span class="fb-item-val">Model, hooks, permissions. Don't touch it unless you know what you're doing.</span>
        </li>
        <li>
          <span class="fb-item-key">skills/</span>
          <span class="fb-item-val">Real slash commands. Not the useless defaults that ship out of the box.</span>
        </li>
        <li>
          <span class="fb-item-key">hooks/</span>
          <span class="fb-item-val">Shell scripts that fire before/after edits so you don't shoot yourself in the foot.</span>
        </li>
        <li>
          <span class="fb-item-key">commands/</span>
          <span class="fb-item-val">Status line and other crap Claude needs to actually function.</span>
        </li>
      </ul>
    </div>

    <div class="fb-section">
      <h2>Just Do It Already</h2>
      <div class="fb-codeblock">
        <span class="cmd">git clone</span> <span class="arg">https://github.com/fartybobo/farty-bobo ~/dev/farty-bobo</span><br/>
        <span class="cmd">cd</span> <span class="arg">~/dev/farty-bobo</span><br/>
        <span class="cmd">./setup.sh</span>
      </div>
      <a class="fb-link" href="https://github.com/fartybobo/farty-bobo">Read the Damn Docs →</a>
    </div>

  </div>

  <footer class="fb-footer">Farty Bobo &mdash; We Got the f***ing Gas</footer>

</div>
