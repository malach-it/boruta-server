import Vue from 'vue'
import Vuex from 'vuex'
import { Socket } from 'phoenix'

import oauth from './services/oauth.service'
import User from './models/user.model'

Vue.use(Vuex)

export default new Vuex.Store({
  state: {
    isAuthenticated: false,
    currentUser: User.default,
    socket: null
  },
  getters: {
    isAuthenticated (state) {
      return state.isAuthenticated
    },
    currentUser (state) {
      return state.currentUser
    },
    socket (state) {
      return state.socket
    }
  },
  mutations: {
    SET_AUTHENTICATED (state, isAuthenticated) {
      state.isAuthenticated = isAuthenticated
    },
    SET_LOGIN_INTERVAL (state, interval) {
      clearInterval(state.loginInterval)
      state.loginInterval = interval
    },
    SET_CURRENT_USER (state, user) {
      state.currentUser = user
    },
    SET_SOCKET (state, socket) {
      state.socket = socket
    }
  },
  actions: {
    async socketConnection ({ commit, state }) {
      if (state.socket) return state.socket

      const socket = new Socket(`${window.env.VUE_APP_BORUTA_BASE_SOCKET_URL}/socket`, { params: { token: oauth.accessToken } })
      commit('SET_SOCKET', socket)
      await socket.connect()

      return socket
    },
    async getCurrentUser ({ commit }) {
      try {
        const user = await User.current()
        commit('SET_CURRENT_USER', user)
        commit('SET_AUTHENTICATED', true)
      } catch (error) {
        commit('SET_CURRENT_USER', User.default)
        commit('SET_AUTHENTICATED', false)
      }
    },
    logout ({ commit }) {
      oauth.logout()
      commit('SET_CURRENT_USER', User.default)
      commit('SET_AUTHENTICATED', false)
      return oauth.login()
    }
  }
})
