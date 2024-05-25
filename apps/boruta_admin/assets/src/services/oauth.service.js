import decode from 'jwt-decode'
import { BorutaOauth } from 'boruta-client'

class Oauth {
  constructor () {
    const oauth = new BorutaOauth({
      window,
      host: window.env.BORUTA_ADMIN_OAUTH_BASE_URL,
      authorizePath: '/oauth/authorize',
      revokePath: '/oauth/revoke'
    })

    this.implicitClient = new oauth.Implicit({
      clientId: window.env.BORUTA_ADMIN_OAUTH_CLIENT_ID,
      redirectUri: `${window.env.BORUTA_ADMIN_BASE_URL}/oauth-callback`,
      scope: 'openid email profile scopes:manage:all clients:manage:all users:manage:all upstreams:manage:all identity-providers:manage:all configuration:manage:all logs:read:all',
      silentRefresh: true,
      silentRefreshCallback: this.authenticate.bind(this),
      responseType: 'id_token token'
    })

    this.revokeClient = new oauth.Revoke({
      clientId: window.env.BORUTA_ADMIN_OAUTH_CLIENT_ID
    })
  }

  get idToken() {
    return localStorage.getItem('id_token')
  }

  get currentUser() {
    try {
      const { email } = decode(this.idToken)
      return { email }
    } catch {
      return {}
    }
  }

  authenticate (response) {
    if (window.frameElement) return

    if (response.error) {
      this.login()
    }

    const { access_token, id_token, expires_in } = response
    const expires_at = new Date().getTime() + expires_in * 1000

    localStorage.setItem('access_token', access_token)
    localStorage.setItem('id_token', id_token)
    localStorage.setItem('token_expires_at', expires_at)

    setTimeout(() => {
      const loggedIn = new Event('logged_in')
      window.dispatchEvent(loggedIn)
    }, 100)
  }

  login () {
    window.location = this.implicitClient.loginUrl
  }

  silentRefresh () {
    this.implicitClient.silentRefresh()
  }

  async callback () {
    return this.implicitClient.callback().then(response => {
      this.authenticate(response)
    }).catch((error) => {
      this.login()
      throw error
    })
  }

  logout () {
    return this.revokeClient.revoke(this.accessToken).then(() => {
      localStorage.removeItem('access_token')
      localStorage.removeItem('token_expires_at')
    })
  }

  storeLocationName ({ name, params, query }) {
    localStorage.setItem('stored_location_name', name)
    localStorage.setItem('stored_location_params', JSON.stringify(params))
    localStorage.setItem('stored_location_query', JSON.stringify(query))
  }

  get storedLocation () {
    const name = localStorage.getItem('stored_location_name') || 'home'
    const params = JSON.parse(localStorage.getItem('stored_location_params') || '{}')
    const query = JSON.parse(localStorage.getItem('stored_location_query') || '{}')
    return { name, params, query }
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
