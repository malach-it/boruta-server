import axios from 'axios'
import moment from 'moment'
import { addClientErrorInterceptor } from './utils'

const defaults = {
  errors: null,
  events: []
}

const assign = {
  time_scale_unit: function ({ time_scale_unit }) { this.time_scale_unit = time_scale_unit },
  overflow: function ({ overflow }) { this.overflow = overflow },
  log_lines: function ({ log_lines }) { this.log_lines = log_lines },
  log_count: function ({ log_count }) { this.log_count = log_count },
  events: function ({ events }) { this.events = events },
  counts: function ({ counts }) { this.counts = counts },
  business_event_counts: function ({ business_event_counts }) { this.business_event_counts = business_event_counts },
  gateway_times: function ({ gateway_times }) { this.gateway_times = gateway_times },
  domains: function ({ domains }) { this.domains = domains },
  actions: function ({ actions }) { this.actions = actions }

}

class LogStats {
  constructor (params = {}) {
    Object.assign(this, defaults)

    Object.keys(params).forEach((key) => {
      this[key] = params[key]
      assign[key].bind(this)(params)
    })
  }
}

LogStats.api = function () {
  const accessToken = localStorage.getItem('access_token')

  const instance = axios.create({
    baseURL: `${window.env.BORUTA_ADMIN_BASE_URL}/api/logs`,
    headers: { 'Authorization': `Bearer ${accessToken}` }
  })

  return addClientErrorInterceptor(instance)
}

LogStats.all = function ({ startAt, endAt, application, domain, action, sub, resourceId, eventsOnly }) {
  const params = new URLSearchParams()
  params.append('start_at', startAt === 'all' ? 'all' : moment.utc(startAt).toISOString())
  params.append('end_at', moment.utc(endAt).toISOString())
  params.append('application', application)
  domain && params.append('query[domain]', domain)
  action && params.append('query[action]', action)
  sub && params.append('query[sub]', sub)
  resourceId && params.append('query[resource_id]', resourceId)
  eventsOnly && params.append('events_only', 'true')
  params.append('type', 'business')

  return this.api().get(`?${params.toString()}`).then(({ data }) => {
    return new LogStats(data)
  }).catch(error => {
    throw error.response.data
  })
}

export default LogStats
