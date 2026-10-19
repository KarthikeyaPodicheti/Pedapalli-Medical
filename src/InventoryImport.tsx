import { useEffect, useState, type FormEvent } from 'react'
import { DownloadSimple, FileArrowUp, CheckCircle } from '@phosphor-icons/react'
import { localApi, type InventoryImport } from './local-api'
import { parseCsv } from './validation'

// Reject oversized expanded ZIP archives before asking ExcelJS to decompress.
function checkWorkbook(buffer:ArrayBuffer){
  const view=new DataView(buffer);let end=-1
  for(let i=buffer.byteLength-22;i>=Math.max(0,buffer.byteLength-65557);i--)if(view.getUint32(i,true)===0x06054b50){end=i;break}
  if(end<0)throw new Error('Invalid XLSX archive.')
  const entries=view.getUint16(end+10,true);let offset=view.getUint32(end+16,true),expanded=0
  if(entries>200||view.getUint16(end+4,true)!==0||view.getUint16(end+6,true)!==0)throw new Error('Use a simple workbook with one worksheet.')
  for(let i=0;i<entries;i++){
    if(offset+46>buffer.byteLength||view.getUint32(offset,true)!==0x02014b50)throw new Error('Invalid workbook directory.')
    expanded+=view.getUint32(offset+24,true)
    if(expanded>8*1024*1024)throw new Error('Expanded workbook exceeds 8 MB. Export a smaller CSV.')
    offset+=46+view.getUint16(offset+28,true)+view.getUint16(offset+30,true)+view.getUint16(offset+32,true)
  }
}
export async function readInventoryFile(file:File){
  if(file.size>1024*1024)throw new Error('Use a file under 1 MB.')
  if(file.name.toLowerCase().endsWith('.csv'))return parseCsv(await file.text())
  if(!file.name.toLowerCase().endsWith('.xlsx'))throw new Error('Choose a CSV or XLSX file.')
  const buffer=await file.arrayBuffer();checkWorkbook(buffer)
  const ExcelJS=await import('exceljs'),workbook=new ExcelJS.Workbook();await workbook.xlsx.load(buffer)
  if(workbook.worksheets.length!==1)throw new Error('Use exactly one worksheet.')
  const sheet=workbook.worksheets[0]
  if(sheet.rowCount>501||sheet.columnCount!==7)throw new Error('Use the seven template columns and at most 500 data rows.')
  const rows:string[][]=[]
  sheet.eachRow({includeEmpty:true},row=>{
    const values:string[]=[]
    for(let column=1;column<=7;column++){
      const cell=row.getCell(column)
      if(![ExcelJS.ValueType.Null,ExcelJS.ValueType.String,ExcelJS.ValueType.Number].includes(cell.type))throw new Error(`Row ${row.number}: use plain values; expiry dates must be text in YYYY-MM-DD format.`)
      values.push(cell.text)
    }
    rows.push(values)
  })
  return rows
}
export default function InventoryImportPanel({role,onApplied}:{role:string;onApplied:()=>Promise<void>}){
  const [history,setHistory]=useState<InventoryImport[]>([]),[selected,setSelected]=useState<InventoryImport|null>(null)
  const [busy,setBusy]=useState(false),[error,setError]=useState(''),[message,setMessage]=useState('')
  const canImport=['owner','inventory'].includes(role)
  async function refresh(){setHistory((await localApi.inventoryImports()).imports)}
  useEffect(()=>{void refresh().catch(()=>setError('Import history could not be loaded.'))},[])
  async function preview(event:FormEvent<HTMLFormElement>){
    event.preventDefault();const data=new FormData(event.currentTarget),file=data.get('file') as File
    setBusy(true);setError('');setMessage('');setSelected(null)
    try{const rows=await readInventoryFile(file);const result=await localApi.previewImport(String(data.get('reference')),String(data.get('mode')),rows);setSelected(result.import);await refresh()}
    catch(err){setError(err instanceof Error?err.message:'Preview failed.')}finally{setBusy(false)}
  }
  async function apply(){
    if(!selected)return;setBusy(true);setError('')
    try{await localApi.applyImport(selected.id,selected.preview_version);setSelected({...selected,status:'applied'});setMessage('Import applied once. Stock remains quarantined pending pharmacist release and independent reconciliation.');await refresh();await onApplied()}
    catch(err){setError(err instanceof Error?err.message:'Apply failed.')}finally{setBusy(false)}
  }
  async function reconcile(event:FormEvent<HTMLFormElement>){
    event.preventDefault();if(!selected)return;const form=new FormData(event.currentTarget);setBusy(true);setError('')
    try{await localApi.reconcileImport(selected.id,selected.rows.map((_,i)=>Number(form.get(`count-${i}`))),String(form.get('note')));setSelected({...selected,status:'reconciled'});setMessage('Independent physical counts match the ledger. Reconciliation recorded.');await refresh()}
    catch(err){setError(err instanceof Error?err.message:'Reconciliation failed.')}finally{setBusy(false)}
  }
  return <section className="local-panel local-import"><h2><FileArrowUp/> Controlled stock import</h2><p>Template v1 · existing SKUs · prices in paise · quantities in the product’s wholesale unit. All rows apply together; new stock stays quarantined.</p>
    {error&&<p role="alert" className="error-box">{error}</p>}{message&&<p role="status"><CheckCircle/> {message}</p>}
    {canImport&&<form className="local-form" onSubmit={preview}><a href={`${import.meta.env.BASE_URL}batch-import-v1.csv`} download><DownloadSimple/> Download CSV template (opens in Excel)</a><label>Source / GRN reference<input name="reference" minLength={3} maxLength={120} required disabled={busy}/></label><label>Import purpose<select name="mode" disabled={busy}><option value="receipt">Add received quantities</option><option value="opening">Opening stock — new batches only</option></select></label><label>CSV or XLSX · max 1 MB / 500 rows<input type="file" name="file" accept=".csv,.xlsx" required disabled={busy}/></label><button className="local-primary" disabled={busy}>Validate and preview</button></form>}
    {selected&&<div><h3>{selected.source_reference} · {selected.status}</h3><p>Checksum of validated content: <code className="local-checksum">{selected.checksum}</code></p><div className="local-import-table"><table><thead><tr><th>SKU / batch</th><th>Expiry</th><th>On hand → after</th><th>Reserved</th><th>Price → new (paise)</th></tr></thead><tbody>{selected.rows.map(row=><tr key={`${row.sku}/${row.batch_number}/${row.expiry_date}`}><td>{row.sku} / {row.batch_number}<small> {row.wholesale_unit}</small></td><td>{row.expiry_date}</td><td>{row.before.batch?.on_hand||0} → {(row.before.batch?.on_hand||0)+row.quantity}</td><td>{row.before.batch?.reserved||0}</td><td>{row.before.price_paise} → {row.price_paise}</td></tr>)}</tbody></table></div><p>These are the balances at preview time. If stock or prices change, apply is blocked; upload the same file and reference again to refresh the preview.</p>
      {canImport&&selected.status==='preview'&&<button className="local-primary" disabled={busy} onClick={()=>void apply()}>Confirm all {selected.rows.length} rows</button>}
      {role==='owner'&&selected.status==='applied'&&<form className="local-form" onSubmit={reconcile}><h3>Independent physical count</h3><p>An owner other than the person who applied the import must count each batch. Differences must be investigated before sign-off.</p>{selected.rows.map((row,i)=><label key={i}>{row.sku} / {row.batch_number} / {row.expiry_date}<input name={`count-${i}`} type="number" min="0" max="999999" step="1" required disabled={busy}/></label>)}<label>Reconciliation evidence / note<textarea name="note" minLength={10} maxLength={500} required disabled={busy}/></label><button className="local-primary" disabled={busy}>Record matching counts</button></form>}
    </div>}
    <h3>Recent imports</h3>{!history.length&&<p>No imports recorded.</p>}<ul>{history.map(item=><li key={item.id}><button className="local-link" disabled={busy} onClick={()=>{setSelected(item);setError('');setMessage('')}}>{item.source_reference} · {item.status} · {item.rows.length} rows · {new Date(item.created_at).toLocaleString('en-IN')}</button></li>)}</ul>
  </section>
}
