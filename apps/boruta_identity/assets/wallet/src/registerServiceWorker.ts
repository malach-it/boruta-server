/* eslint-disable no-console */

import { register } from 'register-service-worker'

let refreshing = false

function notifyUpdateAvailable (registration: ServiceWorkerRegistration) {
  window.dispatchEvent(new CustomEvent('boruta-wallet:service-worker-updated', {
    detail: { registration }
  }))
}

if ('serviceWorker' in navigator) {
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (refreshing) return

    refreshing = true
    window.location.reload()
  })
}

register(`${window.env.BORUTA_OAUTH_BASE_URL}/accounts/wallet/sw.js`, {
  ready () {
    console.log(
      'App is being served from cache by a service worker.\n' +
        'For more details, visit https://goo.gl/AFskqB'
    )
  },
  registered () {
    console.log('Service worker has been registered.')
  },
  cached () {
    console.log('Content has been cached for offline use.')
  },
  updatefound () {
    console.log('New content is downloading.')
  },
  updated (registration) {
    console.log('New content is available; please refresh.')
    notifyUpdateAvailable(registration)
  },
  offline () {
    console.log('No internet connection found. App is running in offline mode.')
  },
  error (error) {
    console.error('Error during service worker registration:', error)
  }
})
