import decode from 'jwt-decode'
import { BorutaOauth } from 'boruta-client'

const ADMIN_SCOPES = 'scopes:manage:all clients:manage:all users:manage:all upstreams:manage:all identity-providers:manage:all configuration:manage:all logs:read:all tokens:read:all'.split(' ')

class Oauth {
  constructor () {
    this.oauth = new BorutaOauth({
      window,
      host: window.env.BORUTA_ADMIN_OAUTH_BASE_URL,
      authorizePath: '/oauth/authorize',
      revokePath: '/oauth/revoke'
    })

    this.requestedScope = (localStorage.getItem('requested_scope') ?? ADMIN_SCOPES.join(' '))
      .split(/\s+/)
      .filter((scope) => ADMIN_SCOPES.includes(scope))
      .join(' ')
    this.authorizedScope = localStorage.getItem('authorized_scope')

    this.revokeClient = new this.oauth.Revoke({
      clientId: window.env.BORUTA_ADMIN_OAUTH_CLIENT_ID
    })
    this.logoutPromise = null
  }

  get implicitClient () {
    return new this.oauth.Implicit({
      clientId: window.env.BORUTA_ADMIN_OAUTH_CLIENT_ID,
      redirectUri: `${window.env.BORUTA_ADMIN_BASE_URL}/oauth-callback`,
      scope: ['openid', 'email', 'profile', this.requestedScope].filter(Boolean).join(' '),
      silentRefresh: true,
      silentRefreshCallback: this.authenticate.bind(this),
      responseType: 'id_token token'
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

  get adminScopes () {
    return ADMIN_SCOPES.map((name) => ({
      name,
      label: this.scopeLabel(name)
    }))
  }

  get authorizedScopes () {
    return (this.authorizedScope || '').split(/\s+/).filter(Boolean)
  }

  authorizedScopeFrom ({ id_token, scope }, fallbackScope = this.requestedScope) {
    let authorizedScope = scope

    if (!authorizedScope) {
      try {
        authorizedScope = decode(id_token).scope
      } catch {
        authorizedScope = null
      }
    }

    return Array.isArray(authorizedScope)
      ? authorizedScope.join(' ')
      : (authorizedScope || fallbackScope)
  }

  setRequestedScope (scopes) {
    this.requestedScope = scopes.join(' ')

    localStorage.setItem('requested_scope', this.requestedScope)
  }

  scopeLabel (scope) {
    const labels = {}

    if (labels[scope]) return labels[scope]

    const [resource, action, target] = scope.split(':')
    return [action, target, resource]
      .filter(Boolean)
      .map((part) => part.replaceAll('-', ' '))
      .join(' ')
      .replace(/^\w/, (letter) => letter.toUpperCase())
  }

  authenticate (response) {
    if (window.frameElement) return

    if (response.error) {
      return this.login()
    }

    this.storeAuthentication(response)
  }

  storeAuthentication (response, fallbackScope = this.requestedScope) {
    const { access_token, id_token, expires_in } = response
    const authorizedScope = this.authorizedScopeFrom(response, fallbackScope)

    this.authorizedScope = authorizedScope

    localStorage.setItem('authorized_scope', authorizedScope)
    localStorage.setItem('access_token', access_token)
    if (id_token) localStorage.setItem('id_token', id_token)
    else localStorage.removeItem('id_token')
    if (Number.isFinite(Number(expires_in))) {
      localStorage.setItem('token_expires_at', Date.now() + Number(expires_in) * 1000)
    } else {
      localStorage.removeItem('token_expires_at')
    }

    setTimeout(() => {
      const loggedIn = new Event('logged_in')
      window.dispatchEvent(loggedIn)
    }, 500)
  }

  login () {
    if (this.basicAuthentication) return

    const loginNavigation = () => {
        localStorage.setItem('requested_scope', this.requestedScope)

        window.location = this.implicitClient.loginUrl
    }

    if (this.accessToken) {
      return this.logout().then(() => {
        loginNavigation()
      })
    }

    return loginNavigation()
  }

  silentRefresh () {
    if (this.basicAuthentication) return

    this.implicitClient.silentRefresh()
  }

  async callback () {
    return this.implicitClient.callback().then(response => {
      this.authenticate(response)
    }).catch((error) => {
      console.log(error)
      this.login()
      throw error
    })
  }

  logout () {
    if (this.logoutPromise) return this.logoutPromise

    const accessToken = this.accessToken
    if (!accessToken) return Promise.resolve()

    this.logoutPromise = this.revokeClient.revoke(accessToken)
      .then(() => {
        localStorage.removeItem('access_token')
        localStorage.removeItem('id_token')
        localStorage.removeItem('token_expires_at')
        localStorage.removeItem('authorized_scope')
        this.authorizedScope = null
      })
      .finally(() => {
        this.logoutPromise = null
      })

    return this.logoutPromise
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

  get basicAuthentication () {
    return window.env.BORUTA_ADMIN_BASIC_AUTH === true
  }

  get isAuthenticated () {
    if (this.basicAuthentication) return true

    const accessToken = this.accessToken
    const expiresAt = localStorage.getItem('token_expires_at')
    return Boolean(accessToken && parseInt(expiresAt) > Date.now())
  }

  get expiresIn () {
    const expiresAt = localStorage.getItem('token_expires_at')
    return parseInt(expiresAt) - new Date().getTime()
  }
}

export default new Oauth()
