import axios from 'axios'
import Scope from './scope.model'
import { addClientErrorInterceptor } from './utils'

const defaults = {
  errors: null,
  uris: [],
  required_scopes: [],
  pool_size: 10,
  pool_count: 1,
  max_idle_time: 10
}

const assign = {
  id: function ({ id }) { this.id = id },
  scheme: function ({ scheme }) { this.scheme = scheme },
  host: function ({ host }) { this.host = host },
  port: function ({ port }) { this.port = port },
  pool_size: function ({ pool_size }) { this.pool_size = pool_size },
  pool_count: function ({ pool_count }) { this.pool_count = pool_count },
  max_idle_time: function ({ max_idle_time }) { this.max_idle_time = max_idle_time },
  strip_uri: function ({ strip_uri }) { this.strip_uri = strip_uri },
  forwarded_token_signature_alg: function ({ forwarded_token_signature_alg }) { this.forwarded_token_signature_alg = forwarded_token_signature_alg },
  forwarded_token_secret: function ({ forwarded_token_secret }) { this.forwarded_token_secret = forwarded_token_secret },
  uris: function ({ uris }) {
    this.uris = uris.map((uri) => ({ uri }))
  },
  authorize: function ({ authorize }) { this.authorize = authorize },
  required_scopes: function ({ required_scopes }) {
    this.required_scopes = Object.keys(required_scopes).flatMap((method) => {
      return required_scopes[method].map(name => ({ model: new Scope({ name }), method: method }))
    }, {})
  },
  error_content_type: function ({ error_content_type }) { this.error_content_type = error_content_type },
  forbidden_response: function ({ forbidden_response }) { this.forbidden_response = forbidden_response },
  unauthorized_response: function ({ unauthorized_response }) { this.unauthorized_response = unauthorized_response }
}

class Upstream {
  constructor (params = {}) {
    Object.assign(this, defaults)

    Object.keys(params).forEach((key) => {
      this[key] = params[key]
      assign[key].bind(this)(params)
    })
  }

  get baseUrl () {
    const { scheme, host, port } = this

    return `${scheme}://${host}:${port}`
  }

  save () {
    this.errors = null
    // TODO trigger validate
    let response
    const { id, serialized } = this
    if (id) {
      response = this.constructor.api().patch(`/${id}`, { upstream: serialized })
    } else {
      response = this.constructor.api().post('/', { upstream: serialized })
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
      id,
      scheme,
      host,
      port,
      pool_size,
      pool_count,
      max_idle_time,
      uris,
      strip_uri,
      authorize,
      required_scopes,
      error_content_type,
      forbidden_response,
      unauthorized_response,
      forwarded_token_signature_alg,
      forwarded_token_secret
    } = this

    return {
      id,
      scheme,
      host,
      port,
      pool_size,
      pool_count,
      max_idle_time,
      uris: uris.map(({ uri }) => uri),
      required_scopes: required_scopes.reduce((acc, { model: { name }, method }) => {
        acc[method] = acc[method] || []
        acc[method].push(name)
        return acc
      }, {}),
      strip_uri,
      authorize,
      error_content_type,
      forbidden_response,
      unauthorized_response,
      forwarded_token_signature_alg,
      forwarded_token_secret
    }
  }
}

Upstream.api = function () {
  const accessToken = localStorage.getItem('access_token')

  const instance = axios.create({
    baseURL: `${window.env.BORUTA_ADMIN_BASE_URL}/api/upstreams`,
    headers: { 'Authorization': `Bearer ${accessToken}` }
  })

  return addClientErrorInterceptor(instance)
}

Upstream.all = function () {
  return this.api().get('/').then(({ data }) => {
    return data.data.map((upstream) => new Upstream(upstream))
  })
}

Upstream.get = function (id) {
  return this.api().get(`/${id}`).then(({ data }) => {
    return new Upstream(data.data)
  })
}

Upstream.forwardedTokenSignatureAlgorithms = [
  "HS256",
  "HS384",
  "HS512",
  "RS256",
  "RS384",
  "RS512"
]

export default Upstream
