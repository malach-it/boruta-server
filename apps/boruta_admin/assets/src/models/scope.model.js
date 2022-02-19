import axios from 'axios'
import router from '../router'

const defaults = {
  name: '',
  edit: false,
  errors: null
}

const assign = {
  id: function ({ id }) { this.id = id },
  name: function ({ name }) { this.name = name },
  label: function ({ label }) { this.label = label },
  edit: function ({ edit }) { this.edit = edit },
  public: function ({ public: e }) { this.public = e }
}
class Scope {
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

  reset () {
    return this.constructor.api().get(`/${this.id}`).then(({ data }) => {
      Object.assign(this, defaults)
      return Object.assign(this, data.data)
    })
  }

  save () {
    const { id, serialized } = this
    let response

    this.errors = null

    if (id) {
      response = this.constructor.api().patch(`/${id}`, { scope: serialized })
        .then(({ data }) => Object.assign(this, data.data))
    } else {
      response = this.constructor.api().post('/', { scope: serialized })
        .then(({ data }) => Object.assign(this, data.data))
    }
    return response.catch((error) => {
      const { errors } = error.response.data
      this.errors = errors
      throw errors
    })
  }

  destroy () {
    return this.constructor.api().delete(`/${this.id}`)
  }

  get serialized () {
    const { id, label, name, public: p } = this

    return {
      id,
      label,
      name,
      public: p
    }
  }
}

Scope.api = function () {
  const accessToken = localStorage.getItem('access_token')

  const instance = axios.create({
    baseURL: `${window.env.VUE_APP_BORUTA_BASE_URL}/api/scopes`,
    headers: { 'Authorization': `Bearer ${accessToken}` }
  })

  instance.interceptors.response.use(function (response) {
      return response;
    }, function (error) {
      if (error.response?.status === 404) return router.push({ name: 'not-found' })
      if (error.response?.status === 400) return router.push({ name: 'bad-request' })

      return Promise.reject(error)
    })

  return instance
}

Scope.all = function () {
  return this.api().get('/').then(({ data }) => {
    return data.data.map((client) => new Scope(client))
  })
}

Scope.get = function (id) {
  return this.api().get(`/${id}`).then(({ data }) => {
    return new Scope(data.data)
  })
}

export default Scope
