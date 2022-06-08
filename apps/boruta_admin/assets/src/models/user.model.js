import axios from 'axios'
import router from '../router'
import Scope from './scope.model'
import { addClientErrorInterceptor } from './utils'

const defaults = {
  errors: null,
  authorize_scopes: false,
  authorized_scopes: []
}

const assign = {
  id: function ({ id }) { this.id = id },
  email: function ({ email }) { this.email = email },
  authorized_scopes: function ({ authorized_scopes }) {
    this.authorized_scopes = authorized_scopes.map((scope) => {
      return { model: new Scope(scope) }
    })
  }
}

class User {
  constructor (params = {}) {
    Object.assign(this, defaults)

    Object.keys(params).forEach((key) => {
      this[key] = params[key]
      assign[key].bind(this)(params)
    })
  }

  // TODO factorize with Client#validate
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

    const { id, serialized } = this
    let response
    if (id) {
      response = this.constructor.api().patch(`/${id}`, { user: serialized })
    } else {
      response = this.constructor.api().post('/', { user: serialized })
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
    const { id, authorized_scopes } = this

    return {
      id,
      authorized_scopes: authorized_scopes.map(({ model }) => model.serialized)
    }
  }
}

User.api = function () {
  const accessToken = localStorage.getItem('access_token')

  const instance = axios.create({
    baseURL: `${window.env.VUE_APP_BORUTA_BASE_URL}/api/users`,
    headers: { 'Authorization': `Bearer ${accessToken}` }
  })

  return addClientErrorInterceptor(instance)
}

User.all = function ({ pageNumber }) {
  return this.api().get(`/?page=${pageNumber}`).then(({
    data: {
      data,
      page_number: currentPage,
      total_pages: totalPages,
    }
  }) => {
    return {
      data: data.map((user) => new User(user)),
      currentPage,
      totalPages
    }

  })
}

User.get = function (id) {
  return this.api().get(`/${id}`).then(({ data }) => {
    return new User(data.data)
  })
}

User.default = defaults

User.current = function () {
  return this.api().get(`/current`).then(({ data }) => {
    return new User(data.data)
  })
}

export default User
