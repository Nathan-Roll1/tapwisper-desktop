const { chromium } = require('/tmp/tap-cdp/node_modules/playwright-core');
(async () => {
    const browser=await chromium.connectOverCDP('http://127.0.0.1:9222');
    async function hook(p) {
        const url=p.url().split('/').slice(-1)[0];
        p.on('console',m=>console.log('renderer',url,m.type(),m.text().slice(0,300)));
        p.on('pageerror',e=>console.log('renderer error',url,e.message));
        await p.evaluate(async ()=>{
            const tap=window.tapwisper;
            if(!tap) return;
            for(const name of ['recording:start','recording:stop','recording:error','recording:cancel','result-panel:result','result-panel:error']) tap.on(name,v=>console.log('event',name,JSON.stringify(v)));
            console.log('engine',await tap.store.get('speechEngine'),await tap.store.get('localModels'));
            const devices=await navigator.mediaDevices?.enumerateDevices();
            console.log('audio inputs',devices?.filter(d=>d.kind==='audioinput').map(d=>d.label));
        }).catch(()=>{});
    }
    const ctx=browser.contexts()[0];ctx.on('page',p=>p.on('domcontentloaded',()=>hook(p)));for(const p of ctx.pages()) await hook(p);
    await new Promise(()=>{});
})().catch(e=>{console.error(e);process.exit(1)});
