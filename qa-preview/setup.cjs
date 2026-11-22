const {chromium}=require('/tmp/tap-cdp/node_modules/playwright-core');
(async()=>{
  const browser=await chromium.connectOverCDP('http://127.0.0.1:9222');
  const ctx=browser.contexts()[0];
  let page;
  const deadline=Date.now()+60_000;
  while(Date.now()<deadline){
    page=ctx.pages().find(p=>p.url().endsWith('#/main'));
    if(page&&await page.evaluate(()=>!!window.tapwisper?.store).catch(()=>false))break;
    await new Promise(r=>setTimeout(r,300));
  }
  if(!page)throw Error('Packaged main window not found');
  page.setDefaultTimeout(40_000);
  try{
    if(!page.url().includes('app.asar/'))throw Error('Expected packaged application page, got '+page.url());
    // Set onboarding / fixture-hotkey defaults only. Download and selection below use UI controls.
    await page.evaluate(async()=>{
      const api=window.tapwisper;
      if((await api.localAi.installed()).includes('oruk-fourier-2b'))throw Error('Model was already installed');
      await api.store.set('onboardingCompleted',true);
      await api.store.set('speechLanguages',['en']);
      await api.store.set('shortcuts',{record:'Ctrl+Space'});
      const prefs=await api.store.get('localAi');
      await api.store.set('localAi',{...prefs,useGpu:false,threads:4});
    });
    await page.reload();
    await page.getByRole('button',{name:'Settings',exact:true}).click();
    await page.getByRole('tab',{name:/speech.to.text/i}).click();
    await page.getByRole('radio',{name:/^Local\b/}).click();
    await page.getByRole('radio',{name:'Qwen3-ASR',exact:true}).click();
    const name=page.getByText('Oruk Fourier 2B',{exact:true});
    await name.waitFor();
    const row=name.locator('xpath=../../..');
    console.log('Packaged UI before selection:',await row.innerText());
    await row.getByRole('button',{name:'Download',exact:true}).click();
    // Wait on actual UI state across native promises, while allowing either autoactivation or an explicit Use.
    const confirm=page.locator('[role="dialog"],[role="alertdialog"]').getByRole('button',{name:'Download',exact:true});
    const inUse=row.getByText('In use',{exact:true});
    const use=row.getByRole('button',{name:'Use',exact:true});
    const started=Date.now();
    while(Date.now()-started<540000) {
      if(await confirm.isVisible()) await confirm.click();
      if(await use.isVisible()) await use.click();
      if(await inUse.isVisible()) break;
      await new Promise(r=>setTimeout(r,600));
    }
    if(!await inUse.isVisible()) throw Error('Fourier never reached In use in the packaged picker: '+await row.innerText());
    const selection=await page.evaluate(async()=>({
      installed:await window.tapwisper.localAi.installed(),
      active:(await window.tapwisper.store.get('localModels')).stt
    }));
    if(!selection.installed.includes('oruk-fourier-2b')||selection.active!=='oruk-fourier-2b') throw Error('Stored selection: '+JSON.stringify(selection));
    console.log('Persisted active model',selection.active,'and installed inventory',selection.installed);
    console.log('Packaged UI after selection:',await row.innerText());
    await page.screenshot({path:'/tmp/tap-picker.png'});
  }catch(e){
    console.log('Packaged page URL:',page.url(),'body:',(await page.locator('body').innerText()).slice(-4500));
    await page.screenshot({path:'/tmp/tap-picker.png'}).catch(()=>{});
    throw e;
  }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
