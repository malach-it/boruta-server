import axios from 'axios'
import { addClientErrorInterceptor } from './utils'

const defaults = {
  id: null,
  txt_content: null,
  html_content: null,
  type: null,
  errors: null
}

const assign = {
  id: function ({ id }) { this.id = id },
  type: function ({ type }) { this.type = type },
  txt_content: function ({ txt_content }) { this.txt_content = txt_content },
  html_content: function ({ html_content }) { this.html_content = html_content },
  backend_id: function ({ backend_id }) { this.backend_id = backend_id },
}

class EmailTemplate {
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
    const { type, backend_id: backendId, serialized } = this

    return this.constructor.api().patch(`/${backendId}/email-templates/${type}`, { template: serialized })
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
    const { type, backend_id: backendId } = this

    return this.constructor.api().delete(`/${backendId}/email-templates/${type}`)
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
    const { txt_content, html_content } = this

    return {
      txt_content,
      html_content
    }
  }

  static api () {
    const accessToken = localStorage.getItem('access_token')

    const instance = axios.create({
      baseURL: `${window.env.BORUTA_ADMIN_BASE_URL}/api/backends`,
      headers: { 'Authorization': `Bearer ${accessToken}` }
    })

    return addClientErrorInterceptor(instance)
  }

  static get (backendId, type) {
    return this.api().get(`/${backendId}/email-templates/${type}`).then(({ data }) => {
      return new EmailTemplate(data.data)
    })
  }
}

export default EmailTemplate
