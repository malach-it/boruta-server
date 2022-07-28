import axios from 'axios'
import router from '../router'
import Scope from './scope.model'
import { addClientErrorInterceptor } from './utils'

const defaults = {
  errors: null,
  uris: [],
  required_scopes: [],
  pool_size: 10,
  max_idle_time: 10
}

const assign = {
  id: function ({ id }) { this.id = id },
  scheme: function ({ scheme }) { this.scheme = scheme },
  host: function ({ host }) { this.host = host },
  port: function ({ port }) { this.port = port },
  pool_size: function ({ pool_size }) { this.pool_size = pool_size },
  max_idle_time: function ({ max_idle_time }) { this.max_idle_time = max_idle_time },
  strip_uri: function ({ strip_uri }) { this.strip_uri = strip_uri },
  uris: function ({ uris }) {
    this.uris = uris.map((uri) => ({ uri }))
  },
  authorize: function ({ authorize }) { this.authorize = authorize },
  required_scopes: function ({ required_scopes }) {
    this.required_scopes = Object.keys(required_scopes).flatMap((method) => {
      return required_scopes[method].map(name => ({ model: new Scope({ name }), method: method }))
    }, {})
  }
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
      max_idle_time,
      uris,
      strip_uri,
      authorize,
      required_scopes
    } = this

    return {
      id,
      scheme,
      host,
      port,
      pool_size,
      max_idle_time,
      uris: uris.map(({ uri }) => uri),
      required_scopes: required_scopes.reduce((acc, { model: { name }, method }) => {
        acc[method] = acc[method] || []
        acc[method].push(name)
        return acc
      }, {}),
      strip_uri,
      authorize
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

export default Upstream
