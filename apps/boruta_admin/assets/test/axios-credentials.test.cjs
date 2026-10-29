const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const test = require('node:test')
const vm = require('node:vm')
const axios = require('axios')

async function client(basic) {
  const context = vm.createContext({ window: { env: { BORUTA_ADMIN_BASIC_AUTH: basic } } })
  const module = new vm.SourceTextModule(fs.readFileSync(
    path.join(__dirname, '../src/models/utils.js'), 'utf8'
  ), { context })
  await module.link(name => new vm.SyntheticModule(['default'], function () {
    this.setExport('default', name === 'axios' ? axios : { basicAuthentication: basic })
  }, { context }))
  await module.evaluate()
  return module.namespace
}

for (const basic of [true, false]) {
  test(`Axios ${basic ? 'omits' : 'retains'} bearer headers with Basic mode ${basic}`, async () => {
    const { addClientErrorInterceptor } = await client(basic)
    let sent
    const instance = addClientErrorInterceptor(axios.create({
      headers: { Authorization: 'Bearer stale', 'Content-Type': 'application/json' },
      adapter: async config => { sent = config; return { data: {}, status: 200, headers: {}, config } }
    }))
    await instance.get('/api/users', { headers: { authorization: 'Bearer override' } })
    assert.equal(sent.withCredentials, true)
    assert.equal(sent.headers.get('Authorization'), basic ? undefined : 'Bearer override')
    assert.equal(sent.headers.get('Content-Type'), 'application/json')
  })
}

test('retry configuration removes case-insensitive bearer headers in Basic mode', async () => {
  const { browserCredentialConfig } = await client(true)
  const config = browserCredentialConfig({ headers: { authorization: 'Bearer retry', Accept: 'application/json' } })
  assert.equal(config.headers.authorization, undefined)
  assert.equal(config.headers.Accept, 'application/json')
  assert.equal(config.withCredentials, true)
})

test('Basic-auth API 401 is returned without triggering OAuth refresh', async () => {
  const { addClientErrorInterceptor } = await client(true)
  const error = { response: { status: 401 } }
  const instance = addClientErrorInterceptor(axios.create({
    adapter: async () => { throw error }
  }))
  await assert.rejects(instance.get('/api/users'), caught => caught === error)
})
