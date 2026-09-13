const value=id=>document.getElementById(id);
const resourceName=typeof GetParentResourceName==='function'?GetParentResourceName():'coii_torqueworks';
const post=(name,data={})=>fetch(`https://${resourceName}/${name}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)}).catch(()=>{});
const safeColor=value=>typeof value==='string'&&value.length<=64&&/^(#(?:[0-9a-f]{3,4}|[0-9a-f]{6}|[0-9a-f]{8})|rgba?\([\d\s.,%]+\)|hsla?\([\d\s.,%]+\))$/i.test(value.trim())?value.trim():null;
function applyTheme(theme){const colors=theme&&theme.colors||{},categories=theme&&theme.categories||{},root=document.documentElement;const values={'--mmi-accent':colors.accent||categories.electronics,'--mmi-background':colors.background,'--mmi-surface':colors.surface,'--mmi-text':colors.text,'--mmi-muted':colors.muted,'--mmi-border':colors.border,'--mmi-error':colors.error};Object.entries(values).forEach(([name,value])=>{const safe=safeColor(value);if(safe)root.style.setProperty(name,safe)});root.classList.toggle('tw-no-carbon',theme&&theme.effects&&theme.effects.carbonTexture===false)}
let settings={};
value('close').addEventListener('click',()=>post('mmiClose'));
document.querySelectorAll('[data-page]').forEach(button=>button.addEventListener('click',()=>{document.querySelectorAll('[data-page]').forEach(item=>item.classList.toggle('active',item===button));document.querySelectorAll('.page').forEach(page=>page.classList.toggle('active',page.id===button.dataset.page));}));
value('pressure').addEventListener('input',event=>value('pressure-value').textContent=`${Number(event.target.value).toFixed(1)} PSI`);
value('pressure').addEventListener('change',event=>post('mmiAction',{action:'pressure',value:Number(event.target.value)}));
value('split').addEventListener('input',event=>value('split-value').textContent=`${event.target.value}% FRONT`);
value('split').addEventListener('change',event=>post('mmiAction',{action:'split',value:Number(event.target.value)}));
value('factory-split').addEventListener('click',()=>post('mmiAction',{action:'split',value:'FACTORY'}));
value('auto-refill').addEventListener('click',()=>{settings.autoRefill=!settings.autoRefill;post('mmiAction',{action:'autoRefill',value:settings.autoRefill});syncSettings();});
function syncSettings(){const pressure=Number(settings.pressure)||32;value('pressure').value=pressure;value('pressure-value').textContent=`${pressure.toFixed(1)} PSI`;const factory=Number(settings.split)<0;const split=factory?50:Math.round(Number(settings.split)*100);const splitLocked=settings.differential!=='ACTIVE';value('split').value=split;value('split').disabled=splitLocked;value('factory-split').disabled=splitLocked;value('split-setting').classList.toggle('locked',splitLocked);value('split-value').textContent=splitLocked?'ACTIVE LSD REQUIRED':(factory?'FACTORY':`${split}% FRONT`);value('auto-refill').textContent=settings.autoRefill===false?'OFF':'ON';value('auto-refill').classList.toggle('selected',settings.autoRefill!==false);}
let bootStarted=false;
function startBoot(data){if(bootStarted)return;bootStarted=true;value('boot-name').textContent=String(data.vehicleName||'VEHICLE').toUpperCase();value('boot-plate').textContent=data.plate||'MMI SYSTEM';setTimeout(()=>value('boot-message').textContent='READING TORQUEWORKS',700);setTimeout(()=>value('boot-message').textContent='CALIBRATION VERIFIED',1450);setTimeout(()=>value('boot-message').textContent='SYSTEM READY',2050);setTimeout(()=>value('boot').classList.add('complete'),2450);setTimeout(()=>document.body.classList.remove('booting'),2850);}
window.addEventListener('message',event=>{const data=event.data;if(!data||data.action!=='telemetry')return;if(data.theme)applyTheme(data.theme);startBoot(data);settings=data.settings||settings;syncSettings();value('vehicle-name').textContent=String(data.vehicleName||'VEHICLE').toUpperCase();value('plate').textContent=data.plate||'MMI';value('build').textContent=data.buildName?`BUILD #${data.buildName.toUpperCase()}`:'FACTORY BUILD';value('map').textContent=data.map||'MAP 1';value('rpm').textContent=Math.max(0,Math.round(Number(data.rpm)||0)).toLocaleString();const gear=Number(data.gear)||0;value('gear').textContent=gear<=0?'N':gear;value('speed').textContent=Math.max(0,Math.round(Number(data.speed)||0));value('boost').textContent=Math.max(0,Number(data.boost)||0).toFixed(2);value('nitro').textContent=Math.round(Math.max(0,Math.min(1,Number(data.nitro)||0))*100);value('brakes').textContent=Math.max(0,Math.round(Number(data.brakeTemperature)||0));});

let keyboardSelection = 0;
const keyboardControls = () => [...document.querySelectorAll('button,select,input')].filter(element => {
    const page = element.closest('.page');
    return !element.disabled && (!page || page.classList.contains('active'));
});
function selectKeyboardControl(index) {
    const controls = keyboardControls();
    if (!controls.length) return;
    keyboardSelection = (index + controls.length) % controls.length;
    document.querySelectorAll('.key-selected').forEach(element => element.classList.remove('key-selected'));
    controls[keyboardSelection].classList.add('key-selected');
    controls[keyboardSelection].scrollIntoView({ block: 'nearest', inline: 'nearest' });
}
function adjustKeyboardControl(element, direction) {
    if (element.matches('input[type="range"]')) {
        const next = Math.max(Number(element.min), Math.min(Number(element.max),
            Number(element.value) + Number(element.step || 1) * direction));
        element.value = next;
        element.dispatchEvent(new Event('input', { bubbles: true }));
        element.dispatchEvent(new Event('change', { bubbles: true }));
        return true;
    }
    if (element.tagName === 'SELECT') {
        element.selectedIndex = Math.max(0, Math.min(element.options.length - 1,
            element.selectedIndex + direction));
        element.dispatchEvent(new Event('change', { bubbles: true }));
        return true;
    }
    return false;
}
window.addEventListener('message', event => {
    const data = event.data;
    if (!data || data.action !== 'keyboard') return;
    const controls = keyboardControls();
    if (!controls.length) return;
    let selected = document.querySelector('.key-selected');
    let index = controls.indexOf(selected);
    if (index < 0) { selectKeyboardControl(0); selected = keyboardControls()[0]; index = 0; }
    if (data.key === 'ArrowUp') selectKeyboardControl(index - 1);
    if (data.key === 'ArrowDown') selectKeyboardControl(index + 1);
    if (data.key === 'ArrowLeft' && !adjustKeyboardControl(selected, -1)) selectKeyboardControl(index - 1);
    if (data.key === 'ArrowRight' && !adjustKeyboardControl(selected, 1)) selectKeyboardControl(index + 1);
    if (data.key === 'Enter') selected.click();
});
selectKeyboardControl(0);
