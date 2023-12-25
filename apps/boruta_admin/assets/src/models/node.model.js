import axios from 'axios'
import NodeConnection from './node-connection.model.js'
import { addClientErrorInterceptor } from './utils'

const defaults = {
  connections: []
}

const assign = {
  id: function ({ id }) { this.id = id },
  name: function ({ name }) { this.name = name },
  node_name: function ({ node_name }) { this.node_name = node_name },
  status: function ({ status }) { this.status = status },
  ip: function ({ ip }) { this.ip = ip },
  connections: function ({ connections }) {
    this.connections = connections.map(connection => new NodeConnection(connection))
  },
}

class Node {
  constructor (params = {}) {
    Object.assign(this, defaults)

    Object.keys(params).forEach((key) => {
      this[key] = params[key]
      assign[key].bind(this)(params)
    })
  }

  destroy() {
    return this.constructor
      .api()
      .delete(`/${this.id}`)
      .catch((error) => {
        const { code, message, errors } = error.response.data;
        this.errors = errors;
        throw { code, message, errors };
      });
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
