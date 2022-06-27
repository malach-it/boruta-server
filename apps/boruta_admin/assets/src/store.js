import { createStore } from 'vuex'
import { Socket } from 'phoenix'

import oauth from './services/oauth.service'

export default createStore({
  state: {
    isAuthenticated: false,
    socket: null
  },
  getters: {
    isAuthenticated (state) {
      return state.isAuthenticated
    },
    socket (state) {
      return state.socket
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
    async socketConnection ({ commit, state }) {
      if (state.socket) return state.socket

      const socket = new Socket(`${window.env.BORUTA_ADMIN_BASE_SOCKET_URL}/socket`, { params: { token: oauth.accessToken } })
      commit('SET_SOCKET', socket)
      await socket.connect()

      return socket
    },
    logout ({ commit }) {
      oauth.logout().then(() => {
        commit('SET_AUTHENTICATED', false)
        return oauth.login()
      })
    }
  }
})
