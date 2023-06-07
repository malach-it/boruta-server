import axios from 'axios'
import Scope from './scope.model'
import { addClientErrorInterceptor } from './utils'

const defaults = {
  scopes: []
}

const assign = {
  id: function ({ id }) { this.id = id },
  name: function ({ name }) { this.name = name },
  scopes: function ({ scopes }) { this.scopes = scopes.map(scope => ({ model: new Scope(scope) })) }
}

class Role {
  constructor (params = {}) {
    Object.assign(this, defaults)

    Object.keys(params).forEach((key) => {
      this[key] = params[key]
      assign[key].bind(this)(params)
    })
  }

  save () {
    this.errors = null
    // TODO trigger validate
    let response
    const { id, serialized } = this
    if (id) {
      response = this.constructor.api().patch(`/${id}`, { role: serialized })
    } else {
      response = this.constructor.api().post('/', { role: serialized })
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
      name,
      scopes
    } = this

    console.log(scopes)
    return {
      id,
      name,
      scopes: scopes.map(({ model: { id, name } }) => ({ id, name }))
    }
  }
}

Role.api = function () {
  const accessToken = localStorage.getItem('access_token')

  const instance = axios.create({
    baseURL: `${window.env.BORUTA_ADMIN_BASE_URL}/api/roles`,
    headers: { 'Authorization': `Bearer ${accessToken}` }
  })

  return addClientErrorInterceptor(instance)
}

Role.all = function () {
  return this.api().get('/').then(({ data }) => {
    const result = data.data

    return result.map((role) => new Role(role))
  })
}

Role.get = function (id) {
  return this.api().get(`/${id}`).then(({ data }) => {
    return new Role(data.data)
  })
}

export default Role
