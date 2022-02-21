import axios from 'axios'
import router from '../router'

const DEFAULT_ID = 'non-existing'

const defaults = {
  id: DEFAULT_ID,
  name: null,
  type: 'internal',
  errors: null
}

const assign = {
  id: function ({ id }) { this.id = id },
  name: function ({ name }) { this.name = name },
  type: function ({ type }) { this.type = type },
  choose_session: function ({ choose_session }) { this.choose_session = choose_session },
  registrable: function ({ registrable }) { this.registrable = registrable },
  consentable: function ({ consentable }) { this.consentable = consentable },
  confirmable: function ({ confirmable }) { this.confirmable = confirmable }
}

class RelyingParty {
  constructor (params = {}) {
    Object.assign(this, defaults)

    Object.keys(params).forEach((key) => {
      this[key] = params[key]
      assign[key].bind(this)(params)
    })
  }

  get isPersisted () {
    return this.id && this.id != DEFAULT_ID
  }

  save () {
    // TODO trigger validate
    let response
    const { id, serialized } = this
    if (this.isPersisted) {
      response = this.constructor.api().patch(`/${id}`, { relying_party: serialized })
    } else {
      response = this.constructor.api().post('/', { relying_party: serialized })
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
      .catch((error) => {
        const { errors } = error.response.data
        this.errors = errors
        throw errors
      })
  }

  get serialized () {
    const { id, name, type, choose_session, registrable, consentable, confirmable } = this

    return {
      id,
      name,
      type,
      choose_session,
      registrable,
      consentable,
      confirmable
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

  static all () {
    return this.api().get('/').then(({ data }) => {
      return data.data.map((relyingParty) => new RelyingParty(relyingParty))
    })
  }

  static get (id) {
    return this.api().get(`/${id}`).then(({ data }) => {
      return new RelyingParty(data.data)
    })
  }
}

export default RelyingParty
