import OauthClient from 'client-oauth2'

class Oauth {
  constructor () {
    this.client = new OauthClient({
      clientId: process.env.VUE_APP_ADMIN_CLIENT_ID,
      authorizationUri: `${process.env.VUE_APP_BORUTA_BASE_URL}/oauth/authorize`,
      redirectUri: `${process.env.VUE_APP_BORUTA_BASE_URL}/admin/oauth-callback`,
      scopes: ['scopes:manage:all', 'clients:manage:all', 'users:manage:all', 'upstreams:manage:all']
    })
  }

  login () {
    window.location = this.client.token.getUri()
  }

  async callback () {
    const token = await this.client.token.getToken(window.location).catch(() => {
      this.login()
    })
    localStorage.setItem('access_token', token.accessToken)
    localStorage.setItem('token_expires_at', token.expires.getTime())
  }

  logout () {
    localStorage.removeItem('access_token')
    localStorage.removeItem('token_expires_at')
    return Promise.resolve(true)
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
