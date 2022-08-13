import axios from 'axios'
import { addClientErrorInterceptor } from './utils'

const templates = [
  { type: 400, name: "bad-request", label: "Bad request" },
  { type: 403, name: "forbidden", label: "Forbidden" },
  { type: 404, name: "not-found", label: "Not found" },
  { type: 500, name: "internal-server-error", label: "Internal server error" }
]

const defaults = {
  id: null,
  name: null,
  content: null,
  type: null,
  errors: null
}

const assign = {
  id: function ({ id }) { this.id = id },
  name: function ({ name }) { this.name = name },
  type: function ({ type }) { this.type = type },
  content: function ({ content }) { this.content = content },
  label: function ({ label }) { this.label = label }
}

class ErrorTemplate {
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
    const { type, serialized } = this

    return this.constructor.api().patch(`/${type}`, { template: serialized })
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
    const { type } = this

    return this.constructor.api().delete(`/${type}`)
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

  get serialized () {
    const { content } = this

    return {
      content
    }
  }

  static api () {
    const accessToken = localStorage.getItem('access_token')

    const instance = axios.create({
      baseURL: `${window.env.BORUTA_ADMIN_BASE_URL}/api/configuration/error-templates`,
      headers: { 'Authorization': `Bearer ${accessToken}` }
    })

    return addClientErrorInterceptor(instance)
  }

  static get (type) {
    return this.api().get(`/${type}`).then(({ data }) => {
      return new ErrorTemplate(data.data)
    })
  }

  static all () {
    return templates.map(data => new ErrorTemplate(data))
  }
}

export default ErrorTemplate
