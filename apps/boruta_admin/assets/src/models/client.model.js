import axios from 'axios'
import router from '../router'
import Scope from './scope.model'
import IdentityProvider from './identity-provider.model'
import { addClientErrorInterceptor } from './utils'

const allGrantTypes = ['client_credentials', 'password', 'authorization_code', 'refresh_token', 'implicit', 'revoke', 'introspect']

const defaults = {
  errors: null,
  authorize_scopes: false,
  authorized_scopes: [],
  redirect_uris: [],
  id_token_signature_alg: 'RS512',
  identity_provider: { model: new IdentityProvider() },
  grantTypes: allGrantTypes.map((label) => {
    return {
      value: true,
      label
    }
  })
}

const assign = {
  id: function ({ id }) { this.id = id },
  name: function ({ name }) { this.name = name },
  pkce: function ({ pkce }) { this.pkce = pkce },
  public_key: function ({ public_key }) { this.public_key = public_key },
  access_token_ttl: function ({ access_token_ttl }) { this.access_token_ttl = access_token_ttl },
  authorization_code_ttl: function ({ authorization_code_ttl }) { this.authorization_code_ttl = authorization_code_ttl },
  refresh_token_ttl: function ({ refresh_token_ttl }) { this.refresh_token_ttl = refresh_token_ttl },
  id_token_ttl: function ({ id_token_ttl }) { this.id_token_ttl = id_token_ttl },
  secret: function ({ secret }) { this.secret = secret },
  redirect_uris: function ({ redirect_uris }) {
    this.redirect_uris = redirect_uris.map((uri) => ({ uri }))
  },
  public_refresh_token: function ({ public_refresh_token }) { this.public_refresh_token = public_refresh_token },
  public_revoke: function ({ public_revoke }) { this.public_revoke = public_revoke },
  identity_provider: function ({ identity_provider }) {
    this.identity_provider = { model: new IdentityProvider(identity_provider) }
  },
  authorize_scope: function ({ authorize_scope }) { this.authorize_scope = authorize_scope },
  authorized_scopes: function ({ authorized_scopes }) {
    this.authorized_scopes = authorized_scopes.map((scope) => {
      return { model: new Scope(scope) }
    })
  },
  supported_grant_types: function ({ supported_grant_types }) {
    this.supported_grant_types = supported_grant_types
    this.grantTypes = allGrantTypes.map((label) => {
      return {
        value: this.supported_grant_types.includes(label),
        label
      }
    })
  },
  id_token_signature_alg: function ({ id_token_signature_alg }) { this.id_token_signature_alg = id_token_signature_alg },
}

class Client {
  constructor (params = {}) {
    Object.assign(this, defaults)

    Object.keys(params).forEach((key) => {
      this[key] = params[key]
      assign[key].bind(this)(params)
    })
  }

  // TODO factorize with User#validate
  validate () {
    return new Promise((resolve, reject) => {
      this.authorized_scopes.forEach(({ model: scope }) => {
        if (!scope.persisted) {
          const errors = { authorized_scopes: [ 'cannot be empty' ] }
          this.errors = errors
          return reject(errors)
        }
        if (this.authorized_scopes.filter(({ model: e }) => e.id === scope.id).length > 1) {
          const errors = { authorized_scopes: [ 'must be unique' ] }
          this.errors = errors
          return reject(errors)
        }
      })
      resolve()
    })
  }

  async save () {
    this.errors = null

    await this.validate()

    // TODO trigger validate
    let response
    const { id, isPersisted, serialized } = this
    if (isPersisted) {
      response = this.constructor.api().patch(`/${id}`, { client: serialized })
    } else {
      response = this.constructor.api().post('/', { client: serialized })
    }

    return response
      .then(({ data }) => {
        const params = data.data

        Object.keys(params).forEach((key) => {
          this[key] = params[key]
          assign[key].bind(this)(params)
        })
        return this
      })
      .catch((error) => {
        const { errors } = error.response.data
        this.errors = errors
        throw errors
      })
  }

  destroy () {
    return this.constructor.api().delete(`/${this.id}`)
      .catch((error) => {
        const { code, message, errors } = error.response.data
        this.errors = errors
        throw { code, message, errors }
      })
  }

  get serialized () {
    const {
      access_token_ttl,
      authorization_code_ttl,
      authorize_scope,
      authorized_scopes,
      grantTypes,
      id,
      id_token_ttl,
      name,
      pkce,
      public_refresh_token,
      public_revoke,
      redirect_uris,
      refresh_token_ttl,
      identity_provider,
      secret,
      id_token_signature_alg
    } = this

    return {
      access_token_ttl,
      authorization_code_ttl,
      authorize_scope,
      authorized_scopes: authorized_scopes.map(({ model }) => model.serialized),
      id,
      id_token_ttl,
      name,
      pkce,
      public_refresh_token,
      public_revoke,
      redirect_uris: redirect_uris.map(({ uri }) => uri),
      refresh_token_ttl,
      identity_provider: identity_provider.model,
      secret,
      supported_grant_types: grantTypes
        .filter(({ value }) => value)
        .map(({ label }) => label),
      id_token_signature_alg
    }
  }
}

Client.api = function () {
  const accessToken = localStorage.getItem('access_token')

  const instance = axios.create({
    baseURL: `${window.env.VUE_APP_BORUTA_BASE_URL}/api/clients`,
    headers: { 'Authorization': `Bearer ${accessToken}` }
  })

  return addClientErrorInterceptor(instance)
}

Client.all = function () {
  return this.api().get('/').then(({ data }) => {
    return data.data
      .map((client) => new Client(client))
      .map((client) => Object.assign(client, { isPersisted: true }))
  })
}

Client.get = function (id) {
  return this.api().get(`/${id}`).then(({ data }) => {
    const client = new Client(data.data)
    client.isPersisted = true
    return client
  })
}

Client.idTokenSignatureAlgorithms = [
  "HS256",
  "HS384",
  "HS512",
  "RS256",
  "RS384",
  "RS512"
]

export default Client
