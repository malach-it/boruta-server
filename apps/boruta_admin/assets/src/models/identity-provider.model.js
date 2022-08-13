import axios from 'axios'
import { addClientErrorInterceptor } from './utils'

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
  user_editable: function ({ user_editable }) { this.user_editable = user_editable },
  consentable: function ({ consentable }) { this.consentable = consentable },
  confirmable: function ({ confirmable }) { this.confirmable = confirmable }
}

class IdentityProvider {
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
    this.errors = null
    // TODO trigger validate
    let response
    const { id, serialized } = this
    if (this.isPersisted) {
      response = this.constructor.api().patch(`/${id}`, { identity_provider: serialized })
    } else {
      response = this.constructor.api().post('/', { identity_provider: serialized })
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
        const { code, message, errors } = error.response.data
        this.errors = errors
        throw { code, message, errors }
      })
  }

  get serialized () {
    const { id, name, type, choose_session, registrable, user_editable, consentable, confirmable } = this

    return {
      id,
      name,
      type,
      choose_session,
      user_editable,
      registrable,
      consentable,
      confirmable
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

  static all () {
    return this.api().get('/').then(({ data }) => {
      return data.data.map((identityProvider) => new IdentityProvider(identityProvider))
    })
  }

  static get (id) {
    return this.api().get(`/${id}`).then(({ data }) => {
      return new IdentityProvider(data.data)
    })
  }
}

export default IdentityProvider
