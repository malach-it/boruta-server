import axios from 'axios'
import { addClientErrorInterceptor } from './utils'

const defaults = {}

const assign = {
  id: function ({ id }) { this.id = id },
  name: function ({ name }) { this.name = name },
  ip: function ({ ip }) { this.ip = ip },
}

class Node {
  constructor (params = {}) {
    Object.assign(this, defaults)

    Object.keys(params).forEach((key) => {
      this[key] = params[key]
      assign[key].bind(this)(params)
    })
  }
}

Node.api = function () {
  const accessToken = localStorage.getItem('access_token')

  const instance = axios.create({
    baseURL: `${window.env.BORUTA_ADMIN_BASE_URL}/api/service-registry/nodes`,
    headers: { 'Authorization': `Bearer ${accessToken}` }
  })

  return addClientErrorInterceptor(instance)
}

Node.all = function () {
  return this.api().get('/').then(({ data }) => {
    return data.data.map((node) => new Node(node))
  })
}

export default Node
