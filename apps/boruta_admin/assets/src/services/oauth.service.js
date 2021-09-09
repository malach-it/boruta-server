import OauthClient from 'client-oauth2'

class Oauth {
  constructor () {
    this.client = new OauthClient({
      clientId: window.env.VUE_APP_ADMIN_CLIENT_ID,
      authorizationUri: `${window.env.VUE_APP_OAUTH_BASE_URL}/oauth/authorize`,
      // TODO have a separate host for admin
      redirectUri: `${window.env.VUE_APP_BORUTA_BASE_URL}/oauth-callback`,
      scopes: ['scopes:manage:all', 'clients:manage:all', 'users:manage:all', 'upstreams:manage:all']
    })
  }

  login () {
    window.location = this.client.token.getUri({ query: { prompt: 'login' } })
  }

  async callback () {
    const token = await this.client.token.getToken(window.location).catch((error) => {
      confirm(error.message)
      this.login()
      throw error
    })
    localStorage.setItem('access_token', token.accessToken)
    localStorage.setItem('token_expires_at', token.expires.getTime())
  }

  logout () {
    localStorage.removeItem('access_token')
    localStorage.removeItem('token_expires_at')
    return Promise.resolve(true)
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
