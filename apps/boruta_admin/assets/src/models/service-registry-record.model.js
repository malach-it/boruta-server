import axios from 'axios'
import { addClientErrorInterceptor } from './utils'

const assign = {
  id: function ({ id }) { this.id = id },
  node_name: function ({ node_name }) { this.node_name = node_name },
  erlang_node_name: function ({ erlang_node_name }) { this.erlang_node_name = erlang_node_name },
  certificate: function ({ certificate }) { this.certificate = certificate },
  configuration: function ({ configuration }) { this.configuration = configuration },
  ip_address: function ({ ip_address }) { this.ip_address = ip_address },
  aliases: function ({ aliases }) { this.aliases = aliases || [] },
  status: function ({ status }) { this.status = status },
  inserted_at: function ({ inserted_at }) { this.inserted_at = inserted_at },
  updated_at: function ({ updated_at }) { this.updated_at = updated_at }
}

class ServiceRegistryRecord {
  constructor (params = {}) {
    Object.keys(params).forEach((key) => {
      this[key] = params[key]
      if (assign[key]) assign[key].bind(this)(params)
    })
  }
}

ServiceRegistryRecord.api = function () {
  const accessToken = localStorage.getItem('access_token')

  const instance = axios.create({
    baseURL: `${window.env.BORUTA_ADMIN_BASE_URL}/api/upstreams/service-registry`,
    headers: { 'Authorization': `Bearer ${accessToken}` }
  })

  return addClientErrorInterceptor(instance)
}

ServiceRegistryRecord.all = function () {
  return this.api().get('/').then(({ data }) => {
    return data.data.map((record) => new ServiceRegistryRecord(record))
  })
}

export default ServiceRegistryRecord
