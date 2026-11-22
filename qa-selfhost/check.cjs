const fs = require('node:fs')
const {chromium} = require('playwright-core')

async function main() {
  const browser = await chromium.connectOverCDP('http://127.0.0.1:9222')
  try {
    let page
    for (let n = 0; n < 90 && !page; ++n) {
      for (const p of browser.contexts()[0].pages()) {
        if (await p.evaluate(() => !!window.tapwisper?.store).catch(() => false)) {
          page = p
          break
        }
      }
      if (!page) await new Promise(r => setTimeout(r, 500))
    }
    if (!page) throw Error('The released app did not expose its settings API')
    const available = await page.evaluate(() => Object.keys(window.tapwisper.selfHosted ?? {}))
    console.log('RELEASE_SELF_HOSTED_METHODS', JSON.stringify(available))
    if (!available.includes('transcribe')) throw Error('No self-hosted transcription in this released binary')
    if (process.argv.includes('--preflight')) return
    const sample = fs.readFileSync('/tmp/jfk.wav').toString('base64')
    const output = await page.evaluate(async (sample) => {
      const app = window.tapwisper
      const server = {baseUrl: 'http://127.0.0.1:8098', model:'oruk-fourier-2b'}
      const listing = await app.selfHosted.test('stt',{...server, apiKey:''})
      if (!listing.ok || !JSON.stringify(listing).includes(server.model)) throw Error(JSON.stringify(listing))
      const existing = await app.store.get('selfHosted')
      await app.store.set('selfHosted',{...existing, stt:server})
      const wav = Uint8Array.from(atob(sample), c => c.charCodeAt(0))
      const result = await app.selfHosted.transcribe({wav, seconds:11, language:'en'})
      return {listing,result}
    },sample)
    console.log('RELEASE_SERVER_RESULT',JSON.stringify(output))
    if (!output.result.ok || !JSON.stringify(output.result).toLowerCase().includes('my fellow americans')) throw Error('Unexpected transcription')
    const text = Object.values(output.result).find(v=>typeof v ==='string')
    const reference = 'and so my fellow americans ask not what your country can do for you ask what you can do for your country'
    if (text.toLowerCase().match(/[a-z]+/g).join(' ') !== reference) throw Error('Reference differed')
  } finally { await browser.close() }
}
main().catch(e=>{console.error(e);process.exitCode=1})
