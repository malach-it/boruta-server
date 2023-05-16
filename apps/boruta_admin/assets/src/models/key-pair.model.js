import axios from 'axios'
import { addClientErrorInterceptor } from './utils'

const defaults = {
}

const assign = {
  id: function ({ id }) { this.id = id },
  public_key: function ({ public_key }) { this.public_key = public_key },
  is_default: function ({ is_default }) { this.is_default = is_default }
}
class KeyPair {
  constructor (params = {}) {
    Object.assign(this, defaults)

    Object.keys(params).forEach((key) => {
      this[key] = params[key]
      assign[key].bind(this)(params)
    })
  }

  get persisted () {
    return !!this.id
  }

  save () {
    const { id, serialized } = this
    let response

    this.errors = null

    if (id) {
      response = this.constructor.api().patch(`/${id}`, { key_pair: serialized })
        .then(({ data }) => Object.assign(this, data.data))
    } else {
      response = this.constructor.api().post('/', { key_pair: serialized })
        .then(({ data }) => Object.assign(this, data.data))
    }
    return response.catch((error) => {
      const { code, message, errors } = error.response.data
      this.errors = errors
      throw { code, message, errors }
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
    const { id, is_default } = this

    return {
      id,
      is_default
    }
  }
}

KeyPair.api = function () {
  const accessToken = localStorage.getItem('access_token')

  const instance = axios.create({
    baseURL: `${window.env.BORUTA_ADMIN_BASE_URL}/api/key-pairs`,
    headers: { 'Authorization': `Bearer ${accessToken}` }
  })

  return addClientErrorInterceptor(instance)
}

KeyPair.all = function () {
  return this.api().get('/').then(({ data }) => {
    return data.data.map((keyPair) => new KeyPair(keyPair))
  })
}

KeyPair.get = function (id) {
  return this.api().get(`/${id}`).then(({ data }) => {
    return new KeyPair(data.data)
  })
}

export default KeyPair
