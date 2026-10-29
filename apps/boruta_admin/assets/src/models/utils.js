import axios from 'axios'
import router from '../router'
import oauth from '../services/oauth.service'

export function browserCredentialConfig(config) {
  config.withCredentials = true
  if (window.env.BORUTA_ADMIN_BASIC_AUTH && config.headers) {
    if (typeof config.headers.delete === 'function') {
      config.headers.delete('Authorization')
    } else {
      for (const name of Object.keys(config.headers)) {
        if (name.toLowerCase() === 'authorization') delete config.headers[name]
      }
    }
  }
  return config
}

export function addClientErrorInterceptor(instance) {
  browserCredentialConfig(instance.defaults)
  instance.interceptors.request.use(browserCredentialConfig)

  instance.interceptors.response.use(function (response) {
      return response;
    }, function (error) {
      if (error.response?.status === 401 && !oauth.basicAuthentication) {
        return new Promise((resolve, reject) => {
          let refreshTimeout

          function retry() {
            clearTimeout(refreshTimeout)
            window.removeEventListener('logged_in', retry)
            const accessToken = localStorage.getItem('access_token')

            const newRequest = Object.assign(error.config, {
              withCredentials: true,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${accessToken}`
              }
            })
            axios.request(browserCredentialConfig(newRequest)).then(resolve).catch(reject)
          }

          window.addEventListener('logged_in', retry)
          refreshTimeout = setTimeout(() => {
            window.removeEventListener('logged_in', retry)
            oauth.logout()
            reject()
          }, 2000)
          oauth.silentRefresh()
        })
      }

      return Promise.reject(error)
    }
  )

  return instance
}
