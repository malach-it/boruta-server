import axios from 'axios'
import Node from './node.model.js'
import { addClientErrorInterceptor } from './utils'

const defaults = {
}

const assign = {
  status: function ({ status }) { this.status = status },
  to: function ({ to }) {
    this.to = new Node(to)
  },
}

class NodeConnection {
  constructor (params = {}) {
    Object.assign(this, defaults)

    Object.keys(params).forEach((key) => {
      this[key] = params[key]
      assign[key].bind(this)(params)
    })
  }
}

export default NodeConnection
