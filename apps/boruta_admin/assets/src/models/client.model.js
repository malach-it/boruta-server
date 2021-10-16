import axios from 'axios'
import Scope from '@/models/scope.model'

const allGrantTypes = ['client_credentials', 'password', 'authorization_code', 'refresh_token', 'implicit', 'revoke', 'introspect']

const defaults = {
  authorize_scopes: false,
  authorized_scopes: [],
  redirect_uris: [],
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
  }
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
          return reject({ authorized_scopes: [ 'cannot be empty' ] })
        }
        if (this.authorized_scopes.filter(({ model: e }) => e.id === scope.id).length > 1) {
          reject({ authorized_scopes: [ 'must be unique' ] })
        }
      })
      resolve()
    })
  }

  save () {
    // TODO trigger validate
    let response
    const { id, serialized } = this
    if (id) {
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
  }

  get serialized () {
    const {
      id,
      name,
      secret,
      redirect_uris,
      public_refresh_token,
      public_revoke,
      authorize_scope,
      authorized_scopes,
      grantTypes,
      access_token_ttl,
      authorization_code_ttl,
      refresh_token_ttl,
      id_token_ttl,
      pkce
    } = this

    return {
      id,
      name,
      secret,
      redirect_uris: redirect_uris.map(({ uri }) => uri),
      authorize_scope,
      access_token_ttl,
      authorization_code_ttl,
      refresh_token_ttl,
      id_token_ttl,
      pkce,
      public_refresh_token,
      public_revoke,
      authorized_scopes: authorized_scopes.map(({ model }) => model.serialized),
      supported_grant_types: grantTypes
        .filter(({ value }) => value)
        .map(({ label }) => label)
    }
  }
}

Client.api = function () {
  const accessToken = localStorage.getItem('access_token')

  return axios.create({
    baseURL: `${window.env.VUE_APP_BORUTA_BASE_URL}/api/clients`,
    headers: { 'Authorization': `Bearer ${accessToken}` }
  })
}

Client.all = function () {
  return this.api().get('/').then(({ data }) => {
    return data.data.map((client) => new Client(client))
  })
}

Client.get = function (id) {
  return this.api().get(`/${id}`).then(({ data }) => {
    return new Client(data.data)
  })
}

export default Client
