<template>
  <div class="dashboard">
    <div class="container">
      <div class="ui error message" v-if="error">
        {{ error }}
      </div>
      <div class="ui dates form">
        <div class="ui stackable grid">
          <div class="four wide request-times column">
            <h1>Business events</h1>
          </div>
          <div class="five wide request-times column">
            <input type="datetime-local" v-model="dateFilter.startAt" :disabled="pending" />
          </div>
          <div class="five wide request-times column">
            <input type="datetime-local" v-model="dateFilter.endAt" :disabled="pending" />
          </div>
          <div class="two wide request-times column">
            <button class="ui fluid blue button" @click="getLogs()" :disabled="pending">Filter</button>
          </div>
        </div>
      </div>
      <div class="ui segment">
        <div class="ui requests form">
          <div class="ui stackable grid">
            <div class="ten wide filter-form column">
              <div class="field">
                <label>Application</label>
                <select @change="getLogs()" v-model="businessEventFilter.application" :disabled="pending">
                  <option :value="application" v-for="application in businessEventFiltersData.applications">{{ application }}</option>
                </select>
              </div>
              <div class="field">
                <label>Domain</label>
                <select @change="getLogs()" v-model="businessEventFilter.domain" :disabled="pending">
                  <option value=''>All domains</option>
                  <option :value="domain" v-for="domain in businessEventFiltersData.domains">{{ domain }}</option>
                </select>
              </div>
              <div class="field">
                <label>Action</label>
                <select @change="getLogs()" v-model="businessEventFilter.action" :disabled="pending">
                  <option value=''>All actions</option>
                  <option :value="action" v-for="action in businessEventFiltersData.actions">{{ action }}</option>
                </select>
              </div>
            </div>
            <div class="six wide log-count column">
              <div class="counts">
                <label>Log count <span>{{ logCount }}</span></label>
              </div>
            </div>
          </div>
        </div>
        <div class="ui stackable grid">
          <div class="ten wide filter-form column">
            <LineChart :chartData="businessEventCounts" :options="businessEventCountsOptions" height="500" :key="graphRerenders" />
          </div>
          <div class="six wide filter-form column">
            <div class="ui business-event-counts celled list">
              <div class="item" v-for="(count, label) in counts" :key="label">
                <div class="content">
                  <div class="header">
                    <span class="success">{{ count.success }}</span>
                    <span class="failure">{{ count.failure }}</span>
                  </div>
                  <span class="count">{{ label }}</span>
                </div>
              </div>
            </div>
          </div>
          <div v-if="businessEventFilter.application == 'boruta_gateway'" class="sixteen wide filter-form column">
            <LineChart :chartData="gatewayTimes" :options="gatewayTimesOptions" height="500" :key="graphRerenders" />
          </div>
        </div>

        <h3>Log trail</h3>
        <div class="ui error message" v-if="overflow">
          This interface is limited to read at most {{ maxLogLines }} log lines, later log lines are skipped.
        </div>
        <div class="ui logs segment">
          <pre>{{ businessEventLogs.join('\n') }}</pre>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { uniq } from 'lodash'
import moment from 'moment'
import { LineChart } from "vue-chart-3"
import { Chart, registerables } from 'chart.js'
import BusinessLogStats from '../../models/business-log-stats.model.js'
import 'chartjs-adapter-moment'

Chart.register(...registerables)

const MAX_LOG_LINES = 10000 // from backend limit

export default {
  name: 'business-events',
  components: {
    LineChart
  },
  data() {
    const requestDataset = {
       label: 'request time',
       borderColor: stringToColor('request time'),
       backgroundColor: stringToColor('request time'),
       fill: false,
       linetension: 0,
       data: [],
       tmp: {}
    }
    const upstreamDataset = {
       label: 'upstream time',
       borderColor: stringToColor('upstream time'),
       backgroundColor: stringToColor('upstream time'),
       fill: false,
       linetension: 0,
       data: [],
       tmp: []
    }
    const gatewayDataset = {
       label: 'gateway time',
       borderColor: stringToColor('gateway time'),
       backgroundColor: stringToColor('gateway time'),
       fill: false,
       linetension: 0,
       data: [],
       tmp: []
    }

    return {
      overflow: false,
      pending: false,
      error: false,
      maxLogLines: MAX_LOG_LINES,
      timeScaleUnit: '',
      businessEventLogs: [],
      logCount: 0,
      graphRerenders: 0,
      businessEventFiltersData: {
        applications: ['boruta_web', 'boruta_identity', 'boruta_gateway'],
        domains: [],
        actions: []
      },
      dateFilter: {
        startAt: this.$route.query.startAt || moment().utc().startOf('hour').format("yyyy-MM-DDTHH:mm"),
        endAt: this.$route.query.endAt || moment().utc().endOf('hour').format("yyyy-MM-DDTHH:mm")
      },
      businessEventFilter: {
        application: this.$route.query.application || 'boruta_web',
        domain: this.$route.query.domain || '',
        action: this.$route.query.action || ''
      },
      counts: {},
      businessEventCounts: {
        labels: [],
        datasets: []
      },
      gatewayTimes: {
        labels: [],
        datasets: [requestDataset, upstreamDataset, gatewayDataset]
      }
    }
  },
  computed: {
    businessEventCountsOptions() {
      return {
        animation: false,
        plugins: {
          title: {
            display: true,
            text: `Business event counts per ${this.timeScaleUnit}`
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
    },
    gatewayTimesOptions() {
      return {
        animation: false,
        plugins: {
          title: {
            display: true,
            text: `Gateway times per ${this.timeScaleUnit}`
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
    this.overflow = false
    this.resetGraphs()
    this.resetFilters()
    this.getLogStats()
    this.render()
  },
  methods: {
    getLogs() {
      this.applyFilters()
    },
    applyFilters() {
      const query = {
        ...this.$route.query,
        ...this.dateFilter,
        ...this.businessEventFilter
      }

      this.$router.push({ path: this.$route.path, query })
    },
    resetGraphs() {
      const requestDataset = {
         label: 'request time',
         borderColor: stringToColor('request time'),
         backgroundColor: stringToColor('request time'),
         fill: false,
         linetension: 0,
         data: [],
         tmp: {}
      }
      const upstreamDataset = {
         label: 'upstream time',
         borderColor: stringToColor('upstream time'),
         backgroundColor: stringToColor('upstream time'),
         fill: false,
         linetension: 0,
         data: [],
         tmp: []
      }
      const gatewayDataset = {
         label: 'gateway time',
         borderColor: stringToColor('gateway time'),
         backgroundColor: stringToColor('gateway time'),
         fill: false,
         linetension: 0,
         data: [],
         tmp: []
      }

      this.counts = {}
      this.businessEventCounts = {
        labels: [],
        datasets: []
      }
      this.gatewayTimes = {
        labels: [],
        datasets: [requestDataset, upstreamDataset, gatewayDataset]
      }
    },
    resetFilters() {
      this.businessEventFiltersData.actions = []
      this.businessEventFiltersData.domains = []
      if (!this.businessEventFilter.domain.match(this.businessEventFilter.application)) {
        this.businessEventFilter.domain = ''
      }
      if (!this.businessEventFilter.action.match(this.businessEventFilter.application) ||
        !this.businessEventFilter.action.match(this.businessEventFilter.domain)) {
        this.businessEventFilter.action = ''
      }
    },
    getLogStats() {
      this.pending = true
      this.error = false
      BusinessLogStats.all({
        ...this.businessEventFilter,
        ...this.dateFilter
      }).then(({
        time_scale_unit,
        overflow,
        log_lines,
        log_count,
        counts,
        business_event_counts,
        domains,
        actions
      }) => {
        this.timeScaleUnit = time_scale_unit
        this.overflow = overflow
        this.businessEventLogs = log_lines
        this.logCount = log_count
        this.populateCounts(counts)
        this.populateBusinessEventCounts(business_event_counts)
        this.populateGatewayTimes(log_lines)
        this.businessEventFiltersData.domains = domains
        this.businessEventFiltersData.actions = actions
        this.pending = false
      }).catch(error => this.error = error.message)
    },
    render() {
      this.graphRerenders += 1
    },
    populateCounts(stats) {
      Object.keys(stats).forEach(currentLabel => {
        this.counts[currentLabel] = this.counts[currentLabel] || {}

        Object.keys(stats[currentLabel]).forEach(result => {
          this.counts[currentLabel][result] = stats[currentLabel][result]
        })
      })
    },
    populateBusinessEventCounts(stats) {
      Object.keys(stats).forEach(currentLabel => {
        const labels = uniq(Object.values(stats).flatMap(Object.keys)).sort()
        this.businessEventCounts.labels = labels

        let dataset = this.businessEventCounts.datasets.find(({ label }) => {
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
          this.businessEventCounts.datasets.push(dataset)
        }

        Object.keys(stats[currentLabel]).map(timestamp => {
          dataset.data[labels.indexOf(timestamp)] = stats[currentLabel][timestamp]
        })

        this.businessEventCounts.datasets.forEach(dataset => {
          dataset.data = dataset.data.map(value => value === 0 ? NaN : value)
        })
      })
    },
    populateGatewayTimes(logLines) {
      logLines.forEach(line => {
        if (!(line.match(/boruta_gateway/))) return
        if (!(line.match(/success/))) return

        let unitFactor
        if (this.timeScaleUnit == 'second') {
          unitFactor = 1000
        } else if (this.timeScaleUnit == 'minute') {
          unitFactor = 1000 * 60
        } else if (this.timeScaleUnit == 'hour') {
          unitFactor = 1000 * 60 * 60
        }
        const timestamp = new Date(Math.floor(Date.parse(line.split(' ')[0]).valueOf() / unitFactor) * unitFactor).toString()

        const rawAttributes = line.split(' - ')[1].split(' ')
        const rawRequestTime = rawAttributes.find(rawAttribute => {
          return rawAttribute.match(/request_time/)
        })
        const requestTime = rawRequestTime && rawRequestTime.match(/\d+/)[0]

        const rawGatewayTime = rawAttributes.find(rawAttribute => {
          return rawAttribute.match(/gateway_time/)
        })
        const gatewayTime = rawGatewayTime && rawGatewayTime.match(/\d+/)[0]

        const rawUpstreamTime = rawAttributes.find(rawAttribute => {
          return rawAttribute.match(/upstream_time/)
        })
        const upstreamTime = rawUpstreamTime && rawUpstreamTime.match(/\d+/)[0]

        const labels = ['Request time', 'Gateway time', 'Upstream time']

        const requestDataset = this.gatewayTimes.datasets[0]
        const upstreamDataset = this.gatewayTimes.datasets[1]
        const gatewayDataset = this.gatewayTimes.datasets[2]

        if (requestDataset.tmp[timestamp]) {
          const lastRequestTime = requestDataset.tmp[timestamp]
          requestDataset.tmp[timestamp] = (lastRequestTime + parseInt(requestTime) / 1000) / 2
        } else {
          requestDataset.tmp[timestamp] = parseInt(requestTime) / 1000
        }
        this.gatewayTimes.labels = Object.keys(requestDataset.tmp)
        requestDataset.data = Object.values(requestDataset.tmp)

        if (gatewayDataset.tmp[timestamp]) {
          const lastGatewayTime = gatewayDataset.tmp[timestamp]
          gatewayDataset.tmp[timestamp] = (lastGatewayTime + parseInt(gatewayTime) / 1000) / 2
        } else {
          gatewayDataset.tmp[timestamp] = parseInt(gatewayTime) / 1000
        }
        gatewayDataset.data = Object.values(gatewayDataset.tmp)

        if (upstreamDataset.tmp[timestamp]) {
          const lastUpstreamTime = upstreamDataset.tmp[timestamp]
          upstreamDataset.tmp[timestamp] = (lastUpstreamTime + parseInt(upstreamTime) / 1000) / 2
        } else {
          upstreamDataset.tmp[timestamp] = parseInt(upstreamTime) / 1000
        }
        upstreamDataset.data = Object.values(upstreamDataset.tmp)
      })
    },
  },
  watch: {
    $route(to, from) {
      if (to.name !== 'business-event-logs') return

      this.dateFilter = {
        startAt: to.query.startAt || moment().utc().startOf('hour').format("yyyy-MM-DDTHH:mm"),
        endAt: to.query.endAt || moment().utc().endOf('hour').format("yyyy-MM-DDTHH:mm")
      }

      this.businessEventFilter = {
        application: to.query.application || 'boruta_web',
        domain: to.query.domain || '',
        action: to.query.action || '',
      }

      this.overflow = false
      this.resetGraphs()
      this.resetFilters()
      this.getLogStats()
      this.render()
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
  .dates.form {
    margin-bottom: 1em;
  }
  .logs.segment {
    overflow: hidden;
    overflow-x: scroll;
    overflow-y: scroll;
    max-height: 30vh;
    pre {
      overflow: visible !important;
    }
  }
  .dates.form {
    button {
      font-size: 1.08rem!important;
    }
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
  .business-event-counts.list {
    font-size: 1.2em;
    .header {
      float: right;
      span {
        margin-right: .5em;
        &.success {
          color: green;
        }
        &.failure {
          color: red;
        }
      }
    }
  }
}
</style>
