const root = document.getElementById('dyno');
const canvas = document.getElementById('chart');
const ctx = canvas.getContext('2d');
const fields = Object.fromEntries(['rpm', 'power', 'torque', 'boost', 'speed', 'status', 'gear', 'peaks', 'instruction', 'build', 'ecu-state', 'dyno-plate'].map(id => [id, document.getElementById(id)]));
let samples = [];

const themeValue = value => typeof value === 'string' && value.length <= 64 &&
    /^(#(?:[0-9a-f]{3,4}|[0-9a-f]{6}|[0-9a-f]{8})|rgba?\([\d\s.,%]+\)|hsla?\([\d\s.,%]+\))$/i.test(value.trim()) ? value.trim() : null;
const setThemeVariable = (name, value) => {
    const safe = themeValue(value);
    if (safe) document.documentElement.style.setProperty(name, safe);
};
const themeColorWithAlpha = (value, alpha) => {
    const safe = themeValue(value);
    if (!safe) return null;
    const probe = document.createElement('span');
    probe.style.color = safe;
    probe.style.display = 'none';
    document.body.appendChild(probe);
    const resolved = getComputedStyle(probe).color;
    probe.remove();
    const channels = resolved.match(/[\d.]+/g);
    if (!channels || channels.length < 3) return null;
    return `rgba(${Math.round(Number(channels[0]))}, ${Math.round(Number(channels[1]))}, ${Math.round(Number(channels[2]))}, ${alpha})`;
};
window.applyTorqueWorksTheme = theme => {
    theme = theme && typeof theme === 'object' ? theme : {};
    const colors = theme.colors || {}, categories = theme.categories || {}, dyno = theme.dyno || {};
    const variables = {
        '--accent': colors.accent, '--tw-accent': colors.accent,
        '--surface': colors.surface, '--surface-raised': colors.surfaceRaised,
        '--tw-background': colors.background, '--tw-panel': colors.panel,
        '--text': colors.text, '--muted': colors.muted, '--line': colors.border,
        '--success': colors.success, '--danger': colors.error, '--tw-warning': colors.warning,
        '--tw-power': categories.power, '--tw-driveline': categories.driveline,
        '--tw-grip': categories.grip, '--tw-electronics': categories.electronics,
        '--tw-dyno': dyno.power,
        '--dyno-cyan': dyno.power, '--dyno-orange': dyno.torque,
        '--dyno-pink': dyno.boost, '--tw-dyno-power': dyno.power,
        '--tw-dyno-torque': dyno.torque, '--tw-dyno-boost': dyno.boost,
        '--tw-dyno-grid': dyno.grid
    };
    Object.entries(variables).forEach(([name, value]) => setThemeVariable(name, value));
    const effects = theme.effects || {};
    const glow = Math.max(0, Math.min(1, Number(effects.glowStrength)));
    const blur = Math.max(0, Math.min(30, Number(effects.blur)));
    if (Number.isFinite(glow)) {
        document.documentElement.style.setProperty('--tw-glow-strength', glow);
        document.documentElement.style.setProperty('--tw-glow-percent', `${glow * 100}%`);
    }
    const glowAlpha = Number.isFinite(glow) ? glow : .29;
    const computedTheme = getComputedStyle(document.documentElement);
    for (const category of ['power', 'driveline', 'grip', 'electronics']) {
        const color = categories[category] || computedTheme.getPropertyValue(`--tw-${category}`).trim();
        const translucent = themeColorWithAlpha(color, glowAlpha);
        if (translucent) document.documentElement.style.setProperty(`--tw-${category}-glow`, translucent);
    }
    if (Number.isFinite(blur)) document.documentElement.style.setProperty('--tw-blur', `${blur}px`);
    document.documentElement.classList.toggle('tw-no-carbon', effects.carbonTexture === false);
    window.dispatchEvent(new CustomEvent('torqueworks-theme-applied'));
};

// NUI must always boot invisible; it is explicitly opened by a dyno message.
root.classList.add('hidden');

function resize() {
    const ratio = window.devicePixelRatio || 1;
    const box = canvas.getBoundingClientRect();
    canvas.width = Math.max(1, box.width * ratio);
    canvas.height = Math.max(1, box.height * ratio);
    ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
    draw();
}

function line(data, key, max, color, width, height, pad) {
    if (data.length < 2 || max <= 0) return;
    ctx.beginPath();
    data.forEach((sample, index) => {
        const x = pad + ((sample.rpmNormalized - .18) / .80) * (width - pad * 2);
        const y = height - pad - (sample[key] / max) * (height - pad * 2);
        index ? ctx.lineTo(x, y) : ctx.moveTo(x, y);
    });
    ctx.strokeStyle = color;
    ctx.lineWidth = 2;
    ctx.shadowColor = color;
    ctx.shadowBlur = 8;
    ctx.stroke();
    ctx.shadowBlur = 0;
}

function draw() {
    const ratio = window.devicePixelRatio || 1;
    const width = canvas.width / ratio;
    const height = canvas.height / ratio;
    const pad = 34;
    ctx.clearRect(0, 0, width, height);
    const styles = getComputedStyle(document.documentElement);
    ctx.strokeStyle = styles.getPropertyValue('--tw-dyno-grid').trim() || 'rgba(255,255,255,.065)';
    ctx.lineWidth = 1;
    for (let i = 0; i <= 8; i++) {
        const x = pad + i * (width - pad * 2) / 8;
        ctx.beginPath(); ctx.moveTo(x, pad); ctx.lineTo(x, height - pad); ctx.stroke();
    }
    for (let i = 0; i <= 4; i++) {
        const y = pad + i * (height - pad * 2) / 4;
        ctx.beginPath(); ctx.moveTo(pad, y); ctx.lineTo(width - pad, y); ctx.stroke();
    }
    const maxPower = Math.max(100, ...samples.map(s => s.power)) * 1.12;
    const maxTorque = Math.max(100, ...samples.map(s => s.torque)) * 1.12;
    const maxBoost = Math.max(.1, ...samples.map(s => s.boost)) * 1.15;
    line(samples, 'power', maxPower, styles.getPropertyValue('--dyno-cyan').trim() || '#4ce8ff', width, height, pad);
    line(samples, 'torque', maxTorque, styles.getPropertyValue('--dyno-orange').trim() || '#ffb84d', width, height, pad);
    line(samples, 'boost', maxBoost, styles.getPropertyValue('--dyno-pink').trim() || '#ff4d91', width, height, pad);
    ctx.fillStyle = '#637985';
    ctx.font = '10px monospace';
    ctx.fillText('RPM', width - pad - 18, height - 10);
}

function updateReadout(sample) {
    fields.rpm.textContent = Math.round(sample.rpm).toLocaleString();
    fields.power.textContent = sample.power.toFixed(1);
    fields.torque.textContent = sample.torque.toFixed(1);
    fields.boost.textContent = sample.boost.toFixed(3);
    fields.speed.textContent = sample.speed.toFixed(1);
    fields['ecu-state'].textContent = `THROTTLE ${(sample.throttle * 100).toFixed(0)}% // GEAR BOOST x${sample.gearBoost.toFixed(2)} // ${sample.limiterActive ? 'LIMITER CUT' : 'LIMITER READY'}`;
}

function renderBuild(build) {
    fields['dyno-plate'].textContent = build.plate || 'UNKNOWN PLATE';
    const split = build.frontTorqueBias < 0
        ? 'FACTORY'
        : `${Math.round(build.frontTorqueBias * 100)}F/${Math.round((1 - build.frontTorqueBias) * 100)}R`;
    const values = [
        ['TURBO', build.turbo], ['ECU', build.ecu], ['MAP', build.ecuMap],
        ['ENGINE', build.engine], ['FUEL PUMP', build.fuelpump], ['FLYWHEEL', build.flywheel], ['TRANSMISSION', build.transmission],
        ['SHIFT', build.transmissionPersonality],
        ['LSD', build.differential], ['TIRES', `${build.tireCompound} @ ${build.tirePressure.toFixed(1)} PSI`],
        ['SPLIT', split]
    ];
    fields.build.innerHTML = values
        .map(([label, value]) => `<span>${label} // ${String(value).replaceAll('_', ' ')}</span>`).join('');
}

window.addEventListener('message', ({ data }) => {
    if (data.action === 'torqueWorksTheme') {
        window.applyTorqueWorksTheme(data.theme);
    } else if (data.action === 'open') {
        samples = [];
        root.classList.add('is-preparing');
        root.classList.remove('hidden');
        root.dataset.status = 'armed';
        fields.status.textContent = 'ARMED';
        fields.instruction.textContent = 'HOLD FULL THROTTLE TO START';
        fields.instruction.style.display = 'flex';
        fields.peaks.textContent = 'AWAITING PULL';
        fields.gear.textContent = data.gear;
        renderBuild(data.build);
        requestAnimationFrame(() => requestAnimationFrame(() => {
            resize();
            root.classList.remove('is-preparing');
        }));
    } else if (data.action === 'running') {
        root.dataset.status = 'running';
        fields.status.textContent = 'RUNNING';
        fields.instruction.style.display = 'none';
    } else if (data.action === 'sample') {
        samples.push(data.sample);
        updateReadout(data.sample);
        draw();
    } else if (data.action === 'complete') {
        samples = data.result.samples || samples;
        root.dataset.status = 'complete';
        fields.status.textContent = 'COMPLETE';
        fields.peaks.textContent = `PEAK ${data.result.peakPower.toFixed(1)} WHP // ${data.result.peakTorque.toFixed(1)} NM`;
        if (samples.length) updateReadout(samples[samples.length - 1]);
        draw();
    } else if (data.action === 'close') {
        root.classList.add('hidden');
    }
});

document.getElementById('close').addEventListener('click', () => {
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: '{}'
    });
});
document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && !root.classList.contains('hidden')) {
        document.getElementById('close').click();
    }
});
window.addEventListener('resize', resize);

// A world DUI cannot receive FiveM NUI focus directly. When the installed MMI
// enters interaction mode, this transparent root page captures physical mouse
// buttons and Lua forwards them to the DUI after applying its world-space UV map.
let mmiInteractionActive = false;
const sendMmiInput = (name, data = {}) => fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data)
}).catch(() => {});

window.addEventListener('message', ({ data }) => {
    if (data && data.action === 'mmiInteraction') {
        mmiInteractionActive = data.active === true;
        const controls = document.getElementById('mmi-controls');
        if (controls) {
            controls.classList.toggle('hidden', !mmiInteractionActive);
            controls.setAttribute('aria-hidden', String(!mmiInteractionActive));
        }
    }
});
window.addEventListener('mousedown', event => {
    if (!mmiInteractionActive || event.button !== 0) return;
    event.preventDefault();
    sendMmiInput('mmiPointer', { pressed: true });
}, true);
window.addEventListener('mouseup', event => {
    if (!mmiInteractionActive || event.button !== 0) return;
    event.preventDefault();
    sendMmiInput('mmiPointer', { pressed: false });
}, true);
window.addEventListener('keydown', event => {
    if (!mmiInteractionActive) return;
    const key = event.key;
    if (!['F7', 'Escape', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Enter'].includes(key)) return;
    event.preventDefault();
    if (key === 'F7' || key === 'Escape') sendMmiInput('mmiClose');
    else sendMmiInput('mmiKey', { key });
}, true);
