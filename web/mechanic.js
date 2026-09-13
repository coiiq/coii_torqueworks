const mechanicRoot = document.getElementById('mechanic');
const buildCardRoot = document.getElementById('vehicle-build-card');
const buildPreviewRoot = document.getElementById('vehicle-build-preview');
let buildCardState = null;
let buildPreviewHideTimer = null;
const mechanicContent = document.getElementById('mechanic-content');
const mechanicPlate = document.getElementById('mechanic-plate');
const mechanicClass = document.getElementById('mechanic-class');
const mechanicBuildName = document.getElementById('mechanic-build-name');
const buildNameEdit = document.getElementById('build-name-edit');
const buildNameForm = document.getElementById('build-name-form');
const buildNameInput = document.getElementById('build-name-input');
const carSettingsToggle = document.getElementById('car-settings-toggle');
const carSettingsPanel = document.getElementById('car-settings-panel');
const ecuCustomPanel = document.getElementById('ecu-custom-panel');
const hotspotLayer = document.getElementById('hotspot-layer');
let mechanicHotspotIntroTimer = null;
const quoteBasket = document.getElementById('quote-basket');
const quoteLinesRoot = document.getElementById('quote-lines');
const customerQuoteRoot = document.getElementById('customer-quote');
let quoteSelection = new Map();
let activeCustomerQuote = null;
const upgradeDrawer = document.getElementById('upgrade-drawer');
const workshopSelection = document.getElementById('workshop-selection');
const menuWatermark = document.getElementById('menu-watermark');
const installRequirementPopover = document.getElementById('install-requirement-popover');
// Keep the fixed popover in viewport space. The mechanic shell is transformed,
// which otherwise offsets it from the actual centre of the hovered card.
document.body.appendChild(installRequirementPopover);
const nitroHud = document.getElementById('nitro-hud');
const nitroHudFill = document.getElementById('nitro-hud-fill');
const nitroCooldown = document.getElementById('nitro-cooldown');
const nitroDelayLabel = document.getElementById('nitro-delay-label');
let nitroHudHideTimer = null;
let nitroAutoRefillEnabled = (() => {
    try { return localStorage.getItem('coii_torqueworks_nitro_auto_refill') !== 'false'; }
    catch (_) { return true; }
})();
function syncNitroAutoRefillPreference() {
    fetch(`https://${GetParentResourceName()}/nitroAutoRefillPreference`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ enabled: nitroAutoRefillEnabled })
    }).catch(() => {});
}
syncNitroAutoRefillPreference();
let mechanicState = { build: null, catalogs: null, history: [], view: 'installed' };
let requirementHideTimer = null;
let requirementShowTimer = null;
let activeRequirementCard = null;
let pendingRequirementCard = null;
let requirementHoverSequence = 0;
let requirementPositionFrame = null;
let requirementPointerInside = false;

function positionInstallRequirements(card = activeRequirementCard) {
    if (!card?.isConnected || installRequirementPopover.classList.contains('hidden')) return;
    const rect = card.getBoundingClientRect();
    installRequirementPopover.style.width = `${Math.max(50, rect.width)}px`;
    installRequirementPopover.style.left = `${Math.max(8, Math.min(window.innerWidth - 58, rect.left))}px`;
    installRequirementPopover.style.bottom = `${window.innerHeight - rect.top + 10}px`;
}

function queueRequirementPosition() {
    if (requirementPositionFrame || !activeRequirementCard) return;
    requirementPositionFrame = requestAnimationFrame(() => {
        requirementPositionFrame = null;
        positionInstallRequirements();
    });
}

function updateRequirementOverflow() {
    const list = installRequirementPopover.querySelector('.requirement-list');
    if (!list) return;
    const items = [...list.querySelectorAll('.requirement-item')];
    const style = getComputedStyle(list);
    const gap = parseFloat(style.columnGap || style.gap) || 0;
    const padding = (parseFloat(style.paddingLeft) || 0) + (parseFloat(style.paddingRight) || 0);
    const visibleWidth = items.reduce((total, item) => total + item.getBoundingClientRect().width, 0)
        + Math.max(0, items.length - 1) * gap + padding;
    list.classList.toggle('is-overflowing', visibleWidth > list.clientWidth + 1);
}

function hideInstallRequirements() {
    requirementHoverSequence += 1;
    if (requirementShowTimer) clearTimeout(requirementShowTimer);
    requirementShowTimer = null;
    pendingRequirementCard = null;
    installRequirementPopover.classList.add('hidden');
    activeRequirementCard?.classList.remove('requirements-active');
    activeRequirementCard = null;
}
let uiAudioContext;
let nitroAudio = null;
const turboAudioBuffers = new Map();
let playerAudioSettings = (() => {
    try {
        const saved = JSON.parse(localStorage.getItem('coii_torqueworks_audio') || '{}');
        const savedVolume = Number(saved.volume);
        return {
            enabled: saved.enabled !== false,
            volume: Number.isFinite(savedVolume) ? Math.max(0, Math.min(savedVolume, 100)) : 100
        };
    } catch (_) {
        return { enabled: true, volume: 100 };
    }
})();

function reportTurboAudioStatus(ok, error) {
    fetch(`https://${GetParentResourceName()}/turboAudioStatus`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ ok, error: error || '' })
    }).catch(() => {});
}

async function playTurboWastegateSound(file, requestedVolume, force = false, test = false, spatial = null, maxDistance = 45) {
    if ((!force && !playerAudioSettings.enabled) || typeof file !== 'string' || !file.startsWith('audio/turbos/')) return;
    const source = `https://cfx-nui-${GetParentResourceName()}/web/${file}`;
    try {
        uiAudioContext ||= new (window.AudioContext || window.webkitAudioContext)();
        if (uiAudioContext.state === 'suspended') await uiAudioContext.resume();
        let buffer = turboAudioBuffers.get(source);
        if (!buffer) {
            const response = await fetch(source);
            if (!response.ok) throw new Error(`HTTP ${response.status}`);
            const bytes = await response.arrayBuffer();
            buffer = await uiAudioContext.decodeAudioData(bytes.slice(0));
            turboAudioBuffers.set(source, buffer);
        }
        const voice = uiAudioContext.createBufferSource();
        const gain = uiAudioContext.createGain();
        const panner = spatial && typeof uiAudioContext.createPanner === 'function'
            ? uiAudioContext.createPanner() : null;
        gain.gain.value = Math.max(0, Math.min(1,
            (Number(requestedVolume) || 0.5) * (playerAudioSettings.volume / 100)));
        voice.buffer = buffer;
        if (panner) {
            panner.panningModel = 'HRTF';
            panner.distanceModel = 'inverse';
            panner.refDistance = 2;
            panner.maxDistance = Math.max(5, Number(maxDistance) || 45);
            panner.rolloffFactor = 0.35;
            panner.coneInnerAngle = 360;
            panner.coneOuterAngle = 360;
            const x = Number(spatial.x) || 0;
            const y = Number(spatial.y) || 0;
            const z = Number(spatial.z) || 0;
            if (panner.positionX) {
                panner.positionX.value = x;
                panner.positionY.value = y;
                panner.positionZ.value = z;
            } else {
                panner.setPosition(x, y, z);
            }
            voice.connect(gain).connect(panner).connect(uiAudioContext.destination);
        } else {
            voice.connect(gain).connect(uiAudioContext.destination);
        }
        voice.start();
        if (test) reportTurboAudioStatus(true);
    } catch (error) {
        if (test) reportTurboAudioStatus(false, error?.message || String(error));
    }
}

function savePlayerAudioSettings() {
    try { localStorage.setItem('coii_torqueworks_audio', JSON.stringify(playerAudioSettings)); } catch (_) { /* Optional persistence. */ }
}

function playUiSound(kind) {
    try {
        uiAudioContext ||= new (window.AudioContext || window.webkitAudioContext)();
        if (uiAudioContext.state === 'suspended') uiAudioContext.resume();
        const now = uiAudioContext.currentTime;
        const oscillator = uiAudioContext.createOscillator();
        const gain = uiAudioContext.createGain();
        const settings = {
            hover: [760, 910, .018, .035], select: [310, 620, .032, .075],
            action: [420, 840, .045, .11], open: [120, 300, .028, .16]
        }[kind] || [500, 650, .02, .05];
        oscillator.type = kind === 'open' ? 'sine' : 'square';
        oscillator.frequency.setValueAtTime(settings[0], now);
        oscillator.frequency.exponentialRampToValueAtTime(settings[1], now + settings[3]);
        gain.gain.setValueAtTime(settings[2], now);
        gain.gain.exponentialRampToValueAtTime(.0001, now + settings[3]);
        oscillator.connect(gain).connect(uiAudioContext.destination);
        oscillator.start(now); oscillator.stop(now + settings[3]);
    } catch (_) { /* Audio is optional when CEF blocks autoplay. */ }
}

function setNitroSound(enabled, requestedVolume) {
    try {
        if (!enabled) {
            if (nitroAudio) {
                const now = nitroAudio.context.currentTime;
                nitroAudio.gain.gain.cancelScheduledValues(now);
                nitroAudio.gain.gain.setValueAtTime(Math.max(.0001, nitroAudio.gain.gain.value), now);
                nitroAudio.gain.gain.exponentialRampToValueAtTime(.0001, now + .12);
                nitroAudio.source.stop(now + .13);
                nitroAudio = null;
            }
            return;
        }
        if (nitroAudio) return;
        uiAudioContext ||= new (window.AudioContext || window.webkitAudioContext)();
        if (uiAudioContext.state === 'suspended') uiAudioContext.resume();
        const context = uiAudioContext;
        const buffer = context.createBuffer(1, context.sampleRate * 2, context.sampleRate);
        const data = buffer.getChannelData(0);
        for (let i = 0; i < data.length; i++) data[i] = (Math.random() * 2 - 1) * (0.65 + 0.35 * Math.sin(i * .013));
        const source = context.createBufferSource();
        const filter = context.createBiquadFilter();
        const gain = context.createGain();
        source.buffer = buffer; source.loop = true;
        filter.type = 'bandpass'; filter.frequency.value = 980; filter.Q.value = .62;
        const volume = Math.max(.01, Math.min(Number(requestedVolume) || .16, .35));
        gain.gain.setValueAtTime(.0001, context.currentTime);
        gain.gain.exponentialRampToValueAtTime(volume, context.currentTime + .09);
        source.connect(filter).connect(gain).connect(context.destination);
        source.start();
        nitroAudio = { context, source, gain };
    } catch (_) { nitroAudio = null; }
}

function playSequentialShiftSound(direction, requestedVolume) {
    try {
        if (!playerAudioSettings.enabled || playerAudioSettings.volume <= 0) return;
        uiAudioContext ||= new (window.AudioContext || window.webkitAudioContext)();
        if (uiAudioContext.state === 'suspended') uiAudioContext.resume();
        const context = uiAudioContext;
        const now = context.currentTime;
        const volume = Math.max(0, Math.min(Number(requestedVolume) || .12, .35)) * (playerAudioSettings.volume / 100);

        const master = context.createGain();
        const compressor = context.createDynamicsCompressor();
        master.gain.value = volume;
        compressor.threshold.value = -18;
        compressor.knee.value = 8;
        compressor.ratio.value = 5;
        compressor.attack.value = .002;
        compressor.release.value = .08;
        master.connect(compressor).connect(context.destination);

        // Broadband actuator air: a very short filtered burst instead of a tone.
        const duration = direction === 'down' ? .105 : .135;
        const noiseBuffer = context.createBuffer(1, Math.ceil(context.sampleRate * duration), context.sampleRate);
        const noise = noiseBuffer.getChannelData(0);
        for (let index = 0; index < noise.length; index++) {
            const progress = index / noise.length;
            noise[index] = (Math.random() * 2 - 1) * Math.pow(1 - progress, 2.6);
        }
        const actuator = context.createBufferSource();
        const actuatorFilter = context.createBiquadFilter();
        const actuatorGain = context.createGain();
        actuator.buffer = noiseBuffer;
        actuatorFilter.type = 'bandpass';
        actuatorFilter.frequency.value = direction === 'down' ? 860 : 1750;
        actuatorFilter.Q.value = direction === 'down' ? .48 : .72;
        actuatorGain.gain.setValueAtTime(direction === 'down' ? .32 : .60, now);
        actuatorGain.gain.exponentialRampToValueAtTime(.0001, now + duration);
        actuator.connect(actuatorFilter).connect(actuatorGain).connect(master);
        actuator.start(now); actuator.stop(now + duration);

        // Low gearbox case impact provides the physical clunk.
        const caseImpact = context.createOscillator();
        const caseGain = context.createGain();
        caseImpact.type = 'sine';
        caseImpact.frequency.setValueAtTime(direction === 'down' ? 74 : 118, now);
        caseImpact.frequency.exponentialRampToValueAtTime(44, now + .07);
        caseGain.gain.setValueAtTime(direction === 'down' ? .72 : .78, now);
        caseGain.gain.exponentialRampToValueAtTime(.0001, now + .08);
        caseImpact.connect(caseGain).connect(master);
        caseImpact.start(now); caseImpact.stop(now + .085);

        // Two damped steel resonances imitate the selector fork and dog ring.
        const ringDelay = direction === 'down' ? .018 : .015;
        [direction === 'down' ? 360 : 690, direction === 'down' ? 590 : 1080].forEach((frequency, index) => {
            const ring = context.createOscillator();
            const ringGain = context.createGain();
            ring.type = 'triangle';
            ring.frequency.setValueAtTime(frequency, now + ringDelay);
            ring.frequency.exponentialRampToValueAtTime(frequency * .72, now + ringDelay + .07);
            ringGain.gain.setValueAtTime(direction === 'down' ? (index ? .055 : .11) : (index ? .16 : .27), now + ringDelay);
            ringGain.gain.exponentialRampToValueAtTime(.0001, now + ringDelay + (direction === 'down' ? .045 : .08));
            ring.connect(ringGain).connect(master);
            ring.start(now + ringDelay); ring.stop(now + ringDelay + (direction === 'down' ? .05 : .085));
        });
    } catch (_) { /* Shift audio is optional if CEF audio is unavailable. */ }
}

const esc = value => String(value ?? '').replace(/[&<>'"]/g, char => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;'
}[char]));
const title = value => String(value).replaceAll('_', ' ').replace(/([a-z])([A-Z])/g, '$1 $2').replace(/\b\w/g, char => char.toUpperCase());
const objectEntries = value => Object.entries(value || {}).filter(([, item]) => item && typeof item === 'object');
const mapEntries = () => Array.isArray(mechanicState.catalogs.maps)
    ? mechanicState.catalogs.maps.map((map, index) => [String(index + 1), map])
    : objectEntries(mechanicState.catalogs.maps);
const mapById = id => Array.isArray(mechanicState.catalogs.maps)
    ? mechanicState.catalogs.maps[Number(id) - 1]
    : mechanicState.catalogs.maps[id];

function mechanicFetch(action, value = {}) {
    return fetch(`https://${GetParentResourceName()}/mechanicAction`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ action, ...value })
    });
}

const quoteKey = (category, partId) => `${category}:${partId}`;
function approvedQuoteLine(category, partId) {
    return (mechanicState.workOrder?.quote?.lines || []).find(line =>
        line.category === category && line.partId === partId && line.completed !== true);
}
function renderQuoteBasket() {
    const lines = [...quoteSelection.values()];
    quoteBasket.classList.toggle('hidden', !lines.length);
    quoteLinesRoot.innerHTML = lines.map((line, index) => `<div class="quote-line" data-category="${esc(line.category)}" style="--quote-row:${index}"><span><small>${esc(line.categoryLabel)}</small><strong>${esc(line.label)}</strong></span><b>${money(line.price)}</b></div>`).join('');
    const labor = Number(mechanicState.catalogs?.billing?.laborPerPart || 0) * lines.length;
    const total = lines.reduce((sum, line) => sum + Number(line.price || 0), 0) + labor;
    document.getElementById('quote-count').textContent = `${lines.length} PART${lines.length === 1 ? '' : 'S'}`;
    document.getElementById('quote-total').textContent = money(total);
}

function displayBuildName(value) {
    const name = String(value || '').trim();
    mechanicBuildName.textContent = name ? `#${name.toUpperCase()}` : '';
    mechanicBuildName.classList.toggle('hidden', !name);
    buildNameInput.value = name;
}

function renderCarSettings() {
    const { build, catalogs } = mechanicState;
    if (!build || !catalogs) return;
    const front = build.frontTorqueBias < 0 ? 50 : Math.round(build.frontTorqueBias * 100);
    const splitUnlocked = build.differential === 'ACTIVE';
    carSettingsPanel.innerHTML = `<header><div><small>TORQUEWORKS</small><h2>CAR SETTINGS</h2></div><button data-settings-close aria-label="Close car settings">×</button></header>
        <article><div class="setting-copy"><label>TIRE PRESSURE</label><strong id="settings-pressure-value">${Number(build.tirePressure).toFixed(1)} PSI</strong></div>
        <input id="settings-pressure" type="range" min="${catalogs.pressure.minimum}" max="${catalogs.pressure.maximum}" step="${catalogs.pressure.increment}" value="${build.tirePressure}">
        <button data-settings-pressure>APPLY PRESSURE</button></article>
        <article class="torque-bias-setting ${splitUnlocked ? '' : 'setting-locked'}"><span class="settings-lock">LOCK</span><div class="setting-copy"><label>FRONT TORQUE BIAS</label><strong id="settings-split-value">${splitUnlocked ? `${front}% FRONT` : 'ACTIVE LSD REQUIRED'}</strong></div>
        <input id="settings-split" type="range" min="0" max="100" step="5" value="${front}" ${splitUnlocked ? '' : 'disabled'}>
        <div class="settings-actions"><button data-settings-split ${splitUnlocked ? '' : 'disabled'}>APPLY SPLIT</button><button data-settings-factory-split ${splitUnlocked ? '' : 'disabled'}>FACTORY SPLIT</button></div></article>
        <article class="player-audio-settings"><div class="setting-copy"><label>MANUAL SHIFT AUDIO</label><strong id="settings-audio-state">${playerAudioSettings.enabled ? `ON // ${playerAudioSettings.volume}%` : 'OFF'}</strong></div>
        <input id="settings-audio-volume" type="range" min="0" max="100" step="1" value="${playerAudioSettings.volume}" ${playerAudioSettings.enabled ? '' : 'disabled'}>
        <div class="settings-actions"><button class="${playerAudioSettings.enabled ? 'active' : ''}" data-settings-audio-toggle>${playerAudioSettings.enabled ? 'DISABLE SOUND' : 'ENABLE SOUND'}</button><button data-settings-audio-test ${playerAudioSettings.enabled ? '' : 'disabled'}>TEST SHIFT</button></div></article>
        <article class="nitro-auto-refill-settings"><div class="setting-copy"><label>NITRO AUTO-REFILL</label><strong>${nitroAutoRefillEnabled ? 'ON' : 'OFF'}</strong><span>Automatically uses one nos_bottle after the refill delay.</span></div>
        <div class="settings-actions"><button class="${nitroAutoRefillEnabled ? 'active' : ''}" data-settings-nitro-auto>${nitroAutoRefillEnabled ? 'DISABLE AUTO-REFILL' : 'ENABLE AUTO-REFILL'}</button></div></article>
        <article class="factory-calibration"><div class="setting-copy"><label>FACTORY CALIBRATION</label><span>Restore ECU hardware and active map.</span></div>
        <button data-settings-reset-ecu>RESET ECU</button></article>`;
}

function renderCustomEcuPanel() {
    const limits = mechanicState.catalogs.ecuCalibration;
    const calibration = { ...limits.defaults, ...(mechanicState.build.ecuCalibration || {}) };
    const popButtons = objectEntries(limits.pops).map(([id, mode]) =>
        `<button type="button" class="${calibration.pops === id ? 'active' : ''}" data-custom-pop="${id}">${esc(mode.label)}</button>`).join('');
    ecuCustomPanel.innerHTML = `<header><div><small>ECU // CUSTOM MAP</small><h2>CALIBRATION</h2></div><button data-custom-close aria-label="Close custom map">&times;</button></header>
        <article><div class="setting-copy"><label>BOOST TARGET</label><strong id="custom-boost-value">x${Number(calibration.boost).toFixed(2)}</strong></div>
        <input id="custom-boost" type="range" min="${limits.boost.minimum}" max="${limits.boost.maximum}" step="${limits.boost.increment}" value="${calibration.boost}"></article>
        <article><div class="setting-copy"><label>POPS &amp; BANGS</label><strong id="custom-pops-value">${esc(calibration.pops)}</strong></div>
        <div class="settings-actions custom-pop-options">${popButtons}</div></article>
        <article><div class="setting-copy"><label>LAUNCH CONTROL</label><strong id="custom-launch-state">${calibration.launchEnabled ? 'ARMED' : 'OFF'}</strong></div>
        <p class="custom-setting-note">HOLD SPACE + THROTTLE WHILE STATIONARY</p><button class="custom-launch-switch ${calibration.launchEnabled ? 'active' : ''}" data-custom-launch>${calibration.launchEnabled ? 'DISABLE' : 'ENABLE'}</button></article>
        <article id="custom-launch-rpm-row" class="${calibration.launchEnabled ? '' : 'setting-disabled'}"><div class="setting-copy"><label>LAUNCH RPM</label><strong id="custom-launch-rpm-value">${Number(calibration.launchRpm).toLocaleString()} RPM</strong></div>
        <input id="custom-launch-rpm" type="range" min="${limits.launchRpm.minimum}" max="${limits.launchRpm.maximum}" step="${limits.launchRpm.increment}" value="${calibration.launchRpm}" ${calibration.launchEnabled ? '' : 'disabled'}></article>
        <footer><span>CHANGES APPLY TO THIS VEHICLE</span><button data-custom-apply>FLASH CUSTOM MAP</button></footer>`;
}

function heading(name, subtitle) {
    return '';
}

const money = value => `$${Number(value || 0).toLocaleString('en-US')}`;

function engineTurboCompatibility(category, id) {
    const system = mechanicState.catalogs?.compatibility?.engineTurbo;
    if (!system || !mechanicState.build || (category !== 'engine' && category !== 'turbo')) return null;
    const engineId = category === 'engine' ? id : mechanicState.build.engine;
    const turboId = category === 'turbo' ? id : mechanicState.build.turbo;
    const turbo = mechanicState.catalogs?.parts?.turbo?.[turboId];
    const compatibilityKey = turbo?.compatibilityClass || turboId;
    return system.combinations?.[engineId]?.[compatibilityKey] || system.default || null;
}

function compatibilityMeter(category, id) {
    const compatibility = engineTurboCompatibility(category, id);
    if (!compatibility) return '';
    const label = compatibility.label || 'BALANCED';
    const score = /OPTIMAL/.test(label) ? 5 : /GOOD|FACTORY/.test(label) ? 4 :
        /BALANCED/.test(label) ? 3 : /COMPROMISED/.test(label) ? 2 : 1;
    const tone = score >= 5 ? 'optimal' : score >= 4 ? 'good' : score >= 3 ? 'balanced' :
        score >= 2 ? 'compromised' : 'poor';
    const squares = Array.from({ length: 5 }, (_, index) =>
        `<i class="${index < score ? 'filled' : ''}"></i>`).join('');
    return `<span class="compatibility-meter compatibility-${tone}" title="${esc(label)}" aria-label="Combination: ${esc(label)}"><span>${squares}</span><small>${esc(label)}</small></span>`;
}

function impactStrip(category, id, part) {
    const metrics = [];
    const add = (label, value, tone = 'gain') => metrics.push(`<span class="impact-${tone}"><small>${esc(label)}</small><b>${esc(value)}</b></span>`);
    if (category === 'turbo') {
        add('BOOST', part.maxBoost > 0 ? `+${Math.round(part.maxBoost * 100)}%` : 'N/A', part.maxBoost > 0 ? 'gain' : 'neutral');
        add('SPOOL', part.spoolRate > 3 ? 'FAST' : part.spoolRate > 1.5 ? 'MED' : part.spoolRate > 0 ? 'SLOW' : 'NONE', part.spoolRate > 2 ? 'gain' : 'neutral');
    } else if (category === 'engine') {
        add('TORQUE', `${part.torque >= 1 ? '+' : ''}${Math.round((part.torque - 1) * 100)}%`, part.torque >= 1 ? 'gain' : 'loss');
        add('TOP END', `${part.maxFlatVel >= 1 ? '+' : ''}${Math.round((part.maxFlatVel - 1) * 100)}%`, part.maxFlatVel >= 1 ? 'gain' : 'loss');
        add('ENGINE TYPE', part.engineType || 'OEM', 'neutral');
    } else if (category === 'fuelpump') {
        add('FLOW', `+${Math.round((part.flow - 1) * 100)}%`, part.flow > 1 ? 'gain' : 'neutral');
        add('OVER-RUN', part.backfire ? 'BACKFIRE' : 'CLEAN', part.backfire ? 'gain' : 'neutral');
    } else if (category === 'nitro') {
        add('POWER', part.enabled ? `+${Math.round((part.powerMultiplier - 1) * 100)}%` : 'NONE', part.enabled ? 'gain' : 'neutral');
        add('SHOT', part.enabled ? `${(part.durationMs / 1000).toFixed(1)}S` : 'BYPASS', part.enabled ? 'gain' : 'neutral');
    } else if (category === 'flywheel') {
        add('RESPONSE', part.throttleResponse > 1.1 ? 'SHARP' : part.throttleResponse < .9 ? 'SMOOTH' : 'BALANCED', part.throttleResponse > 1 ? 'gain' : 'neutral');
        add('RPM FALL', part.rpmFallRate > .8 ? 'FAST' : part.rpmFallRate < .4 ? 'SLOW' : 'FACTORY', part.rpmFallRate > .55 ? 'gain' : 'neutral');
    } else if (category === 'ecu') {
        const peak = Math.max(...(part.curve || [{ torque: 1 }]).map(point => point.torque));
        add('PEAK', `${peak >= 1 ? '+' : ''}${Math.round((peak - 1) * 100)}%`, peak >= 1 ? 'gain' : 'loss');
        add('CURVE', `${(part.curve || []).length} PT`, 'neutral');
    } else if (category === 'transmission') {
        add('GEARS', part.gearCount ? String(part.gearCount) : 'OEM', 'neutral');
        add('BIAS', part.ratios ? (part.ratios[0] >= 3.2 ? 'ACCEL' : part.ratios[0] <= 2.8 ? 'SPEED' : 'BAL') : 'FACTORY', 'neutral');
    } else if (category === 'differential') {
        add('LOCK', `${Math.round(part.lsdLock * 100)}%`, part.lsdLock > 0 ? 'gain' : 'neutral');
        add('TRACTION', `${Math.round((1 - part.tractionLossMultiplier) * 100)}%`, part.tractionLossMultiplier < 1 ? 'gain' : 'neutral');
    } else if (category === 'brakes') {
        add('FORCE', `${part.forceMultiplier >= 1 ? '+' : ''}${Math.round((part.forceMultiplier - 1) * 100)}%`, part.forceMultiplier > 1 ? 'gain' : 'neutral');
        add('PEDAL', part.pedalExponent < .9 ? 'SHARP' : part.pedalExponent < 1.05 ? 'DIRECT' : 'SMOOTH', part.pedalExponent < 1 ? 'gain' : 'neutral');
        add('FADE', `${Math.round(part.maximumFade * 100)}% MAX`, part.maximumFade <= .12 ? 'gain' : 'neutral');
    } else if (category === 'suspension') {
        if (part.purpose) add('SETUP', part.purpose, 'neutral');
        add('STEERING', `${Math.round(((part.steeringLock || 1) - 1) * 100)}%`, (part.steeringLock || 1) > 1 ? 'gain' : 'neutral');
        add('SPRING', `${Math.round((part.stiffness - 1) * 100)}%`, part.stiffness > 1 ? 'gain' : 'neutral');
        add('DAMPING', `${Math.round((part.reboundDamping - 1) * 100)}%`, part.reboundDamping > 1 ? 'gain' : 'neutral');
        add('ROLL', `${Math.round((part.antiRollForce - 1) * 100)}%`, part.antiRollForce > 1 ? 'gain' : 'neutral');
    } else if (category === 'tires') {
        if (part.purpose) add('SETUP', part.purpose, 'neutral');
        add('GRIP', `${part.grip >= 1 ? '+' : ''}${Math.round((part.grip - 1) * 100)}%`, part.grip >= 1 ? 'gain' : 'loss');
        add('LATERAL', `${part.lateralGrip >= 1 ? '+' : ''}${Math.round((part.lateralGrip - 1) * 100)}%`, part.lateralGrip >= 1 ? 'gain' : 'loss');
    }
    const stats = metrics.join('');
    return `<div class="impact-strip"><div class="impact-track"><div class="impact-set">${stats}</div><div class="impact-set" aria-hidden="true">${stats}</div></div></div>`;
}

function partCard(category, id, part, installed) {
    const factory = mechanicState.catalogs.factory[category];
    const locked = mechanicState.lockedParts?.[category]?.[id] === true;
    const categoryLabel = category === 'fuelpump' ? 'FUEL PUMP' : category === 'nitro' ? 'NITROUS' : category.toUpperCase();
    const installation = mechanicState.catalogs.installation;
    const requirementRefs = id !== factory && !installed && installation?.consumable?.enabled
        ? [...(installation.requirements?.universal || []), ...(installation.requirements?.parts?.[category]?.[id] || [])] : [];
    const requirementMap = new Map();
    requirementRefs.forEach(requirement => {
        const item = installation.items?.[requirement.item] || {};
        if (!item.item) return;
        const existing = requirementMap.get(item.item);
        if (existing) existing.amount += Number(requirement.amount) || 1;
        else requirementMap.set(item.item, { ...item, amount: Number(requirement.amount) || 1 });
    });
    const requirements = [...requirementMap.values()];
    const requiresKit = requirements.length > 0;
    const requirementRows = requirements.map(requirement => `<div class="requirement-item">
        ${requirement.image ? `<img src="${esc(requirement.image)}" alt="">` : ''}<span><small>REQUIRED PART</small><strong>${esc(requirement.label || requirement.item)}</strong></span><b>${requirement.amount}x</b></div>`).join('');
    const requirement = requiresKit ? `<div class="install-requirement-data ${mechanicState.installationBypass ? 'bypassed' : ''}">${requirementRows}</div>` : '';
    const selectedForQuote = quoteSelection.has(quoteKey(category, id));
    const approved = approvedQuoteLine(category, id);
    const button = locked ? '' : installed
        ? `<button class="action" disabled>INSTALLED</button>${id !== factory ? `<button class="action danger" data-part="${category}" data-value="${factory}">UNINSTALL</button>` : ''}`
        : approved
            ? `<button class="action" data-part="${category}" data-value="${id}">COMPLETE ORDER</button>`
            : `<button class="action ${selectedForQuote ? 'in-quote' : ''}" data-quote-part="${category}" data-value="${id}">${selectedForQuote ? 'REMOVE FROM QUOTE' : 'ADD TO QUOTE'}</button>`;
    const lock = locked ? `<div class="part-lock" aria-label="Part unavailable"><svg viewBox="0 0 24 24"><rect x="5" y="10" width="14" height="11"/><path d="M8 10V7a4 4 0 0 1 8 0v3M12 14v3"/></svg><strong>LOCKED</strong><span>INCOMPATIBLE</span></div>` : '';
    return `<article class="mechanic-card category-${esc(category)} ${installed ? 'installed' : ''} ${locked ? 'locked' : ''} ${requiresKit ? 'requires-install-item' : ''}">
        <span class="card-visual">${hotspotIcon(category)}</span>
        <label>${esc(categoryLabel)}</label><h3>${esc(part.label || title(id))}${compatibilityMeter(category, id)}</h3>
        ${impactStrip(category, id, part)}${requirement}
        <strong class="part-price">${locked ? 'UNAVAILABLE' : installed ? 'INSTALLED' : money(mechanicState.catalogs.prices?.[category]?.[id])}</strong>
        ${lock}
        <div class="mechanic-actions">${button}</div></article>`;
}

function transmissionPersonalityCard(id, personality) {
    const installed = mechanicState.build.transmissionPersonality === id;
    const selectedForQuote = quoteSelection.has(quoteKey('transmissionPersonality', id));
    const approved = approvedQuoteLine('transmissionPersonality', id);
    const speed = personality.manual ? 'DRIVER' : personality.shiftDuration <= .12 ? 'INSTANT' : personality.shiftDuration <= .25 ? 'FAST' : 'SMOOTH';
    const handover = `${Math.round(personality.shiftPowerFloor * 100)}%`;
    return `<article class="mechanic-card category-transmission ${installed ? 'installed' : ''}">
        <span class="card-visual">${hotspotIcon('transmission')}</span>
        <label>SHIFT BEHAVIOR</label><h3>${esc(personality.label || title(id))}</h3>
        <div class="impact-strip"><span class="impact-neutral"><small>SHIFT</small><b>${speed}</b></span><span class="impact-neutral"><small>HANDOVER</small><b>${handover}</b></span></div>
        <strong class="part-price">${installed ? 'INSTALLED' : money(mechanicState.catalogs.prices?.transmissionPersonalities?.[id])}</strong>
        <div class="mechanic-actions">${installed ? '<button class="action" disabled>ACTIVE</button>' : approved ? `<button class="action" data-personality="${esc(id)}">COMPLETE ORDER</button>` : `<button class="action ${selectedForQuote ? 'in-quote' : ''}" data-quote-special="transmissionPersonality" data-value="${esc(id)}">${selectedForQuote ? 'REMOVE FROM QUOTE' : 'ADD TO QUOTE'}</button>`}</div></article>`;
}

function renderInstalled() {
    const { build, catalogs } = mechanicState;
    const cards = Object.keys(catalogs.parts).map(category => {
        const id = build[category];
        return partCard(category, id, catalogs.parts[category][id], true);
    });
    const split = build.frontTorqueBias < 0 ? 'Factory baseline' : `${Math.round(build.frontTorqueBias * 100)}% front / ${Math.round((1 - build.frontTorqueBias) * 100)}% rear`;
    cards.push(transmissionPersonalityCard(build.transmissionPersonality, catalogs.transmissionPersonalities[build.transmissionPersonality]));
    cards.push(`<article class="mechanic-card category-tires installed"><span class="card-visual">${hotspotIcon('tires')}</span><label>TIRES</label><h3>${esc(title(build.tireCompound))}</h3><p>${build.tirePressure.toFixed(1)} PSI</p></article>`);
    cards.push(`<article class="mechanic-card category-ecu installed"><span class="card-visual">${hotspotIcon('ecu')}</span><label>ECU MAP</label><h3>Map ${build.ecuMap} — ${esc(mapById(build.ecuMap).label)}</h3><p>Active calibration</p></article>`);
    cards.push(`<article class="mechanic-card category-differential installed"><span class="card-visual">${hotspotIcon('differential')}</span><label>TORQUE SPLIT</label><h3>${esc(split)}</h3><p>Current front/rear drivetrain distribution</p></article>`);
    mechanicContent.innerHTML = heading('Installed build', 'Every installed component and active calibration on this plate.') + `<div class="mechanic-grid">${cards.join('')}</div>`;
}

function renderParts() {
    const categories = ['turbo', 'engine', 'fuelpump', 'nitro', 'flywheel', 'transmission'];
    const cards = categories.flatMap(category => objectEntries(mechanicState.catalogs.parts[category])
        .map(([id, part]) => partCard(category, id, part, mechanicState.build[category] === id)));
    mechanicContent.innerHTML = heading('Parts catalog', 'Unlimited development inventory. Installation is immediate.') + `<div class="mechanic-grid install-grid">${cards.join('')}</div>`;
}

function renderSinglePart(category) {
    const cards = objectEntries(mechanicState.catalogs.parts[category])
        .map(([id, part]) => partCard(category, id, part, mechanicState.build[category] === id));
    if (category === 'transmission') {
        const personalities = objectEntries(mechanicState.catalogs.transmissionPersonalities)
            .map(([id, personality]) => transmissionPersonalityCard(id, personality));
        cards.push(...personalities);
    }
    mechanicContent.innerHTML = heading(title(category), `Select the ${category} configuration for this vehicle.`) + `<div class="mechanic-grid install-grid">${cards.join('')}</div>`;
}

function renderEcu() {
    const { build, catalogs } = mechanicState;
    const hardware = objectEntries(catalogs.parts.ecu).map(([id, part]) => partCard('ecu', id, part, build.ecu === id));
    const maps = mapEntries().map(([id, map]) => {
        const selected = !build.ecuCalibration?.customEnabled && Number(id) === Number(build.ecuMap);
        return `<article class="mechanic-card category-ecu ${selected ? 'installed' : ''}"><span class="card-visual">${hotspotIcon('ecu')}</span><label>MAP ${id}</label><h3>${esc(map.label)}</h3>
            <div class="impact-strip"><span class="impact-gain"><small>BOOST</small><b>×${map.boostMultiplier.toFixed(2)}</b></span><span class="impact-neutral"><small>LIMIT</small><b>${(map.revLimit * 100).toFixed(0)}%</b></span></div>
            ${selected ? '' : `<strong class="part-price">${money(catalogs.prices?.maps?.[id])}</strong>`}
            <button class="action" ${selected ? 'disabled' : `data-map="${id}"`}>${selected ? 'ACTIVE' : 'FLASH MAP'}</button></article>`;
    });
    const customActive = build.ecuCalibration?.customEnabled === true;
    maps.push(`<article class="mechanic-card category-ecu custom-map-card ${customActive ? 'installed' : ''}" data-open-custom><span class="card-visual">${hotspotIcon('ecu')}</span><label>MAP</label><h3>CUSTOM</h3>
        <div class="impact-strip"><span class="impact-gain"><small>BOOST</small><b>x${Number(build.ecuCalibration?.boost || 1).toFixed(2)}</b></span><span class="impact-neutral"><small>LAUNCH</small><b>${build.ecuCalibration?.launchEnabled ? 'ARMED' : 'OFF'}</b></span></div>
        <strong class="part-price">${customActive ? 'ACTIVE' : 'CALIBRATE'}</strong><button class="action" data-open-custom>${customActive ? 'EDIT MAP' : 'OPEN MAP'}</button></article>`);
    mechanicContent.innerHTML = heading('ECU tuning', 'Choose ECU hardware or select a calibration.') +
        `<div class="mechanic-grid install-grid">${hardware.join('')}${maps.join('')}</div>`;
}


function renderTires() {
    const { build, catalogs } = mechanicState;
    const cards = objectEntries(catalogs.compounds).map(([id, compound]) => {
        const selected = build.tireCompound === id;
        const selectedForQuote = quoteSelection.has(quoteKey('tireCompound', id));
        const approved = approvedQuoteLine('tireCompound', id);
        const locked = mechanicState.lockedParts?.tireCompound?.[id] === true;
        const lock = locked ? `<div class="part-lock" aria-label="Part unavailable"><svg viewBox="0 0 24 24"><rect x="5" y="10" width="14" height="11"/><path d="M8 10V7a4 4 0 0 1 8 0v3M12 14v3"/></svg><strong>LOCKED</strong><span>INCOMPATIBLE</span></div>` : '';
        return `<article class="mechanic-card category-tires ${selected ? 'installed' : ''} ${locked ? 'locked' : ''}"><span class="card-visual">${hotspotIcon('tires')}</span><label>COMPOUND</label><h3>${esc(compound.label)}</h3>
            ${impactStrip('tires', id, compound)}${locked ? '<strong class="part-price">UNAVAILABLE</strong>' : selected ? '' : `<strong class="part-price">${money(catalogs.prices?.compounds?.[id])}</strong>`}
            ${lock}${locked ? '' : selected ? '<button class="action" disabled>INSTALLED</button>' : approved ? `<button class="action" data-compound="${id}">COMPLETE ORDER</button>` : `<button class="action ${selectedForQuote ? 'in-quote' : ''}" data-quote-special="tireCompound" data-value="${id}">${selectedForQuote ? 'REMOVE FROM QUOTE' : 'ADD TO QUOTE'}</button>`}</article>`;
    });
    mechanicContent.innerHTML = heading('Tires', 'Compound and pressure are applied from factory traction baselines.') + `<div class="mechanic-grid">${cards.join('')}</div>`;
}

function renderDrivetrain() {
    const { build, catalogs } = mechanicState;
    const cards = objectEntries(catalogs.parts.differential).map(([id, part]) => partCard('differential', id, part, build.differential === id));
    mechanicContent.innerHTML = heading('Differential and AWD', 'LSD behavior is independent from the front/rear torque split.') + `<div class="mechanic-grid">${cards.join('')}</div>`;
}

function drawHistory(run) {
    const canvas = document.getElementById('history-chart');
    if (!canvas || !run) return;
    const ratio = window.devicePixelRatio || 1, box = canvas.getBoundingClientRect();
    canvas.width = Math.max(1, box.width * ratio); canvas.height = Math.max(1, box.height * ratio);
    const context = canvas.getContext('2d'); context.setTransform(ratio, 0, 0, ratio, 0, 0);
    const width = box.width, height = box.height, pad = 35, samples = run.samples || [];
    context.clearRect(0, 0, width, height); context.strokeStyle = 'rgba(120,160,180,.13)';
    for (let i = 0; i <= 6; i++) { const x = pad + i * (width - pad * 2) / 6; context.beginPath(); context.moveTo(x,pad); context.lineTo(x,height-pad); context.stroke(); }
    const plot = (key, max, color) => { if (samples.length < 2 || max <= 0) return; context.beginPath(); samples.forEach((sample,index) => { const x = pad + sample.rpmNormalized * (width-pad*2), y = height-pad-(sample[key]/max)*(height-pad*2); index ? context.lineTo(x,y) : context.moveTo(x,y); }); context.strokeStyle=color; context.lineWidth=2; context.stroke(); };
    plot('power', Math.max(100, ...samples.map(sample => sample.power)) * 1.1, '#4ce8ff');
    plot('torque', Math.max(100, ...samples.map(sample => sample.torque)) * 1.1, '#ffb84d');
    plot('boost', Math.max(.1, ...samples.map(sample => sample.boost)) * 1.1, '#ff4d91');
}

function formatDynoDate(value) {
    if (value === null || value === undefined || value === '') return 'DATE UNAVAILABLE';
    const text = String(value).trim();
    const numeric = Number(text);
    let date;
    if (Number.isFinite(numeric)) {
        // oxmysql may serialize SQL timestamps as Unix milliseconds. Older
        // records/providers can return Unix seconds, so support both forms.
        date = new Date(numeric < 1e11 ? numeric * 1000 : numeric);
    } else {
        date = new Date(text);
    }
    if (Number.isNaN(date.getTime())) return 'DATE UNAVAILABLE';
    return new Intl.DateTimeFormat('en-GB', {
        day: '2-digit', month: 'short', year: 'numeric',
        hour: '2-digit', minute: '2-digit', hour12: false
    }).format(date).toUpperCase();
}

function renderHistory() {
    const history = mechanicState.history;
    const runs = history.map((run, index) => `<article class="history-run ${index === 0 ? 'active' : ''}" data-history="${index}">
        <strong>${Number(run.peak_power).toFixed(1)} WHP</strong> // ${Number(run.peak_torque).toFixed(1)} NM
        <small>${esc(formatDynoDate(run.created_at))} // MAP ${esc(run.build?.ecuMap || 'FACTORY')}</small></article>`).join('');
    mechanicContent.innerHTML = `<button class="history-close" data-close-history aria-label="Close dyno history">×</button>` +
        `<div class="history-layout"><div class="history-list">${runs || '<p class="subtitle">No saved pulls yet.</p>'}</div><div class="history-chart-shell"><canvas id="history-chart"></canvas></div></div>`;
    requestAnimationFrame(() => {
        const list = mechanicContent.querySelector('.history-list');
        if (list) list.scrollTop = 0;
        if (history.length) drawHistory(history[0]);
    });
}

function renderMechanic() {
    hideInstallRequirements();
    if (!mechanicState.build || !mechanicState.catalogs) return;
    if (mechanicState.view.startsWith('category-')) {
        renderSinglePart(mechanicState.view.replace('category-', ''));
    } else {
        ({ installed: renderInstalled, parts: renderParts, ecu: renderEcu, tires: renderTires, drivetrain: renderDrivetrain, history: renderHistory }[mechanicState.view] || renderInstalled)();
    }
    updateMenuWatermark();
    mechanicContent.querySelectorAll('.mechanic-card').forEach((card, index) => card.style.setProperty('--card-index', index));
    requestAnimationFrame(updateGridOverflow);
    if (!carSettingsPanel.classList.contains('hidden')) renderCarSettings();
    if (!ecuCustomPanel.classList.contains('hidden')) renderCustomEcuPanel();
}

function updateGridOverflow() {
    mechanicContent.querySelectorAll('.mechanic-grid').forEach(grid => {
        grid.classList.toggle('is-overflowing', grid.scrollWidth > grid.clientWidth + 2);
    });
}

const smoothScrollStates = new WeakMap();
function smoothScroll(element, axis, delta) {
    if (!element || !Number.isFinite(delta)) return;
    const position = axis === 'x' ? 'scrollLeft' : 'scrollTop';
    const maximum = Math.max(0, axis === 'x'
        ? element.scrollWidth - element.clientWidth
        : element.scrollHeight - element.clientHeight);
    let state = smoothScrollStates.get(element);
    if (!state || state.axis !== axis) state = { axis, target: element[position], frame: 0 };
    else if (!state.frame) state.target = element[position];
    state.target = Math.max(0, Math.min(maximum, state.target + delta));
    if (!state.frame) {
        const step = () => {
            const distance = state.target - element[position];
            if (Math.abs(distance) < .35) {
                element[position] = state.target;
                state.frame = 0;
                return;
            }
            element[position] += distance * .22;
            state.frame = requestAnimationFrame(step);
        };
        state.frame = requestAnimationFrame(step);
    }
    smoothScrollStates.set(element, state);
}

function updateMenuWatermark() {
    const view = mechanicState.view;
    const icon = view.startsWith('category-') ? view.replace('category-', '') : ({
        installed: 'overview', parts: 'overview', ecu: 'ecu', tires: 'tires',
        drivetrain: 'differential', history: 'history'
    })[view] || 'overview';
    menuWatermark.innerHTML = hotspotIcon(icon);
    menuWatermark.classList.remove('is-changing');
    requestAnimationFrame(() => menuWatermark.classList.add('is-changing'));
}

function openWorkshopView(view, label) {
    const opening = upgradeDrawer.classList.contains('hidden');
    mechanicState.view = view;
    upgradeDrawer.dataset.view = view;
    workshopSelection.textContent = label || title(view);
    if (opening) upgradeDrawer.classList.add('is-preparing');
    upgradeDrawer.classList.remove('hidden');
    renderMechanic();
    if (opening) requestAnimationFrame(() => requestAnimationFrame(() => {
        updateGridOverflow();
        upgradeDrawer.classList.remove('is-preparing');
    }));
}

const hotspotMeta = {
    engine: ['ENGINE', 'category-engine'], turbo: ['TURBO', 'category-turbo'],
    ecu: ['ECU', 'ecu'], fuelpump: ['FUEL PUMP', 'category-fuelpump'], nitro: ['NITROUS', 'category-nitro'], flywheel: ['FLYWHEEL', 'category-flywheel'],
    transmission: ['TRANSMISSION', 'category-transmission'],
    differential: ['DRIVETRAIN', 'drivetrain'], tires: ['TIRES', 'tires'],
    brakes: ['BRAKES', 'category-brakes'],
    suspension: ['SUSPENSION', 'category-suspension'],
    history: ['DYNO', 'history']
};
const hotspotGroups = {
    power: { label: 'POWER', icon: 'power', children: ['engine', 'turbo', 'ecu', 'fuelpump', 'nitro'], anchor: 'engine' },
    driveline: { label: 'DRIVELINE', icon: 'driveline', children: ['flywheel', 'transmission', 'differential'], anchor: 'transmission' },
    grip: { label: 'GRIP', icon: 'grip', children: ['tires', 'brakes', 'suspension'], anchor: 'tires' },
    dyno: { label: 'DYNO', icon: 'history', children: ['history'], anchor: 'history', direct: true }
};
let activeHotspotGroup = 'root';
let latestHotspotPoints = [];

function hotspotIcon(id) {
    const paths = {
        overview: '<path d="M3 5h7v6H3zM14 5h7v6h-7zM3 15h7v4H3zM14 15h7v4h-7zM6 3v2m12-2v2M6 11v4m12-4v4"/>',
        engine: '<path d="M4 9h3l2-3h7l2 3h2v9h-3l-2 2H8l-2-2H4V9zM10 6V4h5M2 11h2v5H2m18-4h2v4h-2M9 11h7v5H9z"/>',
        flywheel: '<path d="M12 3a9 9 0 1 0 9 9 9 9 0 0 0-9-9zM12 7a5 5 0 1 0 5 5 5 5 0 0 0-5-5zM12 10v4m-2-2h4M12 3v2m0 14v2M3 12h2m14 0h2"/>',
        turbo: '<path d="M19 7h3l-2 3M12 4a8 8 0 1 0 8 8c0-1.8-.6-3.5-1.6-4.8M12 8a4 4 0 1 1-4 4h4V8zM12 12l5-5"/>',
        ecu: '<path d="M5 5h14v14H5zM9 9h6v6H9zM9 2v3m6-3v3M9 19v3m6-3v3M2 9h3m-3 6h3m14-6h3m-3 6h3M11 11h2v2h-2z"/>',
        fuelpump: '<path d="M6 3h10v18H6zM8 6h6v5H8zM16 7h2l2 3v7a2 2 0 0 1-4 0v-3M4 21h14M9 15h4"/>',
        nitro: '<path d="M9 2h6v3l2 2v13H7V7l2-2V2zM9 9h6M10 13l4-2-2 3h3l-5 4 2-3H9l1-2zM10 2h4"/>',
        transmission: '<path d="M3 9h4l2-3h6l2 3h4v6h-4l-2 3H9l-2-3H3V9zM11 8v8m3-7v6M3 12H1m22 0h-2M9 18v3h6v-3"/>',
        differential: '<path d="M2 10h6l2-3h4l2 3h6v4h-6l-2 3h-4l-2-3H2v-4zM12 9v6m-3-3h6M4 8v8m16-8v8"/>',
        tires: '<path d="M9 3h6l3 3v12l-3 3H9l-3-3V6l3-3zM9 6h6m-6 4h6m-6 4h6m-6 4h6M6 8h3m6 0h3M6 16h3m6 0h3"/>',
        brakes: '<path d="M12 3a9 9 0 1 0 9 9M12 7a5 5 0 1 0 5 5M17 4h4v8h-4zM12 10v4m-2-2h4"/>',
        suspension: '<path d="M5 3v4m14-4v4M3 7h18M6 7v3l-2 2 4 2-4 2 4 2-2 3M18 7v3l2 2-4 2 4 2-4 2 2 3M9 12h6m-6 5h6"/>',
        history: '<path d="M3 20V4m0 16h18M6 16l4-5 3 2 5-7M18 6v4m0-4h-4M7 5h5M7 8h3"/>'
        , power: '<path d="M13 2L5 14h6l-1 8 9-13h-6V2z"/>'
        , driveline: '<path d="M3 9h5l2-3h4l2 3h5v6h-5l-2 3h-4l-2-3H3V9zM12 8v8M1 12h2m18 0h2"/>'
        , grip: '<path d="M8 3h8l3 4v10l-3 4H8l-3-4V7l3-4zM8 7h8M8 12h8M8 17h8"/>'
        , back: '<path d="M10 5l-7 7 7 7M3 12h12a6 6 0 0 1 6 6"/>'
    };
    return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">${paths[id]}</svg>`;
}

function updateHotspots(points) {
    latestHotspotPoints = points;
    const fallback = {
        engine: [.34, .28], turbo: [.22, .42], ecu: [.29, .60], fuelpump: [.38, .68], nitro: [.43, .74],
        flywheel: [.50, .62], transmission: [.50, .72], differential: [.67, .65],
        tires: [.76, .43], brakes: [.68, .56], suspension: [.57, .70], history: [.62, .22]
    };
    const screenOffset = {
        engine: [-.045, 0], turbo: [-.018, -.055], ecu: [-.035, .060], fuelpump: [-.055, .035], nitro: [.025, .055],
        flywheel: [-.035, -.045], transmission: [-.005, .065],
        tires: [.040, -.035], brakes: [.055, .045], suspension: [.025, .045], differential: [.050, .025], history: [0, 0]
    };
    const offsetPosition = (id, position) => {
        const offset = screenOffset[id] || [0, 0];
        return [
            Math.max(.04, Math.min(.96, position[0] + offset[0])),
            Math.max(.08, Math.min(.92, position[1] + offset[1]))
        ];
    };
    const projectionAvailable = points.some(point => point.visible && point.x >= 0 && point.x <= 1 && point.y >= 0 && point.y <= 1);
    const byId = Object.fromEntries(points.map(point => [point.id, point]));
    let desired;
    if (activeHotspotGroup === 'root') {
        desired = Object.entries(hotspotGroups).map(([id, group]) => ({
            key: `group-${id}`, group: id, label: group.label, icon: group.icon,
            point: byId[group.anchor], anchor: group.anchor
        }));
    } else {
        const group = hotspotGroups[activeHotspotGroup];
        desired = group.children.map(id => ({ key: id, hotspot: id, label: hotspotMeta[id][0], icon: id, point: byId[id], anchor: id }));
        desired.push({ key: 'back', back: true, label: 'BACK', icon: 'back', fixed: [.50, .20] });
    }
    hotspotLayer.dataset.group = activeHotspotGroup;
    const known = new Set(desired.map(item => item.key));
    hotspotLayer.querySelectorAll('.vehicle-hotspot-group').forEach(item => item.remove());
    desired.forEach((item, index) => {
        let button = hotspotLayer.querySelector(`[data-hotspot-key="${item.key}"]`);
        if (!button) {
            button = document.createElement('button');
            button.dataset.hotspotKey = item.key;
            if (item.hotspot) button.dataset.hotspot = item.hotspot;
            if (item.group) button.dataset.categoryGroup = item.group;
            if (item.back) button.dataset.hotspotBack = '';
            button.className = `vehicle-hotspot ${item.group ? `hotspot-master category-${item.group}` : item.back ? 'hotspot-back' : `category-${item.hotspot}`}`;
            button.innerHTML = `<span class="hotspot-icon">${hotspotIcon(item.icon)}</span><span><b>${item.label}</b><small>${item.group ? (hotspotGroups[item.group].direct ? 'OPEN' : 'SELECT GROUP') : item.back ? 'ALL GROUPS' : 'VIEW UPGRADES'}</small></span>`;
            hotspotLayer.appendChild(button);
        }
        const rawPosition = item.fixed || (projectionAvailable && item.point?.visible
            ? [item.point.x, item.point.y] : fallback[item.anchor]);
        const position = item.fixed || offsetPosition(item.anchor, rawPosition);
        button.style.setProperty('--hotspot-index', index);
        button.style.left = `${position[0] * 100}%`;
        button.style.top = `${position[1] * 100}%`;
        button.classList.toggle('offscreen', !item.fixed && projectionAvailable && !item.point?.visible);
    });
    hotspotLayer.querySelectorAll('[data-hotspot-key]').forEach(button => {
        if (!known.has(button.dataset.hotspotKey)) button.remove();
    });
}

document.getElementById('mechanic-nav').addEventListener('click', event => {
    const button = event.target.closest('[data-view]'); if (!button) return;
    document.querySelectorAll('#mechanic-nav button').forEach(item => item.classList.toggle('active', item === button));
    mechanicState.view = button.dataset.view; renderMechanic();
});

mechanicContent.addEventListener('click', event => {
    const target = event.target.closest('button, [data-history], [data-open-custom]'); if (!target) return;
    playUiSound(target.matches('.action, [data-close-history]') ? 'action' : 'select');
    if (target.hasAttribute('data-close-history')) {
        upgradeDrawer.classList.add('hidden');
        workshopSelection.textContent = 'SELECT A COMPONENT';
        hotspotLayer.querySelectorAll('.vehicle-hotspot').forEach(item => item.classList.remove('selected'));
        return;
    }
    if (target.dataset.quotePart || target.dataset.quoteSpecial) {
        const category = target.dataset.quotePart || target.dataset.quoteSpecial, partId = target.dataset.value;
        const key = quoteKey(category, partId);
        if (quoteSelection.has(key)) quoteSelection.delete(key);
        else {
            // One final part per category can exist in a vehicle build.
            for (const [existingKey, line] of quoteSelection) if (line.category === category) quoteSelection.delete(existingKey);
            const part = category === 'tireCompound' ? mechanicState.catalogs.compounds?.[partId]
                : category === 'transmissionPersonality' ? mechanicState.catalogs.transmissionPersonalities?.[partId]
                : mechanicState.catalogs.parts?.[category]?.[partId];
            const priceGroup = category === 'tireCompound' ? 'compounds'
                : category === 'transmissionPersonality' ? 'transmissionPersonalities' : category;
            quoteSelection.set(key, {
                category, partId, label: part?.label || title(partId),
                categoryLabel: category === 'fuelpump' ? 'FUEL PUMP' : title(category).toUpperCase(),
                price: Number(mechanicState.catalogs.prices?.[priceGroup]?.[partId] || 0)
            });
        }
        renderMechanic();
        renderQuoteBasket();
    } else if (target.dataset.part) {
        mechanicFetch('part', { category: target.dataset.part, value: target.dataset.value });
    }
    if (target.dataset.map) mechanicFetch('map', { value: Number(target.dataset.map) });
    if (target.hasAttribute('data-open-custom')) {
        carSettingsPanel.classList.add('hidden');
        ecuCustomPanel.classList.remove('hidden');
        renderCustomEcuPanel();
    }
    if (target.dataset.ecuPop) {
        mechanicContent.querySelectorAll('[data-ecu-pop]').forEach(button => button.classList.toggle('active', button === target));
        document.getElementById('ecu-pops-value').textContent = target.dataset.ecuPop;
    }
    if (target.hasAttribute('data-ecu-launch')) {
        target.classList.toggle('active');
        target.querySelector('strong').textContent = target.classList.contains('active') ? 'ARMED' : 'OFF';
        document.getElementById('ecu-launch-rpm').disabled = !target.classList.contains('active');
    }
    if (target.hasAttribute('data-ecu-apply')) {
        const selectedPop = mechanicContent.querySelector('[data-ecu-pop].active');
        mechanicFetch('ecuCalibration', { value: {
            boost: Number(document.getElementById('ecu-boost').value),
            pops: selectedPop?.dataset.ecuPop || 'OFF',
            launchEnabled: mechanicContent.querySelector('[data-ecu-launch]').classList.contains('active'),
            launchRpm: Number(document.getElementById('ecu-launch-rpm').value)
        }});
    }
    if (target.dataset.personality) mechanicFetch('transmissionPersonality', { value: target.dataset.personality });
    if (target.dataset.compound) mechanicFetch('compound', { value: target.dataset.compound });
    if (target.hasAttribute('data-reset-ecu')) mechanicFetch('resetEcu');
    if (target.hasAttribute('data-set-pressure')) mechanicFetch('pressure', { value: Number(document.getElementById('pressure-input').value) });
    if (target.hasAttribute('data-set-split')) mechanicFetch('split', { value: Number(document.getElementById('split-input').value) });
    if (target.hasAttribute('data-factory-split')) mechanicFetch('split', { value: 'FACTORY' });
    if (target.dataset.history !== undefined) { document.querySelectorAll('.history-run').forEach(item => item.classList.toggle('active', item === target)); drawHistory(mechanicState.history[Number(target.dataset.history)]); }
});

document.getElementById('quote-clear').addEventListener('click', () => {
    quoteSelection.clear(); renderQuoteBasket(); renderMechanic();
});
function sendSelectedQuote(self = false) {
    const lines = [...quoteSelection.values()].map(({ category, partId }) => ({ category, partId }));
    if (!lines.length) return;
    fetch(`https://${GetParentResourceName()}/mechanicSendQuote`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ lines, self })
    });
}
document.getElementById('quote-self').addEventListener('click', () => sendSelectedQuote(true));
document.getElementById('quote-send').addEventListener('click', () => sendSelectedQuote(false));

customerQuoteRoot.addEventListener('click', event => {
    const button = event.target.closest('[data-quote-response]');
    if (!button || !activeCustomerQuote) return;
    const response = button.dataset.quoteResponse;
    fetch(`https://${GetParentResourceName()}/customerQuoteResponse`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ id: activeCustomerQuote.id, token: activeCustomerQuote.token, response, selfQuote: activeCustomerQuote.selfQuote === true })
    });
    activeCustomerQuote = null;
    customerQuoteRoot.classList.add('hidden');
});

function showCustomerQuote(data) {
    activeCustomerQuote = data;
    const quote = data.quote || {};
    document.getElementById('customer-quote-plate').textContent = data.plate || 'NO PLATE';
    document.getElementById('customer-quote-mechanic').textContent = data.mechanicName || 'MECHANIC';
    const current = quote.currentClass || {}, estimated = quote.estimatedClass || {};
    document.getElementById('customer-quote-class').textContent = `${current.label || 'D'} ${current.rating || 300} → ${estimated.label || 'D'} ${estimated.rating || 300}`;
    document.getElementById('customer-quote-lines').innerHTML = (quote.lines || []).map((line, index) => {
        const materials = (line.requirements || []).map(item => `${Number(item.amount) || 1}x ${esc(item.label || item.item)}`).join(' · ');
        return `<div class="customer-invoice-line" data-category="${esc(line.category)}" style="--quote-row:${index}"><span><small>${esc(line.categoryLabel)}</small><strong>${esc(line.label)}</strong>${materials ? `<em>${materials}</em>` : ''}</span><b>${money(line.price)}</b></div>`;
    }).join('');
    document.getElementById('customer-quote-parts').textContent = money(quote.partsTotal || 0);
    document.getElementById('customer-quote-labor').textContent = money(quote.labor || 0);
    document.getElementById('customer-quote-total').textContent = money(data.total || quote.total || 0);
    customerQuoteRoot.querySelector('[data-quote-response="cash"]').classList.toggle('hidden', !(data.accounts || []).some(item => item.value === 'cash'));
    customerQuoteRoot.querySelector('[data-quote-response="bank"]').classList.toggle('hidden', !(data.accounts || []).some(item => item.value === 'bank'));
    customerQuoteRoot.classList.remove('hidden');
}

mechanicContent.addEventListener('input', event => {
    if (event.target.id === 'split-input') document.getElementById('split-value').textContent = `${event.target.value}%`;
    if (event.target.id === 'ecu-boost') document.getElementById('ecu-boost-value').textContent = `x${Number(event.target.value).toFixed(2)}`;
    if (event.target.id === 'ecu-launch-rpm') document.getElementById('ecu-launch-rpm-value').textContent = `${Number(event.target.value).toLocaleString()} RPM`;
});

const cardScrollSettles = new WeakMap();

function smoothlyRevealCard(card) {
    const grid = card.closest('.mechanic-grid');
    if (!grid) return false;
    const gridRect = grid.getBoundingClientRect();
    const cardRect = card.getBoundingClientRect();
    const edgePadding = 8;
    let movement = 0;
    if (cardRect.left < gridRect.left + edgePadding) {
        movement = cardRect.left - gridRect.left - edgePadding;
    } else if (cardRect.right > gridRect.right - edgePadding) {
        movement = cardRect.right - gridRect.right + edgePadding;
    }
    if (Math.abs(movement) < 2) return false;
    smoothScroll(grid, 'x', movement);
    cardScrollSettles.set(card, performance.now() + 280);
    return true;
}

mechanicContent.addEventListener('mouseover', event => {
    const card = event.target.closest('.mechanic-grid .mechanic-card');
    if (!card || card.contains(event.relatedTarget)) return;
    smoothlyRevealCard(card);
});

mechanicContent.addEventListener('mouseover', event => {
    const card = event.target.closest('.mechanic-card.requires-install-item');
    if (!card || card.contains(event.relatedTarget)) return;
    const data = card.querySelector('.install-requirement-data');
    if (!data) return;
    if (requirementHideTimer) clearTimeout(requirementHideTimer);
    if (requirementShowTimer) clearTimeout(requirementShowTimer);
    requirementHideTimer = null;
    requirementShowTimer = null;
    if (activeRequirementCard && activeRequirementCard !== card) {
        activeRequirementCard.classList.remove('requirements-active');
        activeRequirementCard = null;
        installRequirementPopover.classList.add('hidden');
    }
    pendingRequirementCard = card;
    const sequence = ++requirementHoverSequence;
    const revealDelay = Math.max(180, (cardScrollSettles.get(card) || 0) - performance.now());
    requirementShowTimer = setTimeout(() => {
        if (sequence !== requirementHoverSequence || pendingRequirementCard !== card || !card.isConnected || !card.matches(':hover')) return;
        requirementShowTimer = null;
        pendingRequirementCard = null;
        activeRequirementCard?.classList.remove('requirements-active');
        activeRequirementCard = card;
        card.classList.add('requirements-active');
        installRequirementPopover.innerHTML = `<div class="requirement-list">${data.innerHTML}</div>`;
        const categoryAccent = getComputedStyle(card).getPropertyValue('--card-accent').trim();
        installRequirementPopover.style.setProperty('--requirement-accent', categoryAccent || '#72e5eb');
        installRequirementPopover.classList.remove('hidden');
        positionInstallRequirements(card);
        requestAnimationFrame(updateRequirementOverflow);
    }, revealDelay);
});
mechanicContent.addEventListener('mouseout', event => {
    const card = event.target.closest('.mechanic-card.requires-install-item');
    if (!card || card.contains(event.relatedTarget)) return;
    if (pendingRequirementCard === card) {
        requirementHoverSequence += 1;
        pendingRequirementCard = null;
        if (requirementShowTimer) clearTimeout(requirementShowTimer);
        requirementShowTimer = null;
    }
    requirementHideTimer = setTimeout(hideInstallRequirements, 140);
});
installRequirementPopover.addEventListener('mouseenter', () => {
    requirementPointerInside = true;
    if (requirementHideTimer) clearTimeout(requirementHideTimer);
});
installRequirementPopover.addEventListener('mouseover', event => {
    const item = event.target.closest('.requirement-item');
    if (!item) return;
    const list = item.closest('.requirement-list');
    list?.querySelectorAll('.requirement-item.is-expanded').forEach(active => {
        if (active !== item) active.classList.remove('is-expanded');
    });
    item.classList.add('is-expanded');
    requestAnimationFrame(updateRequirementOverflow);
});
installRequirementPopover.addEventListener('mouseleave', () => {
    requirementPointerInside = false;
    hideInstallRequirements();
});
window.addEventListener('wheel', event => {
    if (!requirementPointerInside || installRequirementPopover.classList.contains('hidden')) return;
    const list = installRequirementPopover.querySelector('.requirement-list');
    if (!list) return;

    // Keep the tile beneath the cursor open while its horizontal strip moves.
    // Without this, leaving the tile for a wheel/scrollbar interaction can
    // collapse its width and temporarily remove the available scroll range.
    const hoveredItem = document.elementFromPoint(event.clientX, event.clientY)?.closest?.('.requirement-item');
    if (hoveredItem) hoveredItem.classList.add('is-expanded');
    if (list.scrollWidth <= list.clientWidth + 1) return;

    const rawDelta = Math.abs(event.deltaX) > Math.abs(event.deltaY) ? event.deltaX : event.deltaY;
    if (!rawDelta) return;
    const lineScale = event.deltaMode === 1 ? 18 : event.deltaMode === 2 ? list.clientWidth : 1;
    const scaledDelta = rawDelta * lineScale;
    const movement = Math.sign(scaledDelta) * Math.max(52, Math.abs(scaledDelta));
    list.scrollLeft = Math.max(0, Math.min(list.scrollWidth - list.clientWidth, list.scrollLeft + movement));
    event.preventDefault();
    event.stopPropagation();
    event.stopImmediatePropagation();
}, { capture: true, passive: false });
installRequirementPopover.addEventListener('transitionend', event => {
    if (event.target.closest('.requirement-item')) updateRequirementOverflow();
});
mechanicContent.addEventListener('scroll', queueRequirementPosition, true);

hotspotLayer.addEventListener('click', event => {
    const button = event.target.closest('[data-hotspot-key]'); if (!button) return;
    playUiSound('select');
    if (button.hasAttribute('data-hotspot-back')) {
        activeHotspotGroup = 'root';
        upgradeDrawer.classList.add('hidden');
        workshopSelection.textContent = 'SELECT A COMPONENT';
        updateHotspots(latestHotspotPoints);
        return;
    }
    if (button.dataset.categoryGroup) {
        const group = hotspotGroups[button.dataset.categoryGroup];
        if (group.direct) {
            const id = group.children[0];
            openWorkshopView(hotspotMeta[id][1], hotspotMeta[id][0]);
        } else {
            activeHotspotGroup = button.dataset.categoryGroup;
            upgradeDrawer.classList.add('hidden');
            workshopSelection.textContent = group.label;
            updateHotspots(latestHotspotPoints);
        }
        return;
    }
    if (!button.dataset.hotspot) return;
    const [label, view] = hotspotMeta[button.dataset.hotspot];
    hotspotLayer.querySelectorAll('.vehicle-hotspot').forEach(item => item.classList.toggle('selected', item === button));
    openWorkshopView(view, label);
});

document.getElementById('build-overview').addEventListener('click', () => openWorkshopView('installed', 'BUILD OVERVIEW'));
buildNameEdit.addEventListener('click', () => {
    carSettingsPanel.classList.add('hidden');
    ecuCustomPanel.classList.add('hidden');
    buildNameForm.classList.toggle('hidden');
    if (!buildNameForm.classList.contains('hidden')) {
        buildNameInput.focus(); buildNameInput.select(); playUiSound('select');
    }
});
carSettingsToggle.addEventListener('click', () => {
    buildNameForm.classList.add('hidden');
    ecuCustomPanel.classList.add('hidden');
    const opening = carSettingsPanel.classList.contains('hidden');
    carSettingsPanel.classList.toggle('hidden');
    if (opening) renderCarSettings();
    playUiSound(opening ? 'select' : 'hover');
});
carSettingsPanel.addEventListener('input', event => {
    if (event.target.id === 'settings-pressure') {
        document.getElementById('settings-pressure-value').textContent = `${Number(event.target.value).toFixed(1)} PSI`;
    }
    if (event.target.id === 'settings-split') {
        document.getElementById('settings-split-value').textContent = `${event.target.value}% FRONT`;
    }
    if (event.target.id === 'settings-audio-volume') {
        playerAudioSettings.volume = Number(event.target.value);
        savePlayerAudioSettings();
        document.getElementById('settings-audio-state').textContent = `ON // ${playerAudioSettings.volume}%`;
    }
});
carSettingsPanel.addEventListener('click', event => {
    const target = event.target.closest('button'); if (!target) return;
    if (target.hasAttribute('data-settings-close')) carSettingsPanel.classList.add('hidden');
    if (target.hasAttribute('data-settings-pressure')) mechanicFetch('pressure', { value: Number(document.getElementById('settings-pressure').value) });
    if (target.hasAttribute('data-settings-split')) mechanicFetch('split', { value: Number(document.getElementById('settings-split').value) });
    if (target.hasAttribute('data-settings-factory-split')) mechanicFetch('split', { value: 'FACTORY' });
    if (target.hasAttribute('data-settings-reset-ecu')) mechanicFetch('resetEcu');
    if (target.hasAttribute('data-settings-audio-toggle')) {
        playerAudioSettings.enabled = !playerAudioSettings.enabled;
        savePlayerAudioSettings();
        renderCarSettings();
    }
    if (target.hasAttribute('data-settings-audio-test')) playSequentialShiftSound('up', .12);
    if (target.hasAttribute('data-settings-nitro-auto')) {
        nitroAutoRefillEnabled = !nitroAutoRefillEnabled;
        try { localStorage.setItem('coii_torqueworks_nitro_auto_refill', String(nitroAutoRefillEnabled)); } catch (_) {}
        syncNitroAutoRefillPreference();
        renderCarSettings();
    }
    if (!target.hasAttribute('data-settings-audio-test')) playUiSound('action');
});
ecuCustomPanel.addEventListener('input', event => {
    if (event.target.id === 'custom-boost') {
        document.getElementById('custom-boost-value').textContent = `x${Number(event.target.value).toFixed(2)}`;
    }
    if (event.target.id === 'custom-launch-rpm') {
        document.getElementById('custom-launch-rpm-value').textContent = `${Number(event.target.value).toLocaleString()} RPM`;
    }
});
ecuCustomPanel.addEventListener('click', event => {
    const target = event.target.closest('button'); if (!target) return;
    if (target.hasAttribute('data-custom-close')) {
        ecuCustomPanel.classList.add('hidden');
        playUiSound('hover');
        return;
    }
    if (target.dataset.customPop) {
        ecuCustomPanel.querySelectorAll('[data-custom-pop]').forEach(button => button.classList.toggle('active', button === target));
        document.getElementById('custom-pops-value').textContent = target.dataset.customPop;
    }
    if (target.hasAttribute('data-custom-launch')) {
        target.classList.toggle('active');
        const enabled = target.classList.contains('active');
        target.textContent = enabled ? 'DISABLE' : 'ENABLE';
        document.getElementById('custom-launch-state').textContent = enabled ? 'ARMED' : 'OFF';
        document.getElementById('custom-launch-rpm').disabled = !enabled;
        document.getElementById('custom-launch-rpm-row').classList.toggle('setting-disabled', !enabled);
    }
    if (target.hasAttribute('data-custom-apply')) {
        const selectedPop = ecuCustomPanel.querySelector('[data-custom-pop].active');
        mechanicFetch('ecuCalibration', { value: {
            customEnabled: true,
            boost: Number(document.getElementById('custom-boost').value),
            pops: selectedPop?.dataset.customPop || 'OFF',
            launchEnabled: ecuCustomPanel.querySelector('[data-custom-launch]').classList.contains('active'),
            launchRpm: Number(document.getElementById('custom-launch-rpm').value)
        }});
        ecuCustomPanel.classList.add('hidden');
    }
    playUiSound('action');
});
buildNameForm.addEventListener('submit', event => {
    event.preventDefault();
    mechanicFetch('buildName', { value: buildNameInput.value });
    buildNameForm.classList.add('hidden');
    playUiSound('action');
});
document.getElementById('build-name-clear').addEventListener('click', () => {
    mechanicFetch('buildName', { value: '' });
    buildNameForm.classList.add('hidden');
    playUiSound('action');
});

let orbiting = false, lastPointerX = 0, lastPointerY = 0, cameraQueued = false, cameraDeltaX = 0, cameraDeltaY = 0;
function sendCamera(payload) {
    fetch(`https://${GetParentResourceName()}/mechanicCamera`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(payload)
    });
}
mechanicRoot.addEventListener('pointerdown', event => {
    if (event.target.closest('button, input, .upgrade-drawer, .quote-basket')) return;
    orbiting = true; lastPointerX = event.clientX; lastPointerY = event.clientY;
    mechanicRoot.setPointerCapture(event.pointerId);
});
mechanicRoot.addEventListener('pointerover', event => {
    const interactive = event.target.closest('.mechanic-card, .vehicle-hotspot, button');
    if (!interactive || interactive.contains(event.relatedTarget)) return;
    playUiSound('hover');
    const card = event.target.closest('.mechanic-card');
    if (card) {
        requestAnimationFrame(() => updateGridOverflow());
    }
});
upgradeDrawer.addEventListener('transitionend', event => {
    const card = event.target.closest?.('.mechanic-card');
    if (!card || (event.propertyName !== 'width' && event.propertyName !== 'flex-basis')) return;
    updateGridOverflow();
});
mechanicRoot.addEventListener('pointermove', event => {
    if (!orbiting) return;
    cameraDeltaX += event.clientX - lastPointerX; cameraDeltaY += event.clientY - lastPointerY;
    lastPointerX = event.clientX; lastPointerY = event.clientY;
    if (!cameraQueued) {
        cameraQueued = true;
        requestAnimationFrame(() => { sendCamera({ kind: 'orbit', x: cameraDeltaX, y: cameraDeltaY }); cameraDeltaX = 0; cameraDeltaY = 0; cameraQueued = false; });
    }
});
mechanicRoot.addEventListener('pointerup', () => { orbiting = false; });
mechanicRoot.addEventListener('pointercancel', () => { orbiting = false; });
mechanicRoot.addEventListener('wheel', event => {
    if (event.target.closest('.upgrade-drawer, .car-settings-panel, .quote-basket')) return;
    event.preventDefault(); sendCamera({ kind: 'zoom', value: Math.sign(event.deltaY) });
}, { passive: false });

quoteBasket.addEventListener('wheel', event => {
    smoothScroll(quoteLinesRoot, 'y', event.deltaY);
    event.preventDefault();
    event.stopPropagation();
}, { passive: false });

upgradeDrawer.addEventListener('wheel', event => {
    const grid = event.target.closest('.mechanic-grid') || upgradeDrawer.querySelector('.mechanic-grid');
    if (!grid) return;
    const delta = Math.abs(event.deltaX) > Math.abs(event.deltaY) ? event.deltaX : event.deltaY;
    if (!delta || grid.scrollWidth <= grid.clientWidth + 1) return;
    smoothScroll(grid, 'x', delta * 0.72);
    event.preventDefault();
    event.stopPropagation();
}, { passive: false });

window.addEventListener('resize', () => requestAnimationFrame(updateGridOverflow));

function closeMechanicUi() {
    fetch(`https://${GetParentResourceName()}/mechanicClose`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: '{}' });
}
document.getElementById('mechanic-close').addEventListener('click', closeMechanicUi);
function closeBuildCard() {
    fetch(`https://${GetParentResourceName()}/buildCardClose`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: '{}'
    });
}

function renderBuildCard(card) {
    buildCardState = card;
    document.getElementById('build-card-manufacturer').textContent = (card.manufacturer || 'CUSTOM').toUpperCase();
    document.getElementById('build-card-model').textContent = card.modelName || 'VEHICLE';
    const name = document.getElementById('build-card-name');
    name.textContent = card.buildName ? `"${card.buildName}"` : card.plate;
    const performance = card.performance || {};
    const metric = (value, suffix, digits = 0) => value == null ? 'NO RECORD' : `${Number(value).toFixed(digits)} ${suffix}`;
    document.getElementById('build-card-performance').innerHTML = `
        <article><span>WHEEL POWER</span><strong>${metric(performance.whp, 'WHP')}</strong></article>
        <article><span>WHEEL TORQUE</span><strong>${metric(performance.torque, 'NM')}</strong></article>
        <article><span>BEST 100-200</span><strong>${metric(performance.best100to200, 'SEC', 2)}</strong></article>`;
    const labels = { turbo: 'TURBO', engine: 'ENGINE', transmission: 'TRANSMISSION', differential: 'DIFFERENTIAL', tires: 'TIRES', ecuMap: 'ECU MAP' };
    document.getElementById('build-card-parts').innerHTML = card.parts
        ? Object.entries(labels).map(([key, label]) => `<article><span>${label}</span><strong>${esc(card.parts[key] || 'FACTORY')}</strong></article>`).join('')
        : '<p class="performance-only">PERFORMANCE-ONLY BUILD</p>';
    const owner = document.getElementById('build-card-owner');
    owner.classList.toggle('hidden', !card.isOwner);
    owner.querySelectorAll('button').forEach(button => button.classList.toggle('active', button.dataset.visibility === card.visibility));
    buildCardRoot.classList.remove('hidden');
}

function renderBuildPreview(card) {
    if (buildPreviewHideTimer) { clearTimeout(buildPreviewHideTimer); buildPreviewHideTimer = null; }
    const accent = card.accent || { r: 98, g: 229, b: 236 };
    buildPreviewRoot.style.setProperty('--vehicle-r', Number(accent.r) || 0);
    buildPreviewRoot.style.setProperty('--vehicle-g', Number(accent.g) || 0);
    buildPreviewRoot.style.setProperty('--vehicle-b', Number(accent.b) || 0);
    document.getElementById('preview-manufacturer').textContent = (card.manufacturer || 'CUSTOM').toUpperCase();
    document.getElementById('preview-model').textContent = card.modelName || 'VEHICLE';
    document.getElementById('preview-name').textContent = card.buildName
        ? `BUILD #${card.buildName.toUpperCase()}`
        : card.plate;
    const vehicleClass = card.vehicleClass || { label: 'D', rating: 100 };
    document.getElementById('preview-class').textContent = `${vehicleClass.label} ${vehicleClass.rating}`;
    const performance = card.performance || {};
    const value = (number, suffix) => number == null ? '--' : `${Math.round(Number(number))} ${suffix}`;
    document.getElementById('preview-performance').innerHTML = `
        <article><span>POWER</span><b>${value(performance.whp, 'WHP')}</b></article>
        <article><span>TORQUE</span><b>${value(performance.torque, 'NM')}</b></article>
        <article><span>100-200</span><b>${performance.best100to200 == null ? '--' : `${Number(performance.best100to200).toFixed(2)} S`}</b></article>`;
    const parts = card.parts || {};
    const previewPart = (icon, label, text) => `<article><span class="preview-part-icon">${hotspotIcon(icon)}</span><div><small>${label}</small><strong>${esc(text || '')}</strong></div></article>`;
    const partSet = card.parts ? [
        previewPart('engine', 'ENGINE', parts.engine), previewPart('turbo', 'TURBO', parts.turbo), previewPart('nitro', 'NITROUS', parts.nitro),
        previewPart('transmission', 'TRANSMISSION', parts.transmission), previewPart('differential', 'DIFFERENTIAL', parts.differential),
        previewPart('tires', 'TIRES', parts.tires), previewPart('brakes', 'BRAKES', parts.brakes), previewPart('suspension', 'SUSPENSION', parts.suspension), previewPart('ecu', 'ECU MAP', parts.ecuMap)
    ].join('') : '';
    document.getElementById('preview-parts').innerHTML = card.parts
        ? `<div class="preview-stat-track"><div class="preview-stat-set">${partSet}</div><div class="preview-stat-set" aria-hidden="true">${partSet}</div></div>`
        : '<span>PERFORMANCE ONLY</span>';
    buildPreviewRoot.classList.remove('hidden', 'is-leaving');
    buildPreviewRoot.classList.remove('is-entering');
    void buildPreviewRoot.offsetWidth;
    buildPreviewRoot.classList.add('is-entering');
}

document.getElementById('build-card-close').addEventListener('click', closeBuildCard);
document.getElementById('build-card-owner').addEventListener('click', event => {
    const button = event.target.closest('[data-visibility]'); if (!button) return;
    fetch(`https://${GetParentResourceName()}/buildCardVisibility`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ visibility: button.dataset.visibility })
    });
});
document.addEventListener('keydown', event => {
    if (event.key !== 'Escape') return;
    if (!buildCardRoot.classList.contains('hidden')) closeBuildCard();
    else if (!mechanicRoot.classList.contains('hidden')) closeMechanicUi();
});

window.addEventListener('message', ({ data }) => {
    if (data.action === 'nitroSound') {
        setNitroSound(data.enabled === true, data.volume);
    } else if (data.action === 'nitroHud') {
        if (data.visible === false) {
            if (data.immediate === true) {
                if (nitroHudHideTimer) clearTimeout(nitroHudHideTimer);
                nitroHudHideTimer = null;
                nitroHud.classList.add('hidden');
                nitroHud.classList.remove('is-leaving');
                nitroCooldown.classList.add('hidden');
                return;
            }
            nitroHud.classList.add('is-leaving');
            if (nitroHudHideTimer) clearTimeout(nitroHudHideTimer);
            nitroHudHideTimer = setTimeout(() => {
                nitroHud.classList.add('hidden');
                nitroHudHideTimer = null;
            }, 220);
        } else {
            if (nitroHudHideTimer) {
                clearTimeout(nitroHudHideTimer);
                nitroHudHideTimer = null;
            }
            const level = Math.max(0, Math.min(1, Number(data.level) || 0));
            nitroHudFill.style.transform = `scaleY(${level})`;
            if (Number(data.cooldown) > 0) {
                nitroCooldown.classList.remove('hidden');
                nitroDelayLabel.textContent = data.delayLabel || 'READY IN';
                nitroCooldown.querySelector('b').textContent = Number(data.cooldown).toFixed(1);
            } else {
                nitroCooldown.classList.add('hidden');
            }
            nitroHud.classList.remove('hidden', 'is-leaving');
        }
    } else if (data.action === 'manualShiftSound') {
        playSequentialShiftSound(data.direction, data.volume);
    } else if (data.action === 'turboWastegateSound') {
        playTurboWastegateSound(data.file, data.volume, data.force === true, data.test === true,
            data.spatial, data.maxDistance);
    } else if (data.action === 'buildCardOpen') {
        buildPreviewRoot.classList.add('hidden');
        renderBuildCard(data.card);
    } else if (data.action === 'buildCardClose') {
        buildCardRoot.classList.add('hidden'); buildCardState = null;
    } else if (data.action === 'buildCardPreview') {
        renderBuildPreview(data.card);
    } else if (data.action === 'buildCardPreviewHide') {
        buildPreviewRoot.classList.remove('is-entering');
        buildPreviewRoot.classList.add('is-leaving');
        if (buildPreviewHideTimer) clearTimeout(buildPreviewHideTimer);
        buildPreviewHideTimer = setTimeout(() => {
            buildPreviewRoot.classList.add('hidden');
            buildPreviewRoot.classList.remove('is-leaving');
            buildPreviewHideTimer = null;
        }, 260);
    } else if (data.action === 'buildCardPreviewPosition') {
        buildPreviewRoot.classList.toggle('projected-hidden', !data.visible);
        if (data.visible) {
            buildPreviewRoot.style.left = `${data.x * 100}%`;
            buildPreviewRoot.style.top = `${data.y * 100}%`;
        }
    } else if (data.action === 'buildCardPreviewAccent') {
        const accent = data.accent || {};
        buildPreviewRoot.style.setProperty('--vehicle-r', Number(accent.r) || 0);
        buildPreviewRoot.style.setProperty('--vehicle-g', Number(accent.g) || 0);
        buildPreviewRoot.style.setProperty('--vehicle-b', Number(accent.b) || 0);
    } else if (data.action === 'mechanicOpen') {
        syncNitroAutoRefillPreference();
        activeHotspotGroup = 'root';
        latestHotspotPoints = [];
        mechanicState = { build: data.build, vehicleClass: data.vehicleClass, workshop: data.workshop || null, lockedParts: data.lockedParts || {}, installationBypass: data.installationBypass === true, catalogs: data.catalogs, history: data.history || [], workOrder: data.workOrder || null, view: 'installed' };
        quoteSelection.clear();
        renderQuoteBasket();
        mechanicPlate.textContent = data.plate;
        mechanicClass.textContent = `${data.vehicleClass?.label || 'D'} ${data.vehicleClass?.rating || 100}`;
        displayBuildName(data.build?.buildName);
        if (mechanicHotspotIntroTimer) clearTimeout(mechanicHotspotIntroTimer);
        mechanicRoot.classList.add('hotspots-entering', 'is-preparing');
        mechanicRoot.classList.remove('hidden');
        upgradeDrawer.classList.add('hidden');
        hotspotLayer.innerHTML = '';
        workshopSelection.textContent = data.workshop?.name || 'SELECT A COMPONENT';
        updateHotspots(Object.keys(hotspotMeta).map(id => ({ id, visible: false, x: -1, y: -1 })));
        document.querySelectorAll('#mechanic-nav button').forEach(button => button.classList.toggle('active', button.dataset.view === 'installed'));
        renderMechanic();
        requestAnimationFrame(() => requestAnimationFrame(() => {
            updateGridOverflow();
            mechanicRoot.classList.remove('is-preparing');
            playUiSound('open');
        }));
        mechanicHotspotIntroTimer = setTimeout(() => {
            mechanicRoot.classList.remove('hotspots-entering');
            mechanicHotspotIntroTimer = null;
        }, 1500);
    } else if (data.action === 'mechanicBuild') {
        mechanicState.build = data.build; mechanicState.vehicleClass = data.vehicleClass;
        mechanicClass.textContent = `${data.vehicleClass?.label || 'D'} ${data.vehicleClass?.rating || 100}`;
        displayBuildName(data.build?.buildName); renderMechanic();
    } else if (data.action === 'customerQuote') {
        showCustomerQuote(data.quote);
    } else if (data.action === 'mechanicHotspots') {
        updateHotspots(data.points || []);
    } else if (data.action === 'mechanicClose') {
        if (mechanicHotspotIntroTimer) clearTimeout(mechanicHotspotIntroTimer);
        mechanicHotspotIntroTimer = null;
        mechanicRoot.classList.remove('hotspots-entering');
        activeHotspotGroup = 'root';
        latestHotspotPoints = [];
        mechanicRoot.classList.add('hidden');
        buildNameForm.classList.add('hidden');
        carSettingsPanel.classList.add('hidden');
        ecuCustomPanel.classList.add('hidden');
        hotspotLayer.innerHTML = '';
    }
});

mechanicRoot.classList.add('hidden');
