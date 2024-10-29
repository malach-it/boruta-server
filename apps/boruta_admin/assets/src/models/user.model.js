import axios from 'axios'
import Scope from './scope.model'
import Role from './role.model'
import Organization from './organization.model'
import Backend from './backend.model'
import { addClientErrorInterceptor } from './utils'

const defaults = {
  errors: null,
  authorize_scopes: false,
  authorized_scopes: [],
  roles: [],
  organizations: [],
  backend_id: '',
  backend: new Backend(),
  metadata: {},
  federated_metadata: {}
}

const assign = {
  id: function ({ id }) { this.id = id },
  uid: function ({ uid }) { this.uid = uid },
  backend: function ({ backend }) { this.backend = backend },
  email: function ({ email }) { this.email = email },
  totp_registered_at: function ({ totp_registered_at }) { this.totp_registered_at = totp_registered_at },
  federated_metadata: function ({ federated_metadata }) { this.federated_metadata = federated_metadata },
  metadata: function ({ metadata: rawMetadata }) {
    const metadata = {}

    for (const key in rawMetadata) {
      metadata[key] = {
        displayStatus: rawMetadata[key].display?.includes('status'),
        ...rawMetadata[key]
      }
    }
    this.metadata = metadata
  },
  group: function ({ group }) { this.group = group },
  authorized_scopes: function ({ authorized_scopes }) {
    this.authorized_scopes = authorized_scopes.map((scope) => {
      return { model: new Scope(scope) }
    })
  },
  roles: function ({ roles }) {
    this.roles = roles.map((role) => {
      return { model: new Role(role) }
    })
  },
  organizations: function ({ organizations }) {
    this.organizations = organizations.map((organization) => {
      return { model: new Organization(organization) }
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
    const { id, email, password, metadata: rawMetadata, group, authorized_scopes, roles, organizations } = this

    const metadata = {}

    for (const key in rawMetadata) {
      metadata[key] = {
        display: rawMetadata[key].displayStatus ? ['status'] : [],
        value: rawMetadata[key].value,
        status: rawMetadata[key].status
      }
    }

    return {
      id,
      email,
      password,
      metadata,
      group,
      authorized_scopes: authorized_scopes.map(({ model }) => model.serialized),
      roles: roles.map(({ model }) => model.serialized),
      organizations: organizations.map(({ model }) => model.serialized)
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

User.all = function ({ query, pageNumber }) {
  const searchParams = new URLSearchParams()
  pageNumber && searchParams.append('page', pageNumber)
  query && searchParams.append('q', query)

  return this.api().get(`/?${searchParams.toString()}`).then(({
    data: {
      data,
      total_entries: totalEntries,
      page_number: currentPage,
      total_pages: totalPages,
    }
  }) => {
    return {
      data: data.map((user) => new User(user)),
      currentPage,
      totalPages,
      totalEntries
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

  options.metadataHeaders.forEach(header => {
    formData.append("options[metadata_headers][]", `${header.origin}>${header.target}`)
  })

  return this.api().post('/', formData, {
    headers: {
      'Content-Type': 'multipart/form-data'
    }
  })
    .then(({ data }) => data)
    .catch((error) => {
      const { errors } = error.response.data
      this.errors = errors
      throw errors
    })
}

User.get = function (id) {
  return this.api().get(`/${id}`).then(({ data }) => {
    return new User(data.data)
  })
}

User.default = defaults

export default User
