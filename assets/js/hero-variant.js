(function () {
  var CLAUDE_LINK = '<a href="https://docs.anthropic.com/en/docs/claude-code">Claude Code</a>';
  var variants = [
    'Every machine you own is a different hellscape of broken configs and missing context. This fixes that. It\'s ' + CLAUDE_LINK + ' — but opinionated, angry, and actually set up right. Clone it. Symlink it. Stop suffering.',
    'You know what\'s insane? Starting from scratch on every machine like it\'s 2003. Every laptop. Every VM. Same broken defaults. Same missing context. Same three hours of your life, gone. This is ' + CLAUDE_LINK + ' with the setup already done — pre-loaded, pre-wired, and ready to go. Just clone the damn thing.',
    'Whoever shipped the default config went home early and left us to rot. Every. Single. Machine. Starting from zero. I can\'t take it anymore. This is ' + CLAUDE_LINK + ' done the way it should\'ve shipped — opinionated, complete, and actually functional. Clone it. Move on with your life.'
  ];
  var el = document.getElementById('fb-desc-text');
  if (el) el.innerHTML = variants[Math.floor(Math.random() * variants.length)];
})();
