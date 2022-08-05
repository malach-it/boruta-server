<template>
  <div class="dashboard">
    <div class="container">
      <div class="ui dates form">
        <div class="ui stackable grid">
          <div class="four wide request-times column">
            <h1>Requests</h1>
          </div>
          <div class="five wide request-times column">
            <input type="datetime-local" v-model="requestsFilter.startAt" :disabled="pending" />
          </div>
          <div class="five wide request-times column">
            <input type="datetime-local" v-model="requestsFilter.endAt" :disabled="pending" />
          </div>
          <div class="two wide request-times column">
            <button class="ui fluid blue button" @click="getLogs()" :disabled="pending">Filter</button>
          </div>
        </div>
      </div>
      <div class="ui error message" v-if="fetchError">
        An error has occured when fetching logs, message: {{ fetchError }}.
      </div>
      <div class="ui error message" v-if="overflow">
        This interface is limited to read at most {{ maxLogLines }} log lines, earlier logs are skipped.
      </div>
      <div class="ui segment">
        <div class="ui requests form">
          <div class="ui stackable grid">
            <div class="ten wide filter-form column">
              <div class="field">
                <label>Application</label>
                <select @change="filter()" v-model="requestsFilter.application" :disabled="pending">
                  <option :value="application" v-for="application in requestsFiltersData.applications">{{ application }}</option>
                </select>
              </div>
              <div class="field">
                <label>Request label</label>
                <select @change="filter()" v-model="requestsFilter.requestLabel" :disabled="pending">
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
            <LineChart :chartData="requestCounts" :options="requestCountsOptions" height="500" :key="graphRerenders" />
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
import { cloneDeep, uniq } from 'lodash'
import { LineChart, PieChart } from "vue-chart-3"
import { Chart, registerables } from 'chart.js'
import moment from 'moment'
import 'chartjs-adapter-moment'
import LogStats from '../../models/log-stats.model'

Chart.register(...registerables)

const MAX_LOG_LINES = 10000 // from backend limit

export default {
  name: 'requests',
  components: {
    LineChart,
    PieChart
  },
  data() {
    return {
      overflow: false,
      pending: false,
      maxLogLines: MAX_LOG_LINES,
      timeScaleUnit: '',
      requestLogs: [],
      filteredRequestLogs: [],
      logCount: 0,
      graphRerenders: 0,
      requestsFiltersData: {
        applications: [],
        requestLabels: []
      },
      requestsFilter: {
        startAt: this.$route.query.startAt || moment().utc().startOf('hour').format("yyyy-MM-DDTHH:mm"),
        endAt: this.$route.query.endAt || moment().utc().endOf('hour').format("yyyy-MM-DDTHH:mm"),
        application: this.$route.query.application || 'boruta_web',
        requestLabel: this.$route.query.requestLabel || ''
      },
      statusCodes: {
        labels: [],
        datasets: []
      },
      requestTimes: {
        labels: [],
        datasets: []
      },
      requestCounts: {
        labels: [],
        datasets: []
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
    filteredLogCount() {
      return (this.filteredRequestLogs || this.requestLogs).length
    },
    requestCountsOptions() {
      return {
        animation: false,
        plugins: {
          title: {
            display: true,
            text: `Requests count per ${this.timeScaleUnit}`
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
    this.getLogs()
  },
  methods: {
    async getLogs() {
      this.pending = true
      this.overflow = false
      this.resetGraphs()
      this.resetFilters()

      this.getLogStats()
      this.render()
    },
    resetFilters() {
      this.requestsFiltersData.requestLabels = []
      if (!this.requestsFilter.requestLabel.match(this.requestsFilter.application)) {
        this.requestsFilter.requestLabel = ''
      }
    },
    resetGraphs() {
      this.requestCounts = { labels: [], datasets: [] }
      this.statusCodes = { labels: [], datasets: [] }
      this.requestTimes = { labels: [], datasets: [] }
    },
    render() {
      this.graphRerenders += 1
    },
    getLogStats() {
      LogStats.all(this.requestsFilter).then(({
        time_scale_unit,
        overflow,
        log_lines,
        log_count,
        request_counts,
        status_codes,
        request_times
      }) => {
        this.timeScaleUnit = time_scale_unit
        this.overflow = overflow
        this.requestLogs = log_lines
        this.filteredRequestLogs = log_lines
        // TODO filter
        this.logCount = log_count
        this.populateRequestCounts(request_counts)
        this.populateStatusCodes(status_codes)
        this.populateRequestTimes(request_times)
        this.pending = false
      })
    },
    // importRequestLog(log) {
    //   const requestMatches = log.match(REQUEST_REGEX)
    //   if (!requestMatches) return
    //   this.importRequestFilters(requestMatches)

    //   if (this.isLogApplicationFiltered(requestMatches)) {
    //     return
    //   } else {
    //     this.importRequestLabels(requestMatches)
    //   }
    //   if (this.isLogRequestLabelFiltered(requestMatches)) {
    //     return
    //   }
    //   filteredRequestLogs.push(log)

    //   const time = new Date(requestMatches[1])
    //   time.setMilliseconds(0)
    //   time.setSeconds(0)
    //   if (this.isHourScale) time.setMinutes(0)
    //   const application = requestMatches[3]
    //   const method = requestMatches[4]
    //   const path = requestMatches[5]
    //   const statusCode = requestMatches[7]
    //   const requestTime = parseInt(requestMatches[8])
    //   const requestTimeUnit = requestMatches[9]

    //   this.populateRequestsCount({ time, application, method, path })
    //   this.populateStatusCodes({ statusCode, application, method, path })
    //   this.populateRequestTimes({ time, requestTime, requestTimeUnit, application, method, path })
    // },
    // importRequestFilters(requestMatches) {
    //   if (!requestMatches) return

    //   const application = requestMatches[3]

    //   if (!this.requestsFiltersData.applications.includes(application)) {
    //     this.requestsFiltersData.applications.push(application)
    //     this.requestsFiltersData.applications.sort()
    //   }
    // },
    // importRequestLabels(requestMatches) {
    //   if (!requestMatches) return

    //   const application = requestMatches[3]
    //   const method = requestMatches[4]
    //   const path = requestMatches[5]
    //   const requestLabel = `${application} - ${method} ${path}`.substring(0, 70)

    //   if (!this.requestsFiltersData.requestLabels.includes(requestLabel)) {
    //     this.requestsFiltersData.requestLabels.push(requestLabel)
    //     this.requestsFiltersData.requestLabels.sort()
    //   }
    // },
    // isLogApplicationFiltered(requestMatches) {
    //   if (!requestMatches) return

    //   const application = requestMatches[3]
    //   return (this.requestsFilter.application !== application)
    // },
    // isLogRequestLabelFiltered(requestMatches) {
    //   if (!requestMatches) return

    //   const application = requestMatches[3]

    //   const method = requestMatches[4]
    //   const path = requestMatches[5]
    //   const requestLabel = `${application} - ${method} ${path}`.substring(0, 70)
    //   if (this.requestsFilter.requestLabel === '') {
    //     return false
    //   } else {
    //     return (this.requestsFilter.requestLabel !== requestLabel)
    //   }

    // },
    populateRequestCounts(stats) {
      Object.keys(stats).forEach(currentLabel => {
        const labels = uniq(Object.values(stats).flatMap(Object.keys)).sort()
        this.requestCounts.labels = labels

        let dataset = this.requestCounts.datasets.find(({ label }) => {
          return label === currentLabel
        })
        if (!dataset) {
          dataset = {
            label: currentLabel,
            borderColor: stringToColor(currentLabel),
            backgroundColor: stringToColor(currentLabel),
            fill: false,
            lineTension: 0,
            data: []
          }
          this.requestCounts.datasets.push(dataset)
        }

        Object.keys(stats[currentLabel]).map(timestamp => {
          dataset.data[labels.indexOf(timestamp)] = stats[currentLabel][timestamp]
        })

        this.requestCounts.datasets.forEach(dataset => {
          dataset.data = dataset.data.map(value => value === 0 ? NaN : value)
        })
      })
    },
    populateStatusCodes(stats) {
      const labels = uniq(Object.values(stats).flatMap(Object.keys))
      this.statusCodes.labels = labels

      Object.keys(stats).forEach(currentLabel => {
        let dataset = this.statusCodes.datasets.find(({ label }) => {
          return label === currentLabel
        })
        if (!dataset) {
          dataset = {
            label: currentLabel,
            backgroundColor: stringToColor(currentLabel),
            data: []
          }
          this.statusCodes.datasets.push(dataset)
        }

        Object.keys(stats[currentLabel]).map(statusCode => {
          dataset.data[labels.indexOf(statusCode)] = stats[currentLabel][statusCode]
        })

        dataset.data = dataset.data.map(value => value === 0 ? NaN : value)
      })
    },
    populateRequestTimes(stats) {
      Object.keys(stats).forEach(currentLabel => {
        const labels = uniq(Object.values(stats).flatMap(Object.keys)).sort()
        this.requestTimes.labels = labels

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
            data: []
          }
          this.requestTimes.datasets.push(dataset)
        }

        Object.keys(stats[currentLabel]).map(timestamp => {
          dataset.data[labels.indexOf(timestamp)] = stats[currentLabel][timestamp]
        })

        this.requestTimes.datasets.forEach(dataset => {
          dataset.data = dataset.data.map(value => value === 0 ? NaN : value)
        })
      })
    },
    filter() {
      this.resetGraphs()
      this.resetFilters()
      this.filteredRequestLogs.splice(0, 0)
      this.requestLogs.map(this.importRequestLog.bind(this))
      this.render()
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
        startAt: to.query.startAt || moment().utc().startOf('hour').format("yyyy-MM-DDTHH:mm"),
        endAt: to.query.endAt || moment().utc().endOf('hour').format("yyyy-MM-DDTHH:mm"),
        application: to.query.application || 'boruta_web',
        requestLabel: to.query.requestLabel || ''
      }

      if (!(to.query.application === from.query.application &&
        to.query.requestLabel === from.query.requestLabel)) this.filter()
    }
  },
  beforeRouteLeave() {
    this.resetGraphs()
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
