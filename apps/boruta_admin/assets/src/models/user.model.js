import axios from 'axios'
import Scope from './scope.model'
import { addClientErrorInterceptor } from './utils'

const defaults = {
  errors: null,
  authorize_scopes: false,
  authorized_scopes: [],
  backend_id: ''
}

const assign = {
  id: function ({ id }) { this.id = id },
  backend: function ({ backend }) { this.backend = backend },
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

  get isPersisted() {
    return this.id
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

    const { id, backend_id, serialized } = this
    let response
    if (this.isPersisted) {
      response = this.constructor.api().patch(`/${id}`, { user: serialized })
    } else {
      response = this.constructor.api().post('/', { backend_id, user: serialized })
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
    const { id, email, password, authorized_scopes } = this

    return {
      id,
      email,
      password,
      authorized_scopes: authorized_scopes.map(({ model }) => model.serialized)
    }
  }
}

User.api = function () {
  const accessToken = localStorage.getItem('access_token')

  const instance = axios.create({
    baseURL: `${window.env.BORUTA_ADMIN_BASE_URL}/api/users`,
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

User.upload = function ({ backendId, file, options }) {
  const formData = new FormData()
  formData.append("backend_id", backendId)
  formData.append("file", file)
  if (options.usernameHeader && options.usernameHeader !== '')
    formData.append("options[username_header]", options.usernameHeader)
  if (options.passwordHeader && options.passwordHeader !== '')
    formData.append("options[password_header]", options.passwordHeader)
  if (options.hashPassword && options.hashPassword !== '')
    formData.append("options[hash_password]", options.hashPassword)

  return this.api().post('/', formData, {
    headers: {
      'Content-Type': 'multipart/form-data'
    }
  }).then(({ data }) => data)
}

User.get = function (id) {
  return this.api().get(`/${id}`).then(({ data }) => {
    return new User(data.data)
  })
}

User.default = defaults

export default User
