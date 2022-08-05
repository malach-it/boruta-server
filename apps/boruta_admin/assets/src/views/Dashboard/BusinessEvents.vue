<template>
  <div class="dashboard">
    <div class="container">
      <div class="ui dates form">
        <div class="ui stackable grid">
          <div class="four wide request-times column">
            <h1>Business events</h1>
          </div>
          <div class="five wide request-times column">
            <input type="datetime-local" v-model="businessEventFilter.startAt" :disabled="pending" />
          </div>
          <div class="five wide request-times column">
            <input type="datetime-local" v-model="businessEventFilter.endAt" :disabled="pending" />
          </div>
          <div class="two wide request-times column">
            <button class="ui fluid blue button" @click="getLogs()" :disabled="pending">Filter</button>
          </div>
        </div>
      </div>
      <div class="ui error message" v-if="overflow">
        This interface is limited to read at most {{ maxLogLines }} log lines, earlier logs are skipped
      </div>
      <div class="ui segment">
        <div class="ui requests form">
          <div class="ui stackable grid">
            <div class="ten wide filter-form column">
              <div class="field">
                <label>Application</label>
                <select v-model="businessEventFilter.application" :disabled="pending">
                  <option :value="application" v-for="application in businessEventFiltersData.applications">{{ application }}</option>
                </select>
              </div>
              <div class="field">
                <label>Domain</label>
                <select v-model="businessEventFilter.domain" :disabled="pending">
                  <option value=''>All domains</option>
                  <option :value="domain" v-for="domain in businessEventFiltersData.domains">{{ domain }}</option>
                </select>
              </div>
              <div class="field">
                <label>Action</label>
                <select v-model="businessEventFilter.action" :disabled="pending">
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
        </div>
        <h3>Log trail</h3>
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
    return {
      overflow: false,
      pending: false,
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
      businessEventFilter: {
        startAt: this.$route.query.startAt || moment().utc().startOf('hour').format("yyyy-MM-DDTHH:mm"),
        endAt: this.$route.query.endAt || moment().utc().endOf('hour').format("yyyy-MM-DDTHH:mm"),
        application: this.$route.query.application || 'boruta_web',
        domain: this.$route.query.domain || '',
        action: this.$route.query.action || ''
      },
      counts: {},
      businessEventCounts: {
        labels: [],
        datasets: []
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
    resetGraphs() {
      this.counts = {}
      this.businessEventCounts = {
        labels: [],
        datasets: []
      }
    },
    resetFilters() {
      this.businessEventFiltersData.actions = []
      if (!this.businessEventFilter.action.match(this.businessEventFilter.domain)) {
        this.businessEventFilter.action = ''
      }
    },
    getLogStats() {
      BusinessLogStats.all(this.businessEventFilter).then(({
        time_scale_unit,
        overflow,
        log_lines,
        log_count,
        counts,
        business_event_counts
      }) => {
        this.timeScaleUnit = time_scale_unit
        this.overflow = overflow
        this.businessEventLogs = log_lines
        this.logCount = log_count
        this.populateCounts(counts)
        this.populateBusinessEventCounts(business_event_counts)
        this.pending = false
      })
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
  },
  watch: {
    businessEventFilter: {
      handler({ startAt, endAt, application, domain, action }) {
        const query = { startAt, endAt, application }

        if (domain !== '') query.domain = domain
        if (action !== '') query.action = action

        this.$router.push({path: this.$route.path, query });
      },
      deep: true
    },
    $route(to, from) {
      if (to.name !== 'business-event-logs') return

      this.businessEventFilter = {
        startAt: to.query.startAt || moment().utc().startOf('day').format("yyyy-MM-DDTHH:mm"),
        endAt: to.query.endAt || moment().utc().endOf('day').format("yyyy-MM-DDTHH:mm"),
        application: to.query.application || 'boruta_web',
        domain: to.query.domain || '',
        action: to.query.action || ''
      }

      this.getLogs()
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
