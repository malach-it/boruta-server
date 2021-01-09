import OauthClient from 'client-oauth2'

class Oauth {
  get client () {
    return new OauthClient({
      clientId: process.env.VUE_APP_ADMIN_CLIENT_ID,
      authorizationUri: `${process.env.VUE_APP_BORUTA_BASE_URL}/oauth/authorize`,
      redirectUri: `${process.env.VUE_APP_BORUTA_BASE_URL}/admin/oauth-callback`,
      accessTokenUri: `${process.env.VUE_APP_BORUTA_BASE_URL}/oauth/token`,
      scopes: ['scopes:manage:all', 'clients:manage:all', 'users:manage:all', 'upstreams:manage:all']
    })
  }

  get codeChallenge () {
    let codeChallenge = localStorage.getItem('codeChallenge')
    if (codeChallenge) return codeChallenge

    codeChallenge = Math.random().toString(36).substring(8)
    localStorage.setItem('codeChallenge', codeChallenge)
    return codeChallenge
  }

  login () {
    window.location = this.client.code.getUri({
      query: {
        code_challenge: this.codeChallenge,
        code_challenge_method: 'plain'
      }
    })
  }

  async callback () {
    return this.client.code.getToken(window.location.href, {
      clientSecret: '777',
      body: {
        code_verifier: this.codeChallenge
      }
    }).then(user => {
      localStorage.setItem('access_token', user.accessToken)
      localStorage.setItem('token_expires_at', user.expires.getTime())
    })
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
