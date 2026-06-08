import { createStore } from 'vuex'
import { CredentialsStore, BrowserStorage, BrowserEventHandler } from 'boruta-client'

const CREDENTIALS_KEY = 'boruta-client_credentials'

export const storage = new BrowserStorage(window)
const eventHandler = new BrowserEventHandler(window)
const credentialsStore = new CredentialsStore(eventHandler, storage)

const store = createStore({
  state: {
    credentials: []
  },
  getters: {
    credentials ({ credentials }) {
      return credentials
    }
  },
  mutations: {
    async refreshCredentials(state) {
      state.credentials = await credentialsStore.credentials()
    },
    deleteCredential(state, credential) {
      credentialsStore.deleteCredential(credential.credential).then(credentials => {
        state.credentials = credentials
      })
    },
    async importCredentials(state, importedCredentials) {
      const currentCredentials = await storage.get(CREDENTIALS_KEY) || []
      const credentials = importedCredentials.reduce((credentials, credential) => {
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

store.commit('refreshCredentials')

export default store
