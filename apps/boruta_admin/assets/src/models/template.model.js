import axios from 'axios'
import router from '../router'
import { addClientErrorInterceptor } from './utils'

const defaults = {
  id: null,
  name: null,
  content: null,
  type: null,
  errors: null
}

const assign = {
  id: function ({ id }) { this.id = id },
  type: function ({ type }) { this.type = type },
  content: function ({ content }) { this.content = content },
  identity_provider_id: function ({ identity_provider_id }) { this.identity_provider_id = identity_provider_id },
}

class Template {
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
    const { type, identity_provider_id: identityProviderId, serialized } = this

    return this.constructor.api().patch(`/${identityProviderId}/templates/${type}`, { template: serialized })
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
    const { type, identity_provider_id: identityProviderId } = this

    return this.constructor.api().delete(`/${identityProviderId}/templates/${type}`)
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
      baseURL: `${window.env.BORUTA_ADMIN_BASE_URL}/api/identity-providers`,
      headers: { 'Authorization': `Bearer ${accessToken}` }
    })

    return addClientErrorInterceptor(instance)
  }

  static get (identityProviderId, type) {
    return this.api().get(`/${identityProviderId}/templates/${type}`).then(({ data }) => {
      return new Template(data.data)
    })
  }
}

export default Template
