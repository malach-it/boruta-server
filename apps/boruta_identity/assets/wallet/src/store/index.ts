import { createStore } from 'vuex'
import { CredentialsStore, BrowserStorage, BrowserEventHandler } from 'boruta-client'

const CREDENTIALS_KEY = 'boruta-client_credentials'

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
      const currentCredentials = await storage.get(CREDENTIALS_KEY) || []
      const credentials = importedCredentials.reduce((credentials, credential) => {
        if (credential.jwe) {
          if (credentials.some(({ jwe }) => jwe == credential.jwe)) {
            return credentials
          }

          return credentials.concat([{ jwe: credential.jwe }])
        }

        if (credentials.some(({ credential: currentCredential }) => currentCredential == credential.credential)) {
          return credentials
        }

        return credentials.concat([{
          credentialId: credential.credentialId,
          format: credential.format,
          credential: credential.credential
        }])
      }, currentCredentials)

      await storage.store(CREDENTIALS_KEY, credentials)
      state.credentials = await credentialsStore.credentials()
    }
  },
  actions: {
  },
  modules: {
  }
})

export default store
