import { createStore } from 'vuex'

import oauth from './services/oauth.service'

export default createStore({
  state: {
    isAuthenticated: false,
    socket: null
  },
  getters: {
    isAuthenticated (state) {
      return state.isAuthenticated
    }
  },
  mutations: {
    SET_AUTHENTICATED (state, isAuthenticated) {
      state.isAuthenticated = isAuthenticated
    },
    SET_SOCKET (state, socket) {
      state.socket = socket
    }
  },
  actions: {
    logout ({ commit }) {
      oauth.logout().then(() => {
        commit('SET_AUTHENTICATED', false)
        return oauth.login()
      })
    }
  }
})
