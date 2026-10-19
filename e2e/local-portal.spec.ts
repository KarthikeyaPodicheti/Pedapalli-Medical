import { expect, test } from '@playwright/test'
import { readFileSync } from 'node:fs'
import ExcelJS from 'exceljs'

test('staff previews and applies a stock spreadsheet on desktop and mobile',async({page,context},testInfo)=>{
  const file=process.env.LOCAL_TEST_STAFF_COOKIE_FILE
  test.skip(!file,'Requires the disposable full-stack staff fixture')
  const token=readFileSync(file!,'utf8').split('\n').find(line=>line.includes('\tpm_session\t'))!.split('\t').at(-1)!
  await context.addCookies([{name:'pm_session',value:token,domain:'localhost',path:'/api',httpOnly:true,sameSite:'Strict'}])
  const errors:string[]=[];page.on('pageerror',error=>errors.push(error.message))
  await page.goto('/')
  await page.getByRole('button',{name:'Batch inventory'}).click()
  await expect(page.getByRole('heading',{name:'Controlled stock import'})).toBeVisible()
  const suffix=testInfo.project.name
  await page.getByLabel('Source / GRN reference').fill(`UI-${suffix}`)
  const expiry=new Date(Date.now()+500*86400000).toISOString().slice(0,10)
  const rows=[['sku','wholesale_unit','batch_number','expiry_date','quantity','price_paise','mrp_paise'],['IMPORT-API','pack',`BATCH-${suffix}`,expiry,'5','1000','1200']]
  if(suffix.includes('mobile')){
    const workbook=new ExcelJS.Workbook();workbook.addWorksheet('Import').addRows(rows)
    await page.getByLabel('CSV or XLSX').setInputFiles({name:'import.xlsx',mimeType:'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',buffer:Buffer.from(await workbook.xlsx.writeBuffer())})
  }else await page.getByLabel('CSV or XLSX').setInputFiles({name:'import.csv',mimeType:'text/csv',buffer:Buffer.from(rows.map(row=>row.join(',')).join('\n'))})
  await page.getByRole('button',{name:'Validate and preview'}).click()
  await expect(page.getByRole('button',{name:'Confirm all 1 rows'})).toBeVisible()
  await page.getByRole('button',{name:'Confirm all 1 rows'}).click()
  await expect(page.getByRole('status')).toContainText('Import applied once')
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true)
  expect(errors).toEqual([])
})

test('a buyer can register, sign in and submit a real pending application',async({page},testInfo)=>{
  const suffix=testInfo.project.name.replace(/[^a-z]/g,'').slice(-8)
  const email=`ui-${suffix}@example.in`
  const errors:string[]=[]
  page.on('pageerror',error=>errors.push(error.message))
  await page.goto('/')
  await expect(page.getByRole('heading',{name:'One safe ordering desk for your medical store.'})).toBeVisible()
  await page.getByRole('button',{name:'Create buyer account'}).click()
  await page.getByLabel('Email').fill(email)
  await page.getByLabel('Password').fill('Synthetic buyer password 2026!')
  await page.getByRole('button',{name:'Create account'}).click()
  await expect(page.getByText('Buyer account created.')).toBeVisible()
  await page.getByLabel('Email').fill(email)
  await page.getByLabel('Password').fill('Synthetic buyer password 2026!')
  await page.getByRole('button',{name:'Sign in securely'}).click()
  await expect(page.getByRole('heading',{name:'Tell us about your medical store'})).toBeVisible()
  await page.getByLabel('Business or trading name').fill('UI Test Medical Store')
  await page.getByLabel('Contact person').fill('UI Buyer')
  await page.getByLabel('Indian mobile number').fill('9876543212')
  await expect(page.getByLabel('GSTIN (optional)')).not.toHaveAttribute('required')
  await page.getByLabel('Drug-licence number').fill(`DL-UI-${suffix}`)
  await page.getByLabel('PIN code').fill('505172')
  await page.getByLabel('Registered business address').fill('Market Road, Peddapalli, Telangana')
  await page.getByRole('button',{name:'Submit for verification'}).click()
  await expect(page.getByRole('heading',{name:'Verification pending'})).toBeVisible()
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true)
  expect(errors).toEqual([])
})
