import axios from 'axios'

const defaults = {
  authorize_scopes: false,
  authorized_scopes: []
}

const assign = {
  id: function ({ id }) { this.id = id },
  email: function ({ email }) { this.email = email }
}

class User {
  constructor (params = {}) {
    Object.assign(this, defaults)

    Object.keys(params).forEach((key) => {
      this[key] = params[key]
      assign[key].bind(this)(params)
    })
  }

  destroy () {
    return this.constructor.api().delete(`/${this.id}`)
  }
}

User.api = function () {
  const accessToken = localStorage.getItem('access_token')

  return axios.create({
    baseURL: `${process.env.VUE_APP_BORUTA_BASE_URL}/api/users`,
    headers: { 'Authorization': `Bearer ${accessToken}` }
  })
}

User.all = function () {
  return this.api().get('/').then(({ data }) => {
    return data.data.map((user) => new User(user))
  })
}

User.get = function (id) {
  return this.api().get(`/${id}`).then(({ data }) => {
    return new User(data.data)
  })
}

User.default = defaults

User.current = function () {
  return this.api().get(`/current`).then(({ data }) => {
    return new User(data.data)
  })
}

export default User
