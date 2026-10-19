import { defineConfig } from '@playwright/test'
const localPortal=process.env.LOCAL_PORTAL==='1'
export default defineConfig({
  testDir:'./e2e', fullyParallel:false, timeout:30000,
  testMatch:localPortal?'local-portal.spec.ts':'store.spec.ts',
  use:{baseURL:localPortal?'http://localhost:8080':'http://127.0.0.1:5173',headless:true},
  webServer:localPortal?undefined:{command:'npm run dev -- --port 5173',url:'http://127.0.0.1:5173',reuseExistingServer:!process.env.CI},
  projects:localPortal?[{name:'local-desktop',use:{viewport:{width:1440,height:1000}}},{name:'local-mobile',use:{viewport:{width:390,height:844}}}]:[{name:'desktop',use:{viewport:{width:1440,height:1000}}},{name:'mobile',use:{viewport:{width:390,height:844}}}]
})
