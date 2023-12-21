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
  organization_id: function ({ organization_id }) { this.organization_id = organization_id },
}

const ORGANIZATION_TEMPLATES = ['invite_organization_member']

class EmailTemplate {
  constructor (params = {}) {
    Object.assign(this, defaults)

    Object.keys(params).forEach((key) => {
      this[key] = params[key]
      assign[key].bind(this)(params)
    })
  }

  get resource () {
    if (ORGANIZATION_TEMPLATES.includes(this.type)) return 'organizations'
    return 'backends'
  }

  get resourceForeignKey () {
    if (ORGANIZATION_TEMPLATES.includes(this.type)) return 'organization_id'
    return 'backend_id'
  }

  save () {
    this.errors = null
    // TODO trigger validate
    const { type, serialized } = this
    const id = this[this.resourceForeignKey]

    return this.constructor.api().patch(`/${this.resource}/${id}/email-templates/${type}`, { template: serialized })
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

    return this.constructor.api().delete(`/${this.resource}/${id}/email-templates/${type}`)
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
      baseURL: `${window.env.BORUTA_ADMIN_BASE_URL}/api`,
      headers: { 'Authorization': `Bearer ${accessToken}` }
    })

    return addClientErrorInterceptor(instance)
  }

  static get (id, type) {
    let resource
    if (ORGANIZATION_TEMPLATES.includes(type)) {
      resource = 'organizations'
    } else {
      resource = 'backends'
    }

    return this.api().get(`/${resource}/${id}/email-templates/${type}`).then(({ data }) => {
      return new EmailTemplate(data.data)
    })
  }
}

export default EmailTemplate
