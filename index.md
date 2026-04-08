---
layout: default
title: Farty Bobo
---

<style>
  /* ── Reset Midnight theme noise ── */
  #main_content_wrap, #main_content { background: transparent !important; border: none !important; box-shadow: none !important; }

  /* ── Tokens ── */
  :root {
    --yellow: #f5e642;
    --black: #0a0a0a;
    --off-black: #111;
    --dim: #1a1a1a;
    --border: #2a2a2a;
    --text: #e8e8e8;
    --muted: #666;
    --font-display: 'Bebas Neue', Impact, sans-serif;
    --font-body: 'JetBrains Mono', 'Courier New', monospace;
  }

  /* ── Page shell ── */
  .fb-page {
    font-family: var(--font-body);
    color: var(--text);
    background: var(--black);
    min-height: 100vh;
    padding: 0;
    overflow-x: hidden;
  }

  /* ── HERO ── */
  .fb-hero {
    position: relative;
    display: flex;
    flex-direction: column;
    justify-content: center;
    padding: 80px 6vw;
    border-bottom: 3px solid var(--yellow);
    overflow: hidden;
  }

  .fb-hero::before {
    content: '';
    position: absolute;
    inset: 0;
    background: repeating-linear-gradient(
      -55deg,
      transparent,
      transparent 80px,
      rgba(245,230,66,0.025) 80px,
      rgba(245,230,66,0.025) 81px
    );
    pointer-events: none;
  }

  .fb-hero-inner {
    position: relative;
    z-index: 1;
    display: flex;
    align-items: center;
    gap: 6vw;
  }

  .fb-mascot {
    flex: 0 0 auto;
    width: clamp(180px, 22vw, 300px);
    filter: drop-shadow(0 0 40px rgba(245,230,66,0.3));
    animation: fb-float 4s ease-in-out infinite;
  }

  @keyframes fb-float {
    0%, 100% { transform: translateY(0) rotate(-1deg); }
    50%       { transform: translateY(-12px) rotate(1deg); }
  }

  .fb-title-block { flex: 1 1 auto; }

  .fb-wordmark {
    display: block;
    width: clamp(260px, 40vw, 560px);
    margin-bottom: 8px;
    filter: invert(1) sepia(1) saturate(5) hue-rotate(5deg);
  }

  .fb-tagline {
    font-family: var(--font-display);
    font-size: clamp(2.2rem, 5.5vw, 5rem);
    color: var(--yellow);
    letter-spacing: 0.03em;
    line-height: 1;
    margin: 0 0 28px;
    text-transform: uppercase;
  }

  .fb-desc {
    font-size: clamp(0.78rem, 1.2vw, 0.92rem);
    color: var(--muted);
    max-width: 500px;
    line-height: 1.7;
    margin: 0;
  }

  .fb-desc a { color: var(--yellow); text-decoration: none; border-bottom: 1px solid rgba(245,230,66,0.4); }
  .fb-desc a:hover { border-bottom-color: var(--yellow); }

  /* ── CONTENT ── */
  .fb-content {
    padding: 60px 6vw 100px;
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 4px;
  }

  .fb-section {
    background: var(--off-black);
    border: 1px solid var(--border);
    padding: 40px 36px;
    transition: border-color 0.2s, background 0.2s;
  }

  .fb-section:hover {
    border-color: var(--yellow);
    background: var(--dim);
  }

  .fb-section h2 {
    font-family: var(--font-display);
    font-size: 2rem;
    color: var(--yellow);
    letter-spacing: 0.06em;
    margin: 0 0 28px;
    padding-bottom: 12px;
    border-bottom: 1px solid var(--border);
  }

  .fb-items { list-style: none; margin: 0; padding: 0; }
  .fb-items li {
    display: flex;
    gap: 16px;
    padding: 10px 0;
    border-bottom: 1px solid var(--border);
    font-size: 0.83rem;
    line-height: 1.5;
  }
  .fb-items li:last-child { border-bottom: none; }

  .fb-item-key {
    flex: 0 0 auto;
    color: var(--yellow);
    font-weight: 700;
    min-width: 130px;
  }

  .fb-item-val { color: var(--muted); }

  .fb-codeblock {
    background: #000;
    border: 1px solid var(--border);
    border-left: 3px solid var(--yellow);
    padding: 24px 28px;
    font-size: 0.82rem;
    line-height: 2;
    color: #ccc;
    overflow-x: auto;
    margin: 0 0 28px;
  }

  .fb-codeblock .cmd { color: var(--yellow); }
  .fb-codeblock .arg { color: #aaa; }

  .fb-link {
    display: inline-block;
    font-family: var(--font-display);
    font-size: 1.1rem;
    letter-spacing: 0.08em;
    color: var(--black);
    background: var(--yellow);
    padding: 10px 28px;
    text-decoration: none;
    transition: opacity 0.15s;
  }
  .fb-link:hover { opacity: 0.85; }

  /* ── FOOTER ── */
  .fb-footer {
    text-align: center;
    padding: 32px;
    font-size: 0.7rem;
    color: #333;
    border-top: 1px solid var(--border);
    letter-spacing: 0.1em;
    text-transform: uppercase;
  }

  @media (max-width: 700px) {
    .fb-hero-inner { flex-direction: column; align-items: flex-start; }
    .fb-mascot { width: 140px; }
    .fb-content { grid-template-columns: 1fr; }
  }
</style>

<div class="fb-page">

  <section class="fb-hero">
    <div class="fb-hero-inner">
      <img
        class="fb-mascot"
        src="{{ '/logos/fartybobo_angry_mascot.svg' | relative_url }}"
        alt="Farty Bobo mascot"
      />
      <div class="fb-title-block">
        <img
          class="fb-wordmark"
          src="{{ '/logos/fartybobo_angry_wordmark.svg' | relative_url }}"
          alt="Farty Bobo"
        />
        <p class="fb-tagline">We Got the f***ing Gas</p>
        <p class="fb-desc">
          Every machine you own is a different hellscape of broken configs and
          missing context. This fixes that. It's <a href="https://docs.anthropic.com/en/docs/claude-code">Claude Code</a>
          — but opinionated, angry, and actually set up right.
          Clone it. Symlink it. Stop suffering.
        </p>
      </div>
    </div>
  </section>

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
