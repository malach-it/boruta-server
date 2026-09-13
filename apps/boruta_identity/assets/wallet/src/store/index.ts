import { createStore } from 'vuex'
import { CredentialsStore, BrowserStorage, BrowserEventHandler } from 'boruta-client'
import { CompactEncrypt } from 'jose'

const CREDENTIALS_KEY = 'boruta-client_credentials'
const textEncoder = new TextEncoder()

export const storage = new BrowserStorage(window)
const eventHandler = new BrowserEventHandler(window)
const credentialsStore = new CredentialsStore(eventHandler, storage)

const store = createStore({
  state: {
    credentials: [],
    credentialsError: null
  },
  getters: {
    credentials ({ credentials }) {
      return credentials
    },
    credentialsError ({ credentialsError }) {
      return credentialsError
    }
  },
  mutations: {
    async refreshCredentials(state, password) {
      try {
        state.credentialsError = null
        state.credentials = await credentialsStore.credentials(password)
      } catch (_error) {
        state.credentials = []
        state.credentialsError = 'Unable to unlock credentials.'
      }
    },
    deleteCredential(state, credential) {
      credentialsStore.deleteCredential(credential.credential).then(credentials => {
        state.credentials = credentials
      })
    },
    async importCredentials(state, importedCredentials) {
      try {
        state.credentialsError = null
        const password = await requestCredentialsPassword()
        const currentCredentials = await credentialsStore.credentials(password)
        const credentials = importedCredentials.reduce((credentials, credential) => {
          if (credentials.some(({ credential: currentCredential }) => currentCredential == credential.credential)) {
            return credentials
          }

          return credentials.concat([credential])
        }, currentCredentials)
        const encryptedCredentials = await Promise.all(
          credentials.map(credential => encryptCredential(credential, password))
        )

        await storage.store(CREDENTIALS_KEY, encryptedCredentials)
        state.credentials = await credentialsStore.credentials(password)
      } catch (_error) {
        state.credentialsError = 'Unable to import credentials.'
      }
    }
  },
  actions: {
  },
  modules: {
  }
})

async function requestCredentialsPassword(): Promise<string> {
  return new Promise((resolve, reject) => {
    const handleApproval = (event) => {
      const password = event.detail

      if (typeof password == 'string' && password) {
        resolve(password)
      } else {
        reject(new Error('Credentials password is required.'))
      }
    }

    window.addEventListener(
      'access_credential-approval~' + CREDENTIALS_KEY,
      handleApproval,
      { once: true }
    )
    window.dispatchEvent(new CustomEvent('access_credential-request~' + CREDENTIALS_KEY))
  })
}

async function encryptCredential (credential, password): Promise<{ jwe: string }> {
  const payload = JSON.stringify({
    credentialId: credential.credentialId,
    format: credential.format,
    credential: credential.credential
  })
  const jwe = await new CompactEncrypt(textEncoder.encode(payload))
    .setProtectedHeader({
      alg: 'PBES2-HS256+A128KW',
      enc: 'A256GCM'
    })
    .encrypt(textEncoder.encode(password))

  return { jwe }
}

export default store
