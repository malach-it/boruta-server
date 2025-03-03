import { createStore } from 'vuex'
import { CredentialsStore } from 'boruta-client'

const credentialsStore = new CredentialsStore(window)

export default createStore({
  state: {
    credentials: credentialsStore.credentials
  },
  getters: {
    credentials ({ credentials }) {
      return credentials
    }
  },
  mutations: {
    addCredential(state, credential) {
      state.credentials = credentialsStore.credentials
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
