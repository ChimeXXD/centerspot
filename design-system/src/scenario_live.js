// The Scenarios section's live example: plays one move from mockup/scenario-motion.js (its steps are inlined by
// build.py as __DATA__). Players hold each step briefly, then move to the next, as the mockup's player does; the
// step's arrows fade as they go. Tokens and arrows follow the board's drawing (board.py: TokenDrawing, ArrowDrawing).
(function () {
  var D = __DATA__;
  var root = document.getElementById('scn-live');
  if (!root) return;
  var layer = root.querySelector('.scn-layer'), board = root.querySelector('.scn-board');
  var W = D.W, H = D.H, R = W * 0.038, k = W / 345, HOLD = 0.35, c = D.c;
  var reduce = window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;
  var st = { side: 'attacking', t: 0, playing: false, last: null };
  var steps = function () { return D.steps[st.side]; };
  var n = function (v) { return Math.round(v * 100) / 100; };
  var P = function (p) { return [p.x * W, (1 - p.y) * H]; };

  function head(ex, ey, ang, h, s) {
    return 'M' + n(ex - h * Math.cos(ang - s)) + ' ' + n(ey - h * Math.sin(ang - s)) + ' L' + n(ex) + ' ' + n(ey) +
      ' L' + n(ex - h * Math.cos(ang + s)) + ' ' + n(ey - h * Math.sin(ang + s));
  }
  // An arrow that ends on a player stops short so its head shows.
  function arrow(a, opacity, people) {
    var p0 = P(a.points[0]), p1 = P(a.points[a.points.length - 1]);
    var len = Math.hypot(p1[0] - p0[0], p1[1] - p0[1]) || 1;
    if (people.some(function (q) { var x = P(q); return Math.hypot(x[0] - p1[0], x[1] - p1[1]) < R * 1.2; })) {
      var cut = Math.min(R * 1.35, len / 2);
      p1 = [p1[0] - (p1[0] - p0[0]) / len * cut, p1[1] - (p1[1] - p0[1]) / len * cut];
      len -= cut;
    }
    var col = c[a.kind], d = 'M' + n(p0[0]) + ' ' + n(p0[1]);
    if (a.kind === 'dribble') {
      var m = Math.max(2, Math.round(len / (9 * k))), nx = -(p1[1] - p0[1]) / len, ny = (p1[0] - p0[0]) / len;
      for (var j = 1; j <= m; j++) {
        var t = j / m, amp = j === m ? 0 : (j % 2 ? 3.5 : -3.5) * k;
        d += ' L' + n(p0[0] + (p1[0] - p0[0]) * t + nx * amp) + ' ' + n(p0[1] + (p1[1] - p0[1]) * t + ny * amp);
      }
    } else d += ' L' + n(p1[0]) + ' ' + n(p1[1]);
    var dash = a.kind === 'pass' ? ' stroke-dasharray="' + n(7 * k) + ' ' + n(5 * k) + '"' : '';
    var ang = Math.atan2(p1[1] - p0[1], p1[0] - p0[0]);
    return '<g opacity="' + n(opacity) + '" fill="none" stroke="' + col + '" stroke-width="' + n(2.6 * k) +
      '" stroke-linecap="round" stroke-linejoin="round"><path d="' + d + '"' + dash + '/><path d="' + head(p1[0], p1[1], ang, 9 * k, 0.45) + '"/></g>';
  }
  function disc(p, home, number) {
    var x = n(P(p)[0]), y = n(P(p)[1]), out;
    if (home) out = '<circle cx="' + x + '" cy="' + y + '" r="' + n(R) + '" fill="' + c.home + '"/>';
    else out = '<circle cx="' + x + '" cy="' + y + '" r="' + n(R * 0.9) + '" fill="' + c.awayInner + '" stroke="' + c.away + '" stroke-width="' + n(R * 0.24) + '"/>';
    out += '<circle cx="' + x + '" cy="' + y + '" r="' + n((home ? R : R * 1.02) + R * 0.05) + '" fill="none" stroke="' + c.outline + '" stroke-width="' + n(R * 0.1) + '"/>';
    return out + '<text x="' + x + '" y="' + n(y + R * 0.36) + '" text-anchor="middle" font-family="Nunito, sans-serif" font-weight="800" font-size="' +
      n(R * 1.05) + '" fill="' + (home ? c.homeInk : c.awayInk) + '">' + number + '</text>';
  }

  var dur = function (s, i) { return i < s.length - 1 ? HOLD + s[i].duration : HOLD; };
  var total = function () { var s = steps(), t = 0; for (var i = 0; i < s.length; i++) t += dur(s, i); return t; };
  var startOf = function (i) { var s = steps(), t = 0; for (var j = 0; j < i; j++) t += dur(s, j); return t; };

  function draw() {
    var s = steps(), i = 0, start = 0;
    while (i < s.length - 1 && st.t >= start + dur(s, i)) { start += dur(s, i); i++; }
    var local = st.t - start, moving = !reduce && i < s.length - 1 && local > HOLD;
    var u = moving ? Math.min(1, (local - HOLD) / s[i].duration) : 0;
    var e = u < 0.5 ? 2 * u * u : 1 - Math.pow(-2 * u + 2, 2) / 2;
    var a = s[i], b = s[Math.min(i + 1, s.length - 1)];
    var lerp = function (p, q) { return { x: p.x + (q.x - p.x) * e, y: p.y + (q.y - p.y) * e }; };
    var people = [];
    a.away.forEach(function (p, j) { people.push({ p: lerp(p, b.away[j]), home: false, number: p.number }); });
    a.home.forEach(function (p, j) { people.push({ p: lerp(p, b.home[j]), home: true, number: p.number }); });
    people.sort(function (m, q) { return q.p.y - m.p.y; });  // far end first, as the board stacks them (D-93)
    var ball = lerp(a.ball, b.ball), bp = P(ball);
    var carried = people.some(function (o) { var x = P(o.p); return Math.hypot(x[0] - bp[0], x[1] - bp[1]) < R * 1.2; });
    if (carried) { bp = [bp[0] + R * 0.95, bp[1] + R * 0.95]; }
    var ends = b.home.concat(b.away);
    layer.innerHTML = a.arrows.map(function (ar) { return arrow(ar, moving ? 1 - u : 1, ends); }).join('') +
      people.map(function (o) { return disc(o.p, o.home, o.number); }).join('') +
      '<circle cx="' + n(bp[0]) + '" cy="' + n(bp[1]) + '" r="' + n(R * 0.42) + '" fill="' + c.ball + '" stroke="' + c.outline + '" stroke-width="' + n(R * 0.14) + '"/>';
    var bars = root.querySelectorAll('[data-scrub] b');
    for (var j = 0; j < bars.length; j++) {
      var fill = j < i ? 1 : j > i ? 0 : (i === s.length - 1 ? 1 : Math.min(1, local / dur(s, i)));
      bars[j].style.width = (fill * 100) + '%';
    }
    var label = 'Step ' + (i + 1) + ' of ' + s.length;
    if (root.dataset.step !== String(i) + st.side) {
      root.dataset.step = String(i) + st.side;
      root.querySelector('[data-step]').textContent = label + ' · ';
      root.querySelector('[data-note]').textContent = a.note;
      board.setAttribute('aria-label', label + ': ' + a.note);
    }
    return i;
  }

  var playBtn = root.querySelector('[data-act="play"]');
  function setPlaying(on) {
    st.playing = on; st.last = null;
    playBtn.classList.toggle('on', on);
    playBtn.setAttribute('aria-label', on ? 'Pause' : 'Play');
    if (on) requestAnimationFrame(tick);
  }
  function tick(now) {
    if (!st.playing) return;
    if (st.last !== null) st.t += (now - st.last) / 1000;  // with Reduce Motion, draw() holds each step instead of moving
    st.last = now;
    if (st.t >= total()) { st.t = total(); setPlaying(false); }
    draw();
    if (st.playing) requestAnimationFrame(tick);
  }
  function load(side) {
    st.side = side; st.t = 0; setPlaying(false); root.dataset.step = '';
    root.querySelectorAll('[data-side]').forEach(function (b) {
      var on = b.dataset.side === side; b.classList.toggle('on', on); b.setAttribute('aria-pressed', String(on));
    });
    root.querySelector('[data-help]').textContent = D.help[side];
    root.querySelector('[data-scrub]').innerHTML = steps().map(function () { return '<i><b style="width:0"></b></i>'; }).join('');
    draw();
  }
  function jump(d) {
    setPlaying(false);
    var i = draw(), to = Math.max(0, Math.min(steps().length - 1, i + d));
    st.t = startOf(to); draw();
  }
  root.querySelectorAll('[data-side]').forEach(function (b) { b.addEventListener('click', function () { load(b.dataset.side); }); });
  playBtn.addEventListener('click', function () { if (st.t >= total()) st.t = 0; setPlaying(!st.playing); });
  root.querySelector('[data-act="prev"]').addEventListener('click', function () { jump(-1); });
  root.querySelector('[data-act="next"]').addEventListener('click', function () { jump(1); });
  load('attacking');
})();
