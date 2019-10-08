import axios from 'axios'
import Scope from '@/models/scope.model'

const defaults = {
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
          return reject({ authorized_scopes: [ 'cannot be empty' ] })
        }
        if (this.authorized_scopes.filter(({ model: e }) => e.id === scope.id).length > 1) {
          reject({ authorized_scopes: [ 'must be unique' ] })
        }
      })
      resolve()
    })
  }
  async save () {
    await this.validate()
    const { id, serialized } = this
    if (id) {
      return this.constructor.api().patch(`/${id}`, { user: serialized })
        .then(({ data }) => Object.assign(this, data.data))
    } else {
      return this.constructor.api().post('/', { user: serialized })
        .then(({ data }) => Object.assign(this, data.data))
    }
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

  return axios.create({
    baseURL: `${process.env.VUE_APP_BORUTA_BASE_URL}/api/users`,
    headers: { 'Authorization': `Bearer ${accessToken}` }
  })
}

User.all = function () {
  return this.api().get('/').then(({ data }) => {
    return data.data.map((user) => new User(user))
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
