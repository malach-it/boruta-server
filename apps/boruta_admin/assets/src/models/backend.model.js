import axios from 'axios'
import { addClientErrorInterceptor } from './utils'

const DEFAULT_ID = 'non-existing'

const defaults = {
  id: DEFAULT_ID,
  name: null,
  type: 'Elixir.BorutaIdentity.Accounts.Internal',
  errors: null,
  password_hashing_alg: 'argon2',
  password_hashing_opts: {}
}

const assign = {
  id: function ({ id }) { this.id = id },
  name: function ({ name }) { this.name = name },
  type: function ({ type }) { this.type = type },
  is_default: function ({ is_default }) { this.is_default = is_default },
  password_hashing_alg: function ({ password_hashing_alg }) { this.password_hashing_alg = password_hashing_alg },
  password_hashing_opts: function ({ password_hashing_opts }) { this.password_hashing_opts = password_hashing_opts }
}

class Backend {
  constructor (params = {}) {
    Object.assign(this, defaults)

    Object.keys(params).forEach((key) => {
      this[key] = params[key]
      assign[key].bind(this)(params)
    })
  }

  get isPersisted () {
    return this.id && this.id != DEFAULT_ID
  }

  save () {
    this.errors = null
    // TODO trigger validate
    let response
    const { id, serialized } = this
    if (this.isPersisted) {
      response = this.constructor.api().patch(`/${id}`, { backend: serialized })
    } else {
      response = this.constructor.api().post('/', { backend: serialized })
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
    const { id, name, type, is_default, password_hashing_alg, password_hashing_opts } = this
    const formattedPasswordHashingOpts = {}
    Object.keys(password_hashing_opts).forEach(key => {
      const value = password_hashing_opts[key]
      if (value !== '') {
        formattedPasswordHashingOpts[key] = value
      }
    })

    return {
      id,
      name,
      type,
      is_default,
      password_hashing_alg,
      password_hashing_opts: formattedPasswordHashingOpts
    }
  }

  static get passwordHashingAlgorithms() {
    return [
      { name: 'argon2', label: 'Argon2' },
      { name: 'bcrypt', label: 'Bcrypt' },
      { name: 'pbkdf2', label: 'Pbkdf2' }
    ]
  }

  static get passwordHashingOpts() {
    return {
      'argon2': [
        { name: 'salt_len', type: 'number', label: 'Length of the random salt (in bytes)', default: 16 },
        { name: 't_cost', type: 'number', label: 'Time cost', default: 8 },
        { name: 'm_cost', type: 'number', label: 'Memory usage', default: 16 },
        { name: 'parallelism', type: 'number', label: 'Number of parralel threads', default: 2 },
        { name: 'format', type: 'text', label: 'Output format (encoded, raw_hash, or report)', default: 'encoded' },
        { name: 'hash_len', type: 'number', label: 'Length of the hash (in bytes)', default: 32 },
        { name: 'argon2_type', type: 'number', label: 'Argon2 type (0 argon2d, 1 argon2i, 2 argon2id)', default: 2 }
      ],
      'bcrypt': [],
      'pbkdf2': []
    }
  }

  static api () {
    const accessToken = localStorage.getItem('access_token')

    const instance = axios.create({
      baseURL: `${window.env.BORUTA_ADMIN_BASE_URL}/api/backends`,
      headers: { 'Authorization': `Bearer ${accessToken}` }
    })

    return addClientErrorInterceptor(instance)
  }

  static all () {
    return this.api().get('/').then(({ data }) => {
      return data.data.map((identityProvider) => new Backend(identityProvider))
    })
  }

  static get (id) {
    return this.api().get(`/${id}`).then(({ data }) => {
      return new Backend(data.data)
    })
  }
}

export default Backend
