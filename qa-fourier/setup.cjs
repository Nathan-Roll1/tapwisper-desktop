const { chromium } = require('/tmp/tap-cdp/node_modules/playwright-core');
(async () => {
    const browser = await chromium.connectOverCDP('http://127.0.0.1:9222');
    let page;
    for (let i = 0; i < 100; ++i) {
        for (const p of browser.contexts()[0].pages()) {
            if (await p.evaluate(() => !!window.tapwisper?.store).catch(() => false)) {page=p;break;}
        }
        if (page) break;
        await new Promise(r=>setTimeout(r,400));
    }
    if (!page) throw Error('Cannot locate renderer with public preload');
    await page.evaluate(async ()=>{
        const api=window.tapwisper;
        const id='oruk-fourier-2b';
        await api.store.set('onboardingCompleted',true);
        await api.store.set('speechEngine','local');
        await api.store.set('shortcuts',{record:'Ctrl+Space'});
        await api.store.set('localModels',{stt:id,llm:null});
        const settings=await api.store.get('localAi');
        await api.store.set('localAi',{...settings,useGpu:false,threads:4});
        const result=await api.localAi.download(id);
        if(!result.ok) throw Error(JSON.stringify(result));
        if(!(await api.localAi.installed()).includes(id)) throw Error('Model missing from installed list');
    });
    console.log('Downloaded both files through Electron preload and product IPC.');
    await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
