import axios from 'axios'
import Scope from './scope.model'
import Role from './role.model'
import Backend from './backend.model'
import { addClientErrorInterceptor } from './utils'

const defaults = {
  errors: null
}

const assign = {
  id: function ({ id }) { this.id = id },
  name: function ({ name }) { this.name = name },
  label: function ({ label }) { this.label = label }
}

class Organization {
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

  async save () {
    this.errors = null

    const { id, serialized } = this
    let response
    if (this.isPersisted) {
      response = this.constructor.api().patch(`/${id}`, { organization: serialized })
    } else {
      response = this.constructor.api().post('/', { organization: serialized })
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
    const { name, label } = this

    return {
      name,
      label
    }
  }
}

Organization.api = function () {
  const accessToken = localStorage.getItem('access_token')

  const instance = axios.create({
    baseURL: `${window.env.BORUTA_ADMIN_BASE_URL}/api/organizations`,
    headers: { 'Authorization': `Bearer ${accessToken}` }
  })

  return addClientErrorInterceptor(instance)
}

Organization.all = function ({ query, pageNumber }) {
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
      data: data.map((user) => new Organization(user)),
      currentPage,
      totalPages,
      totalEntries
    }

  })
}

Organization.get = function (id) {
  return this.api().get(`/${id}`).then(({ data }) => {
    return new Organization(data.data)
  })
}

export default Organization
