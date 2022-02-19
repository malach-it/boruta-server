import axios from 'axios'
import router from '../router'

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
  relying_party_id: function ({ relying_party_id }) { this.relying_party_id = relying_party_id },
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
    // TODO trigger validate
    const { type, relying_party_id: relyingPartyId, serialized } = this

    return this.constructor.api().patch(`/${relyingPartyId}/templates/${type}`, { template: serialized })
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
      baseURL: `${window.env.VUE_APP_BORUTA_BASE_URL}/api/relying-parties`,
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

  static get (relyingPartyId, type) {
    return this.api().get(`/${relyingPartyId}/templates/${type}`).then(({ data }) => {
      return new Template(data.data)
    })
  }
}

export default Template
