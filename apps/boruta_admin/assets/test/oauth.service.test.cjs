const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const test = require('node:test')
const vm = require('node:vm')
const decode = require('jwt-decode')

async function service ({ authorization, stored = {}, frameElement = null, basic = false } = {}) {
  const values = new Map(Object.entries(stored))
  const localStorage = {
    getItem: key => values.get(key) ?? null,
    setItem: (key, value) => values.set(key, String(value)),
    removeItem: key => values.delete(key)
  }
  const window = {
    env: { BORUTA_ADMIN_BASIC_AUTH: basic }, frameElement, borutaRequestAuthorization: authorization,
    dispatchEvent () {}
  }
  class BorutaOauth {
    constructor () {
      this.Revoke = class { revoke () { return Promise.resolve() } }
    }
  }
  const context = vm.createContext({
    window, localStorage, Event: class {}, setTimeout: callback => callback()
  })
  const module = new vm.SourceTextModule(fs.readFileSync(
    path.join(__dirname, '../src/services/oauth.service.js'), 'utf8'
  ), { context })
  await module.link(name => {
    const exports = name === 'jwt-decode' ? { default: decode } : { BorutaOauth }
    return new vm.SyntheticModule(Object.keys(exports), function () {
      for (const [key, value] of Object.entries(exports)) this.setExport(key, value)
    }, { context })
  })
  await module.evaluate()
  return { oauth: module.namespace.default, localStorage, window }
}

test('preserves the normal stored OAuth session without a request bearer', async () => {
  const { oauth } = await service({ stored: {
    access_token: 'stored', token_expires_at: String(Date.now() + 60000),
    authorized_scope: 'logs:read:all'
  } })
  assert.equal(oauth.accessToken, 'stored')
  assert.equal(oauth.isAuthenticated, true)
  assert.equal(oauth.authorizedScope, 'logs:read:all')
})

test('request headers no longer bootstrap or replace an OAuth session', async () => {
  const { oauth } = await service({
    authorization: { access_token: 'request', scope: 'users:manage:all' },
    stored: { access_token: 'stored', token_expires_at: String(Date.now() + 60000) }
  })
  assert.equal(oauth.accessToken, 'stored')
  assert.equal(oauth.isAuthenticated, true)
})

test('normal OAuth callback stores credentials and logout clears them', async () => {
  const { oauth, localStorage } = await service()
  oauth.authenticate({ access_token: 'callback', expires_in: 3600, scope: 'logs:read:all' })
  assert.equal(oauth.accessToken, 'callback')
  assert.equal(oauth.authorizedScope, 'logs:read:all')
  assert.equal(oauth.isAuthenticated, true)
  await oauth.logout()
  assert.equal(localStorage.getItem('access_token'), null)
  assert.equal(oauth.isAuthenticated, false)
})

for (const stored of [{}, { access_token: 'expired', token_expires_at: '1' }]) {
  test('Basic authentication avoids OAuth login and refresh without a valid stored token', async () => {
    const { oauth, window } = await service({ basic: true, stored })
    assert.equal(oauth.isAuthenticated, true)
    assert.equal(oauth.login(), undefined)
    assert.equal(oauth.silentRefresh(), undefined)
    assert.equal(window.location, undefined)
    assert.equal(oauth.accessToken, stored.access_token || null)
  })
}

test('without Basic authentication a missing token remains unauthenticated', async () => {
  const { oauth } = await service()
  assert.equal(oauth.isAuthenticated, false)
})
