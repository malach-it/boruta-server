import { createApp } from 'vue'
import { exportJWK, generateKeyPair } from 'jose'
import AsyncComputed from 'vue-async-computed'
import App from './App.vue'
import './registerServiceWorker'
import router from './router'
import store from './store'

generateKeyPair("ECDH-ES", { extractable: true }).then(async ({ publicKey, privateKey }) => {
  localStorage.setItem("encryptionKeyPair", JSON.stringify({
    publicKey: await exportJWK(publicKey),
    privateKey: await exportJWK(privateKey),
  }))
})

createApp(App)
  .use(store)
  .use(router)
  .use(AsyncComputed)
  .mount('#app')
