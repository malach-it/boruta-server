import axios from 'axios'
import Scope from './scope.model'
import IdentityProvider from './identity-provider.model'
import FederationEntity from './federation-entity.model'
import { addClientErrorInterceptor } from './utils'

const allGrantTypes = [
  'client_credentials',
  'password',
  'authorization_code',
  'refresh_token',
  'implicit',
  'preauthorized_code',
  'id_token',
  'vp_token',
  'revoke',
  'introspect'
]

const keyPairTypes = {
  'ec': { curve: ['P-256', 'P-384', 'P-512'] },
  'rsa': { modulus_size: '1024', exponent_size: '65537' }
}

const signaturesAdapters = [
  'Elixir.Boruta.Internal.Signatures',
  'Elixir.Boruta.Universal.Signatures'
]

const defaults = {
  errors: null,
  key_pair_id: null,
  key_pair_type: { type: 'rsa', modulus_size: '1024', exponent_size: '65537' },
  signatures_adapter: 'Elixir.Boruta.Internal.Signatures',
  authorize_scopes: false,
  authorized_scopes: [],
  redirect_uris: [],
  id_token_signature_alg: 'RS512',
  token_endpoint_jwt_auth_alg: 'HS256',
  token_endpoint_auth_methods: ["client_secret_basic", "client_secret_post"],
  identity_provider: { model: new IdentityProvider() },
  federation_entity: { model: new FederationEntity() },
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
  confidential: function ({ confidential }) { this.confidential = confidential },
  pkce: function ({ pkce }) { this.pkce = pkce },
  public_key: function ({ public_key }) { this.public_key = public_key },
  key_pair_type: function ({ key_pair_type }) { this.key_pair_type = key_pair_type },
  signatures_adapter: function ({ signatures_adapter }) { this.signatures_adapter = signatures_adapter },
  did: function ({ did }) { this.did = did },
  access_token_ttl: function ({ access_token_ttl }) { this.access_token_ttl = access_token_ttl },
  authorization_code_ttl: function ({ authorization_code_ttl }) { this.authorization_code_ttl = authorization_code_ttl },
  refresh_token_ttl: function ({ refresh_token_ttl }) { this.refresh_token_ttl = refresh_token_ttl },
  id_token_ttl: function ({ id_token_ttl }) { this.id_token_ttl = id_token_ttl },
  authorization_request_ttl: function ({ authorization_request_ttl }) { this.authorization_request_ttl = authorization_request_ttl },
  secret: function ({ secret }) { this.secret = secret },
  redirect_uris: function ({ redirect_uris }) {
    this.redirect_uris = redirect_uris.map((uri) => ({ uri }))
  },
  public_refresh_token: function ({ public_refresh_token }) { this.public_refresh_token = public_refresh_token },
  public_revoke: function ({ public_revoke }) { this.public_revoke = public_revoke },
  identity_provider: function ({ identity_provider }) {
    this.identity_provider = { model: new IdentityProvider(identity_provider) }
  },
  federation_entity: function ({ federation_entity }) {
    this.federation_entity = { model: new FederationEntity(federation_entity) }
  },
  authorize_scope: function ({ authorize_scope }) { this.authorize_scope = authorize_scope },
  enforce_dpop: function ({ enforce_dpop }) { this.enforce_dpop = enforce_dpop },
  enforce_tx_code: function ({ enforce_tx_code }) { this.enforce_tx_code = enforce_tx_code },
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
  token_endpoint_jwt_auth_alg: function ({ token_endpoint_jwt_auth_alg }) { this.token_endpoint_jwt_auth_alg = token_endpoint_jwt_auth_alg },
  token_endpoint_auth_methods: function ({ token_endpoint_auth_methods }) { this.token_endpoint_auth_methods = token_endpoint_auth_methods },
  jwt_public_key: function ({ jwt_public_key }) { this.jwt_public_key = jwt_public_key },
  id_token_signature_alg: function ({ id_token_signature_alg }) { this.id_token_signature_alg = id_token_signature_alg },
  userinfo_signed_response_alg: function ({ userinfo_signed_response_alg }) { this.userinfo_signed_response_alg = userinfo_signed_response_alg },
  response_mode: function ({ response_mode }) { this.response_mode = response_mode },
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

  async regenerateDid () {
    const { id } = this
    this.constructor.api().post(`/${id}/regenerate_did`)
      .then(({ data }) => {
        const params = data.data

        Object.keys(params).forEach((key) => {
          this[key] = params[key]
          assign[key].bind(this)(params)
        })

        this.key_pair_id = null
        return this
      })
      .catch((error) => {
        const { errors } = error.response.data
        this.errors = errors
        throw errors
      })
  }

  async regenerateKeyPair () {
    const { id } = this
    this.constructor.api().post(`/${id}/regenerate_key_pair`)
      .then(({ data }) => {
        const params = data.data

        Object.keys(params).forEach((key) => {
          this[key] = params[key]
          assign[key].bind(this)(params)
        })

        this.key_pair_id = null
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
      authorization_request_ttl,
      authorize_scope,
      enforce_dpop,
      enforce_tx_code,
      authorized_scopes,
      confidential,
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
      federation_entity,
      secret,
      id_token_signature_alg,
      userinfo_signed_response_alg,
      token_endpoint_jwt_auth_alg,
      token_endpoint_auth_methods,
      jwt_public_key,
      key_pair_id,
      key_pair_type,
      signatures_adapter,
      response_mode
    } = this

    return {
      access_token_ttl,
      authorization_code_ttl,
      authorization_request_ttl,
      authorize_scope,
      enforce_dpop,
      enforce_tx_code,
      authorized_scopes: authorized_scopes.map(({ model }) => model.serialized),
      confidential,
      id,
      id_token_ttl,
      name,
      pkce,
      public_refresh_token,
      public_revoke,
      redirect_uris: redirect_uris.map(({ uri }) => uri),
      refresh_token_ttl,
      identity_provider: identity_provider.model,
      federation_entity: federation_entity.model,
      secret,
      supported_grant_types: grantTypes
        .filter(({ value }) => value)
        .map(({ label }) => label),
      id_token_signature_alg,
      userinfo_signed_response_alg,
      token_endpoint_jwt_auth_alg,
      token_endpoint_auth_methods,
      jwt_public_key,
      key_pair_id,
      key_pair_type,
      signatures_adapter,
      response_mode
    }
  }
}

Client.keyPairTypes = keyPairTypes

Client.signaturesAdapters = signaturesAdapters

Client.api = function () {
  const accessToken = localStorage.getItem('access_token')

  const instance = axios.create({
    baseURL: `${window.env.BORUTA_ADMIN_BASE_URL}/api/clients`,
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
  "EdDSA",
  "ES256",
  "ES384",
  "ES512",
  "HS256",
  "HS384",
  "HS512",
  "RS256",
  "RS384",
  "RS512"
]

Client.clientJwtAuthenticationSignatureAlgorithms = [
  "ES256",
  "ES384",
  "ES512",
  "HS256",
  "HS384",
  "HS512",
  "RS256",
  "RS384",
  "RS512"
]

Client.UserinfoResponseSignatureAlgorithms = [
  null,
  "EdDSA",
  "ES256",
  "ES384",
  "ES512",
  "HS256",
  "HS384",
  "HS512",
  "RS256",
  "RS384",
  "RS512"
]

Client.tokenEndpointAuthMethods = [
  "client_secret_basic",
  "client_secret_post",
  "client_secret_jwt",
  "private_key_jwt"
]

export default Client
