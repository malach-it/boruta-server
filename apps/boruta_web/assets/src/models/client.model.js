import axios from 'axios'

const defaults = {
  authorize_scopes: false,
  authorized_scopes: []
}

const assign = {
  id: function ({ id }) { this.id = id },
  secret: function ({ secret }) { this.secret = secret },
  redirect_uri: function ({ redirect_uri }) { this.redirect_uri = redirect_uri },
  authorize_scope: function ({ authorize_scope }) { this.authorize_scope = authorize_scope },
  authorized_scopes: function ({ authorized_scopes }) {
    this.authorized_scopes = authorized_scopes.map((name) => {
      return { name }
    })
  }
}
class Client {
  constructor (params = {}) {
    Object.assign(this, defaults)

    Object.keys(params).forEach((key) => {
      this[key] = params[key]
      assign[key].bind(this)(params)
    })
  }

  save () {
    const { id, serialized } = this
    if (id) {
      return this.constructor.api().patch(`/${id}`, { client: serialized })
        .then(({ data }) => Object.assign(this, data.data))
    } else {
      return this.constructor.api().post('/', { client: serialized })
        .then(({ data }) => Object.assign(this, data.data))
    }
  }

  destroy () {
    return this.constructor.api().delete(`/${this.id}`)
  }

  get serialized () {
    const { id, secret, redirect_uri, authorize_scope, authorized_scopes } = this

    return {
      id,
      secret,
      redirect_uri,
      authorize_scope,
      authorized_scopes: authorized_scopes.map((scope) => scope.name)
    }
  }
}

Client.api = function () {
  const accessToken = localStorage.getItem('vue-authenticate.vueauth_token')

  return axios.create({
    baseURL: `${process.env.VUE_APP_BORUTA_BASE_URL}/api/clients`,
    headers: { 'Authorization': `Bearer ${accessToken}` }
  })
}

Client.all = function () {
  return this.api().get('/').then(({ data }) => {
    return data.data.map((client) => new Client(client))
  })
}

Client.get = function (id) {
  return this.api().get(`/${id}`).then(({ data }) => {
    return new Client(data.data)
  })
}

export default Client
