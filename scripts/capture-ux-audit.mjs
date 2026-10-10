import { chromium } from 'playwright'
import { mkdir } from 'node:fs/promises'

const label=process.argv[2]||'current'
const baseURL=process.env.AUDIT_BASE_URL||'http://127.0.0.1:5173'
const output='docs/ux-audit'
await mkdir(output,{recursive:true})

async function capture(name,viewport){
  const browser=await chromium.launch({headless:true})
  const page=await browser.newPage({viewport})
  await page.goto(baseURL)
  await page.evaluate(()=>localStorage.clear())
  await page.reload()
  await page.screenshot({path:`${output}/${label}-${name}-home.png`,fullPage:true})
  await page.getByRole('button',{name:/Explore approved buyer demo/}).click()
  await page.getByRole('searchbox').fill('paracetamol')
  await page.getByRole('button',{name:'Add MOQ to cart'}).click()
  await page.getByRole('button',{name:/Open wholesale cart/}).click()
  await page.getByRole('dialog').getByRole('button',{name:'Review order request'}).click()
  await page.screenshot({path:`${output}/${label}-${name}-checkout.png`,fullPage:true})
  await page.getByRole('dialog').getByRole('button',{name:'Submit demo order request'}).click()
  await page.screenshot({path:`${output}/${label}-${name}-confirmation.png`,fullPage:true})
  await browser.close()
}

await capture('desktop',{width:1440,height:1000})
await capture('mobile',{width:390,height:844})
