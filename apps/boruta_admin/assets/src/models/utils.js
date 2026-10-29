import axios from 'axios'
import router from '../router'
import oauth from '../services/oauth.service'

export function addClientErrorInterceptor(instance) {
  instance.interceptors.response.use(function (response) {
      return response;
    }, function (error) {
      if (error.response?.status === 401) {
        return new Promise((resolve, reject) => {
          let refreshTimeout

          function retry() {
            clearTimeout(refreshTimeout)
            window.removeEventListener('logged_in', retry)
            const accessToken = localStorage.getItem('access_token')

            const newRequest = Object.assign(error.config, {
              headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${accessToken}`
              }
            })
            axios.request(newRequest).then(resolve).catch(reject)
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
