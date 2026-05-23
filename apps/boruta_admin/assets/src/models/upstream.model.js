import axios from 'axios'
import Scope from './scope.model'
import { addClientErrorInterceptor } from './utils'

const defaultForbiddenResponse = JSON.stringify({
  error: 'FORBIDDEN',
  message: 'You are forbidden to access this resource.'
}, null, 2)

const defaultUnauthorizedResponse = JSON.stringify({
  error: 'UNAUTHORIZED',
  message: 'You are unauthorized to access this resource.'
}, null, 2)

const defaults = {
  errors: null,
  node_name: 'global',
  uris: [],
  required_scopes: [],
  error_content_type: 'application/json',
  forbidden_response: defaultForbiddenResponse,
  unauthorized_response: defaultUnauthorizedResponse,
  keepalive: false,
  rate_limit_enabled: false,
  rate_limit_count: 10,
  rate_limit_time_unit: 'second',
  rate_limit_penality: 500,
  rate_limit_timeout: 5000,
  rate_limit_memory_length: 50
}

const assign = {
  id: function ({ id }) { this.id = id },
  node_name: function ({ node_name }) { this.node_name = node_name },
  scheme: function ({ scheme }) { this.scheme = scheme },
  host: function ({ host }) { this.host = host },
  port: function ({ port }) { this.port = port },
  keepalive: function ({ keepalive }) { this.keepalive = keepalive },
  strip_uri: function ({ strip_uri }) { this.strip_uri = strip_uri },
  forwarded_token_signature_alg: function ({ forwarded_token_signature_alg }) { this.forwarded_token_signature_alg = forwarded_token_signature_alg },
  forwarded_token_secret: function ({ forwarded_token_secret }) { this.forwarded_token_secret = forwarded_token_secret },
  forwarded_token_public_key: function ({ forwarded_token_public_key }) { this.forwarded_token_public_key = forwarded_token_public_key },
  forwarded_token_private_key: function ({ forwarded_token_private_key }) { this.forwarded_token_private_key = forwarded_token_private_key },
  rate_limit_enabled: function ({ rate_limit_enabled }) { this.rate_limit_enabled = rate_limit_enabled },
  rate_limit_count: function ({ rate_limit_count }) { this.rate_limit_count = rate_limit_count },
  rate_limit_time_unit: function ({ rate_limit_time_unit }) { this.rate_limit_time_unit = rate_limit_time_unit },
  rate_limit_penality: function ({ rate_limit_penality }) { this.rate_limit_penality = rate_limit_penality },
  rate_limit_timeout: function ({ rate_limit_timeout }) { this.rate_limit_timeout = rate_limit_timeout },
  rate_limit_memory_length: function ({ rate_limit_memory_length }) { this.rate_limit_memory_length = rate_limit_memory_length },
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
  forbidden_response: function ({ forbidden_response }) { this.forbidden_response = forbidden_response ?? defaultForbiddenResponse },
  unauthorized_response: function ({ unauthorized_response }) { this.unauthorized_response = unauthorized_response ?? defaultUnauthorizedResponse }
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
      node_name,
      scheme,
      host,
      port,
      keepalive,
      uris,
      strip_uri,
      authorize,
      required_scopes,
      error_content_type,
      forbidden_response,
      unauthorized_response,
      forwarded_token_signature_alg,
      forwarded_token_secret,
      forwarded_token_private_key,
      forwarded_token_public_key,
      rate_limit_enabled,
      rate_limit_count,
      rate_limit_time_unit,
      rate_limit_penality,
      rate_limit_timeout,
      rate_limit_memory_length
    } = this

    return {
      id,
      node_name,
      scheme,
      host,
      port,
      keepalive,
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
      forwarded_token_secret,
      forwarded_token_private_key,
      forwarded_token_public_key,
      rate_limit_enabled,
      rate_limit_count,
      rate_limit_time_unit,
      rate_limit_penality,
      rate_limit_timeout,
      rate_limit_memory_length
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

Upstream.nodeList = function () {
  return this.api().get('/nodes').then(({ data }) => {
    return data.data
  })
}

Upstream.all = function () {
  return this.api().get('/').then(({ data }) => {
    const result = data.data

    Object.keys(result).forEach((nodeName) => {
      result[nodeName] = result[nodeName].map((upstream) => new Upstream(upstream))
    })

    return result
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

Upstream.rateLimitTimeUnits = [
  "millisecond",
  "second",
  "minute"
]

export default Upstream
