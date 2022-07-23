<template>
  <div class="dashboard">
    <div class="container">
    <div class="ui segment">
      <h2>Requests</h2>
      <div class="ui requests form">
        <div class="field">
          <label>Application</label>
          <select @change="filter()" v-model="requestsFilter.application">
            <option value=''>All applications</option>
            <option :value="application" v-for="application in requestsFiltersData.applications">{{ application }}</option>
          </select>
        </div>
        <div class="field">
          <label>Request label</label>
          <select @change="filter()" v-model="requestsFilter.requestLabel">
            <option value=''>All request labels</option>
            <option :value="requestLabel" v-for="requestLabel in requestsFiltersData.requestLabels">{{ requestLabel }}</option>
          </select>
        </div>
      </div>
      <div class="ui stackable grid">
        <div class="ten wide request-times column">
          <LineChart :chartData="requestsPerMinute" :options="requestsPerMinuteOptions" height="500" :key="graphRerenders" />
        </div>
        <div class="six wide status-codes column">
          <PieChart :chart-data="statusCodes" :options="statusCodesOptions" :key="graphRerenders" />
        </div>
        <div class="sixteen wide request-times column">
          <LineChart :chartData="requestTimes" :options="requestTimesOptions" height="500" :key="graphRerenders" />
        </div>
      </div>
      <h3>Log trail</h3>
      <div class="ui logs segment">
        <pre>{{ (filteredRequestLogs || requestLogs).join('\n') }}</pre>
      </div>
      </div>
      <h2>Business logs</h2>
      <div class="ui logs segment">
        <pre>{{ businessLogs }}</pre>
      </div>
    </div>
  </div>
</template>

<script>
import { LineChart, PieChart } from "vue-chart-3"
import 'chartjs-adapter-moment'
import Logs from '../services/logs.service'
import GatewayRequests from '../components/GatewayRequests.vue'

const REQUEST_REGEX = /(\d{4}-\d{2}-\d{2}T[^\s]+Z) request_id=(\w+) \[info\] (\w+) (\w+) ([^\s]+) - (\w+) (\d{3}) in (\d+)(\w{2})/
const BUSINESS_REGEX = /(\d{4}-\d{2}-\d{2}T[^\s]+Z) request_id=(\w+) \[info\] (\w+) (\w+) - (\w+)( (\w+)=((\".+\")|([^\s]+)))+/

export default {
  name: 'home',
  components: {
    LineChart,
    PieChart
  },
  data() {
    return {
      // logs: '',
      requestLogs: [],
      businessLogs: '',
      graphRerenders: 0,
      requestsFiltersData: {
        applications: [],
        requestLabels: []
      },
      requestsFilter: {
        application: this.$route.query.application || '',
        requestLabel: this.$route.query.requestLabel || ''
      },
      requestsPerMinute: {
        labels: [],
        datasets: []
      },
      statusCodes: {
        labels: [],
        datasets: []
      },
      requestTimes: {
        labels: [],
        datasets: []
      },
      requestsPerMinuteOptions: {
        plugins: {
          title: {
            display: true,
            text: 'Requests per minute'
          },
          legend: {
            align: 'start',
            position: 'bottom'
          }
        },
        scales: {
          x: {
            type: 'timeseries',
            time: {
              unit: 'hour',
              round: true
            }
          }
        }
      },
      statusCodesOptions: {
        cutout: '30%',
        plugins: {
          title: {
            display: true,
            text: 'Status codes'
          },
          legend: {
            display: false
          }
        }
      },
      requestTimesOptions: {
        plugins: {
          title: {
            display: true,
            text: 'Average request time (ms)'
          },
          legend: {
            align: 'start',
            position: 'bottom'
          }
        },
        scales: {
          x: {
            type: 'timeseries',
            time: {
              unit: 'hour',
              round: true
            }
          }
        }
      }
    }
  },
  async mounted() {
    const stream = await Logs.stream()

    const read = (stream) => {
      stream.read().then(({ done, value }) => {
        // decode Uint8Array to utf-8 string
        const data = new TextDecoder().decode(value)

        // this.logs += data
        data.split('\n').map(log => {
          if (log.match(REQUEST_REGEX)) {
            this.requestLogs.push(`${log}`)
            this.importRequestFilters(log)
            this.importRequestLog(log)
          }
          if (log.match(BUSINESS_REGEX)) this.businessLogs += `${log}\n`
        })

        if (done) {
          this.filter()
          stream.cancel()
          } else {
          read(stream)
        }
      })
    }

    read(stream)
  },
  methods: {
    filter() {
      this.resetGraphs()
      this.filteredRequestLogs = this.requestLogs.filter(log => {
        const requestMatches = log.match(REQUEST_REGEX)
        if (!requestMatches) return

        const application = requestMatches[3]
        let isApplicationFiltered = false
        if (this.requestsFilter.application === '') {
          isApplicationFiltered = false
        } else {
          isApplicationFiltered = (this.requestsFilter.application !== application)
        }

        const method = requestMatches[4]
        const path = requestMatches[5]
        const requestLabel = `${application} - ${method} ${path}`.substring(0, 70)
        let isRequestLabelFiltered = false
        if (this.requestsFilter.requestLabel === '') {
          isRequestLabelFiltered = false
        } else {
          isRequestLabelFiltered = (this.requestsFilter.requestLabel !== requestLabel)
        }

        return !(isApplicationFiltered || isRequestLabelFiltered)
      })

      this.filteredRequestLogs.forEach(this.importRequestLog.bind(this))
    },
    resetGraphs() {
      this.requestsPerMinute = { labels: [], datasets: [] }
      this.statusCodes = { labels: [], datasets: [] }
      this.requestTimes = { labels: [], datasets: [] }
      this.graphRerenders += 1
    },
    importRequestFilters(log) {
      const requestMatches = log.match(REQUEST_REGEX)
      if (!requestMatches) return

      const application = requestMatches[3]

      if (!this.requestsFiltersData.applications.includes(application)) {
        this.requestsFiltersData.applications.push(application)
      }

      const method = requestMatches[4]
      const path = requestMatches[5]
      const requestLabel = `${application} - ${method} ${path}`.substring(0, 70)

      if (!this.requestsFiltersData.requestLabels.includes(requestLabel)) {
        this.requestsFiltersData.requestLabels.push(requestLabel)
      }
    },
    importRequestLog(log) {
      const requestMatches = log.match(REQUEST_REGEX)
      if (!requestMatches) return

      const time = new Date(requestMatches[1])
      time.setMilliseconds(0)
      time.setSeconds(0)
      const application = requestMatches[3]
      if (application === 'boruta_admin' &&
        !(
          (
            this.requestsFilter.application === 'boruta_admin' &&
              (this.requestsFilter.requestLabel.match(/boruta_admin/) ||
                this.requestsFilter.requestLabel == '')
          ) || // application boruta_admin selected
            this.requestsFilter.requestLabel.match(/boruta_admin/) // requestLabel from boruta_admin
        )
      ) return
      const method = requestMatches[4]
      const path = requestMatches[5]
      const statusCode = parseInt(requestMatches[7])
      const requestTime = parseInt(requestMatches[8])
      const requestTimeUnit = requestMatches[9]

      this.populateRequestsPerMinute({ time, application, method, path })
      this.populateStatusCodes({ statusCode, application, method, path })
      this.populateRequestTimes({ time, requestTime, requestTimeUnit, application, method, path })
    },
    populateRequestsPerMinute({ time, application, method, path }) {
      const currentLabel = `${application} - ${method} ${path}`.substring(0, 70)

      const labels = this.requestsPerMinute.labels
      const lastLabel = labels.slice(-1)[0]
      if (!lastLabel || !(lastLabel.getTime() == time.getTime())) {
        labels.push(time)
      }

      let dataset = this.requestsPerMinute.datasets.find(({ label }) => {
        return label === currentLabel
      })
      if (!dataset) {
        dataset = {
          label: currentLabel,
          borderColor: stringToColor(currentLabel),
          backgroundColor: stringToColor(currentLabel),
          fill: false,
          lineTension: 0,
          data: null
        }
        this.requestsPerMinute.datasets.push(dataset)
      }

      const currentData = dataset.data || new Array()
      const nextData = new Array(labels.length)
      for (let i = 0; i < nextData.length; i++) {
        nextData[i] = currentData[i] || 0
      }
      nextData.splice(-1, 1, nextData.slice(-1)[0] + 1)

      dataset.data = nextData.map(value => value === 0 ? NaN : value)
    },
    populateStatusCodes({ statusCode, application, method, path }) {
      const currentLabel = statusCode

      const label = statusCode
      const labels = this.statusCodes.labels
      if (!labels.includes(currentLabel)) {
        labels.push(label)
      }

      const currentDatasetLabel = `${application} - ${method} ${path}`.substring(0, 70)
      let dataset = this.statusCodes.datasets.find(({ label }) => {
        return label === currentDatasetLabel
      })
      if (!dataset) {
        dataset = {
          label: currentDatasetLabel,
          backgroundColor: stringToColor(currentDatasetLabel),
          data: null
        }
        this.statusCodes.datasets.push(dataset)
      }

      const currentData = dataset.data || new Array()
      const nextData = new Array(labels.length)
      for (let i = 0; i < nextData.length; i++) {
        nextData[i] = currentData[i] || 0
      }
      nextData.splice(labels.indexOf(statusCode), 1, nextData.slice(-1)[0] + 1)

      dataset.data = nextData.map(value => value === 0 ? NaN : value)
    },
    populateRequestTimes({ time, requestTime, requestTimeUnit, application, method, path }) {
      const currentLabel = `${application} - ${method} ${path}`.substring(0, 70)

      const labels = this.requestTimes.labels
      const lastLabel = labels.slice(-1)[0]
      if (!lastLabel || !(lastLabel.getTime() == time.getTime())) {
        labels.push(time)
      }

      let dataset = this.requestTimes.datasets.find(({ label }) => {
        return label === currentLabel
      })
      if (!dataset) {
        dataset = {
          label: currentLabel,
          borderColor: stringToColor(currentLabel),
          backgroundColor: stringToColor(currentLabel),
          fill: false,
          lineTension: 0,
          data: null
        }
        this.requestTimes.datasets.push(dataset)
      }

      const currentData = dataset.data || new Array()
      const nextData = new Array(labels.length)
      for (let i = 0; i < nextData.length; i++) {
        nextData[i] = currentData[i] || 0
      }
      let requestTimeMilliseconds
      if (requestTimeUnit === 'ms') {
        requestTimeMilliseconds = requestTime
      } else if (requestTimeUnit === 'µs') {
        requestTimeMilliseconds = requestTime / 1000
      }
      nextData.splice(-1, 1, (nextData.slice(-1)[0] + requestTimeMilliseconds) / 2)

      dataset.data = nextData.map(value => value === 0 ? NaN : value)
    }
  },
  watch: {
    requestsFilter: {
      handler({ application, requestLabel }) {
        const query = {}

        if (application !== '') query.application = application
        if (requestLabel !== '') query.requestLabel = requestLabel

        this.$router.push({path: this.$route.path, query });
      },
      deep: true
    },
    $route: {
      handler(route) {
        this.requestsFilter = {
          application: route.query.application || '',
          requestLabel: route.query.requestLabel || ''
        }
        this.filter()
      },
      deep: true
    }
  }
}

function stringToColor(str) {
  let hash = 0
  for (let i = 0; i < str.length; i++) {
    hash = str.charCodeAt(i) + ((hash << 5) - hash)
  }
  let colour = '#'
  for (let i = 0; i < 3; i++) {
    const value = (hash >> (i * 8)) & 0xFF
    colour += ('00' + value.toString(16)).substr(-2)
  }
  return colour
}
</script>

<style scoped lang="scss">
.dashboard {
  position: relative;
  .logs.segment {
    overflow: hidden;
    overflow-x: scroll;
    overflow-y: scroll;
    max-height: 30vh;
  }
  .status-codes {
    display: flex!important;
    align-items: center;
    justify-content: center;
  }
}
</style>
