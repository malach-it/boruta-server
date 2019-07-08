import Vue from 'vue'
import App from './App.vue'
import router from './router'
import store from './store'

import VueAxios from 'vue-axios'
import VueAuthenticate from 'vue-authenticate'
import axios from 'axios'

Vue.use(VueAxios, axios)
Vue.use(VueAuthenticate, {
  baseUrl: 'http://localhost:3000', // Your API domain

  providers: {
    boruta: {
      name: 'boruta',
      authorizationEndpoint: 'http://localhost:4000/oauth/authorize',
      clientId: process.env.VUE_APP_ADMIN_CLIENT_ID,
      redirectUri: 'http://localhost:4000/admin',
      responseType: 'token',
      oauthType: '2.0'
    }
  }
})

Vue.config.productionTip = false

new Vue({
  router,
  store,
  render: h => h(App)
}).$mount('#app')
