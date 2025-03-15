import { createStore } from 'vuex'
import { CredentialsStore, BrowserStorage, BrowserEventHandler } from 'boruta-client'

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
    }
  },
  actions: {
  },
  modules: {
  }
})

store.commit('refreshCredentials')

export default store
