import axios from 'axios'
import moment from 'moment'
import { addClientErrorInterceptor } from './utils'

const defaults = {
  errors: null
}

const assign = {
  time_scale_unit: function ({ time_scale_unit }) { this.time_scale_unit = time_scale_unit },
  overflow: function ({ overflow }) { this.overflow = overflow },
  log_lines: function ({ log_lines }) { this.log_lines = log_lines },
  log_count: function ({ log_count }) { this.log_count = log_count },
  status_codes: function ({ status_codes }) { this.status_codes = status_codes },
  request_counts: function ({ request_counts }) { this.request_counts = request_counts },
  request_times: function ({ request_times }) { this.request_times = request_times },
  labels: function ({ labels }) { this.labels = labels },
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

LogStats.all = function ({ startAt, endAt, application, label }) {
  const params = new URLSearchParams()
  params.append('start_at', moment.utc(startAt).toISOString())
  params.append('end_at', moment.utc(endAt).toISOString())
  params.append('application', application)
  label && params.append('query[label]', label)
  params.append('type', 'request')

  return this.api().get(`?${params.toString()}`).then(({ data }) => {
    return new LogStats(data)
  })
}

export default LogStats
