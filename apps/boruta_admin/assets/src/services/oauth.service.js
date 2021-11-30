import { BorutaOauth } from 'boruta-client'
import store from '../store'

class Oauth {
  constructor () {
    const oauth = new BorutaOauth({
      window: window,
      host: window.env.VUE_APP_OAUTH_BASE_URL,
      authorizePath: '/oauth/authorize'
    })

    this.client = new oauth.Implicit({
      clientId: window.env.VUE_APP_ADMIN_CLIENT_ID,
      redirectUri: `${window.env.VUE_APP_BORUTA_BASE_URL}/oauth-callback`,
      scope: 'scopes:manage:all clients:manage:all users:manage:all upstreams:manage:all relying-parties:manage:all',
      silentRefresh: true,
      silentRefreshCallback: this.authenticate.bind(this)
    })
  }

  authenticate (response) {
    if (response.error) {
      alert(response.error_description)
      this.login()
    }

    if (window.frameElement) return

    const loggedIn = new Event('logged_in')
    window.dispatchEvent(loggedIn)

    const { access_token, expires_in } = response
    const expires_at = new Date().getTime() + expires_in * 1000

    localStorage.setItem('access_token', access_token)
    localStorage.setItem('token_expires_at', expires_at)
    store.dispatch('getCurrentUser')
  }

  login () {
    window.location = this.client.loginUrl
  }

  silentRefresh () {
    this.client.silentRefresh()
  }

  async callback () {
    return this.client.callback().then(response => {
      this.authenticate(response)
    })
  }

  logout () {
    localStorage.removeItem('access_token')
    localStorage.removeItem('token_expires_at')
    return Promise.resolve(true)
  }

  storeLocationName (name, params) {
    localStorage.setItem('stored_location_name', name)
    localStorage.setItem('stored_location_params', JSON.stringify(params))
  }

  get storedLocation () {
    const name = localStorage.getItem('stored_location_name') || 'home'
    const params = JSON.parse(localStorage.getItem('stored_location_params') || {})
    return { name, params }
  }

  get accessToken () {
    return localStorage.getItem('access_token')
  }

  get isAuthenticated () {
    const accessToken = localStorage.getItem('access_token')
    const expiresAt = localStorage.getItem('token_expires_at')
    return accessToken && parseInt(expiresAt) > new Date().getTime()
  }

  get expiresIn () {
    const expiresAt = localStorage.getItem('token_expires_at')
    return parseInt(expiresAt) - new Date().getTime()
  }
}

export default new Oauth()
