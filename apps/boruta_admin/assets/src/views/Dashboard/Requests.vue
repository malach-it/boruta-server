<template>
  <div class="dashboard">
    <div class="container">
      <div class="ui dates form">
        <div class="ui stackable grid">
          <div class="four wide request-times column">
            <h1>Requests</h1>
          </div>
          <div class="five wide request-times column">
            <input type="datetime-local" v-model="requestsFilter.startAt" />
          </div>
          <div class="five wide request-times column">
            <input type="datetime-local" v-model="requestsFilter.endAt" />
          </div>
          <div class="two wide request-times column">
            <button class="ui fluid blue button" @click="getLogs()">Filter</button>
          </div>
        </div>
      </div>
      <div class="ui segment">
        <div class="ui requests form">
          <div class="ui stackable grid">
            <div class="ten wide filter-form column">
              <div class="field">
                <label>Application</label>
                <select @change="filter()" v-model="requestsFilter.application">
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
            <div class="six wide log-count column">
              <div class="counts">
                <label>Log count <span>{{ logCount }}</span></label>
                <label>Filtered Log count: <span>{{ filteredLogCount }}</span></label>
              </div>
            </div>
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
    </div>
  </div>
</template>

<script>
import { LineChart, PieChart } from "vue-chart-3"
import moment from 'moment'
import 'chartjs-adapter-moment'
import Logs from '../../services/logs.service'
import GatewayRequests from '../../components/GatewayRequests.vue'

const REQUEST_REGEX = /(\d{4}-\d{2}-\d{2}T[^\s]+Z) request_id=(\w+) \[info\] (\w+) (\w+) ([^\s]+) - (\w+) (\d{3}) in (\d+)(\w{2})/

export default {
  name: 'requests',
  components: {
    LineChart,
    PieChart
  },
  data() {
    return {
      // logs: '',
      requestLogs: [],
      filteredRequestLogs: [],
      graphRerenders: 0,
      requestsFiltersData: {
        applications: [],
        requestLabels: []
      },
      requestsFilter: {
        startAt: this.$route.query.startAt || moment().utc().startOf('day').format("yyyy-MM-DDTHH:mm"),
        endAt: this.$route.query.endAt || moment().utc().endOf('day').format("yyyy-MM-DDTHH:mm"),
        application: this.$route.query.application || 'boruta_web',
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
        animation: false,
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
        animation: false,
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
        animation: false,
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
  computed: {
    logCount() {
      return this.requestLogs.length
    },
    filteredLogCount() {
      return (this.filteredRequestLogs || this.requestLogs).length
    }
  },
  async mounted() {
    this.getLogs()
  },
  methods: {
    async getLogs() {
      this.stream && this.stream.cancel
      this.resetFilters()
      this.resetGraphs()
      this.requestLogs = []
      this.filteredRequestLogs = []
      this.stream = await Logs.stream(this.requestsFilter)

      this.readLogStream(this.stream)
    },
    resetFilters() {
      this.requestsFiltersData.requestLabels = []
      if (!this.requestsFilter.requestLabel.match(this.requestsFilter.application)) {
        this.requestsFilter.requestLabel = ''
      }
    },
    resetGraphs() {
      this.requestsPerMinute = { labels: [], datasets: [] }
      this.statusCodes = { labels: [], datasets: [] }
      this.requestTimes = { labels: [], datasets: [] }
      this.graphRerenders += 1
    },
    readLogStream(stream) {
      stream.read().then(({ done, value }) => {
        // decode Uint8Array to utf-8 string
        const data = new TextDecoder().decode(value)

        // this.logs += data
        data.split('\n').map(log => {
          if (log.match(REQUEST_REGEX)) {
            this.requestLogs.push(`${log}`)
            this.importRequestLog(log)
          }
        })

        if (done) {
          stream.cancel()
          } else {
          this.readLogStream(stream)
        }
      })
    },
    importRequestLog(log) {
      const requestMatches = log.match(REQUEST_REGEX)
      if (!requestMatches) return
      this.importRequestFilters(requestMatches)

      if (this.isLogApplicationFiltered(requestMatches)) {
        return
      } else {
        this.importRequestLabels(requestMatches)
      }
      if (this.isLogRequestLabelFiltered(requestMatches)) {
        return
      }
      this.filteredRequestLogs.push(log)

      const time = new Date(requestMatches[1])
      time.setMilliseconds(0)
      time.setSeconds(0)
      const application = requestMatches[3]
      const method = requestMatches[4]
      const path = requestMatches[5]
      const statusCode = requestMatches[7]
      const requestTime = parseInt(requestMatches[8])
      const requestTimeUnit = requestMatches[9]

      this.populateRequestsPerMinute({ time, application, method, path })
      this.populateStatusCodes({ statusCode, application, method, path })
      this.populateRequestTimes({ time, requestTime, requestTimeUnit, application, method, path })
    },
    importRequestFilters(requestMatches) {
      if (!requestMatches) return

      const application = requestMatches[3]

      if (!this.requestsFiltersData.applications.includes(application)) {
        this.requestsFiltersData.applications.push(application)
      }
    },
    importRequestLabels(requestMatches) {
      if (!requestMatches) return

      const application = requestMatches[3]
      const method = requestMatches[4]
      const path = requestMatches[5]
      const requestLabel = `${application} - ${method} ${path}`.substring(0, 70)

      if (!this.requestsFiltersData.requestLabels.includes(requestLabel)) {
        this.requestsFiltersData.requestLabels.push(requestLabel)
      }
    },
    isLogApplicationFiltered(requestMatches) {
      if (!requestMatches) return

      const application = requestMatches[3]
      return (this.requestsFilter.application !== application)
    },
    isLogRequestLabelFiltered(requestMatches) {
      if (!requestMatches) return

      const application = requestMatches[3]

      const method = requestMatches[4]
      const path = requestMatches[5]
      const requestLabel = `${application} - ${method} ${path}`.substring(0, 70)
      if (this.requestsFilter.requestLabel === '') {
        return false
      } else {
        return (this.requestsFilter.requestLabel !== requestLabel)
      }

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
      const nextData = new Array()
      for (let i = 0; i < labels.length; i++) {
        nextData.push(currentData[i] || 0)
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
      const nextData = new Array()
      for (let i = 0; i < labels.length; i++) {
        nextData.push(currentData[i] || 0)
      }
      nextData.splice(labels.indexOf(statusCode), 1, nextData[labels.indexOf(statusCode)] + 1)

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
      const nextData = new Array()
      for (let i = 0; i < labels.length; i++) {
        nextData.push(currentData[i] || 0)
      }
      let requestTimeMilliseconds
      if (requestTimeUnit === 'ms') {
        requestTimeMilliseconds = requestTime
      } else if (requestTimeUnit === 'µs') {
        requestTimeMilliseconds = requestTime / 1000
      }
      nextData.splice(-1, 1, nextData.slice(-1)[0] === 0 ? requestTimeMilliseconds : (nextData.slice(-1)[0] + requestTimeMilliseconds) / 2)

      dataset.data = nextData.map(value => value === 0 ? NaN : value)
    },
    filter() {
      this.resetGraphs()
      this.resetFilters()
      this.filteredRequestLogs = []
      this.requestLogs.map(this.importRequestLog.bind(this))
    }
  },
  watch: {
    requestsFilter: {
      handler({ startAt, endAt, application, requestLabel }) {
        const query = { startAt, endAt }

        if (application !== '') query.application = application
        if (requestLabel !== '') query.requestLabel = requestLabel

        this.$router.push({path: this.$route.path, query })
      },
      deep: true
    },
    $route(to, from) {
      if (to.name !== 'request-logs') return

      this.requestsFilter = {
        startAt: to.query.startAt || moment().utc().startOf('day').format("yyyy-MM-DDTHH:mm"),
        endAt: to.query.endAt || moment().utc().endOf('day').format("yyyy-MM-DDTHH:mm"),
        application: to.query.application || 'boruta_web',
        requestLabel: to.query.requestLabel || ''
      }

      if (!(to.query.application === from.query.application &&
        to.query.requestLabel === from.query.requestLabel)) this.filter()
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
  .dates.form {
    button {
      font-size: 1.08rem!important;
    }
  }
  .status-codes {
    display: flex!important;
    align-items: center;
    justify-content: center;
  }
  .log-count {
    display: flex!important;
    align-items: center;
    justify-content: center;
    flex-direction: column;
    .counts {
      padding: 1rem;
      text-align: center;
    }
    label {
      display: block;
      font-size: 1.3rem;
      margin: .5rem;
      span {
        font-weight: bold;
        display: block;
        font-size: 1.5rem;
      }
    }
  }
}
</style>
