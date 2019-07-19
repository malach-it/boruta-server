const OauthClient = require('client-oauth2')

class Oauth {
  constructor () {
    this.client = new OauthClient({
      clientId: process.env.VUE_APP_ADMIN_CLIENT_ID,
      authorizationUri: `${process.env.VUE_APP_BORUTA_BASE_URL}/oauth/authorize`,
      redirectUri: `${process.env.VUE_APP_BORUTA_BASE_URL}/admin/oauth-callback`,
      scopes: ['scopes:manage:all', 'clients:manage:all']
    })
  }

  login () {
    window.location = this.client.token.getUri()
  }

  async callback () {
    const token = await this.client.token.getToken(window.location)
    localStorage.setItem('access_token', token.accessToken)
  }
}

export default new Oauth()
