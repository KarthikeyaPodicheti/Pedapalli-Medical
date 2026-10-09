// Legacy consumer checkout is intentionally disabled.
// B2B orders use the authenticated create_b2b_order database function, which
// enforces buyer approval, current prices, MOQ/steps, stock locks and idempotency.
Deno.serve(() => new Response(JSON.stringify({error:'Legacy checkout is disabled. Use the authenticated buyer portal.'}),{
  status:410,
  headers:{'Content-Type':'application/json','Cache-Control':'no-store'},
}))
