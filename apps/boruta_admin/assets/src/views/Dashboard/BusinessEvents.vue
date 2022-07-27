<template>
  <div class="dashboard">
    <div class="container">
      <div class="ui dates form">
        <div class="ui stackable grid">
          <div class="four wide request-times column">
            <h1>Business events</h1>
          </div>
          <div class="five wide request-times column">
            <input type="datetime-local" v-model="businessEventFilter.startAt" />
          </div>
          <div class="five wide request-times column">
            <input type="datetime-local" v-model="businessEventFilter.endAt" />
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
                <label>Domain</label>
                <select @change="filter()" v-model="businessEventFilter.domain">
                  <option value=''>All domains</option>
                  <option :value="domain" v-for="domain in businessEventFiltersData.domains">{{ domain }}</option>
                </select>
              </div>
              <div class="field">
                <label>Action</label>
                <select @change="filter()" v-model="businessEventFilter.action">
                  <option value=''>All actions</option>
                  <option :value="action" v-for="action in businessEventFiltersData.actions">{{ action }}</option>
                </select>
              </div>
            </div>
            <div class="six wide log-count column">
              <div class="counts">
                <label>Log count <span>{{ logCount }}</span></label>
                <label>Filtered log count <span>{{ filteredLogCount }}</span></label>
              </div>
            </div>
          </div>
        </div>
        <div class="ui stackable grid">
          <div class="ten wide filter-form column">
            <LineChart :chartData="businessEventCountsPerMinute" :options="businessEventCountsPerMinuteOptions" height="500" :key="graphRerenders" />
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
          <pre>{{ (filteredBusinessEventLogs || businessEventLogs).join('\n') }}</pre>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import moment from 'moment'
import { LineChart } from "vue-chart-3"
import { Chart, registerables } from 'chart.js'
import Logs from '../../services/logs.service'

Chart.register(...registerables)

const BUSINESS_REGEX = /(\d{4}-\d{2}-\d{2}T[^\s]+Z) request_id=(\w+) \[info\] (\w+) (\w+) - (\w+)( (\w+)=((\".+\")|([^\s]+)))+/

export default {
  name: 'business-events',
  components: {
    LineChart
  },
  data() {
    return {
      graphRenders: 0,
      businessEventLogs: [],
      filteredBusinessEventLogs: [],
      businessEventFiltersData: {
        domains: [],
        actions: []
      },
      businessEventFilter: {
        startAt: this.$route.query.startAt || moment().utc().startOf('day').format("yyyy-MM-DDTHH:mm"),
        endAt: this.$route.query.endAt || moment().utc().endOf('day').format("yyyy-MM-DDTHH:mm"),
        domain: this.$route.query.domain || '',
        action: this.$route.query.action || ''
      },
      counts: {},
      businessEventCountsPerMinute: {
        labels: [],
        datasets: []
      },
      businessEventCountsPerMinuteOptions: {
        animation: false,
        plugins: {
          title: {
            display: true,
            text: 'Business event counts per minute'
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
    }
  },
  computed: {
    logCount() {
      return this.businessEventLogs.length
    },
    filteredLogCount() {
      return (this.filteredBusinessEventLogs || this.businessEventLogs).length
    }
  },
  async mounted() {
    this.getLogs()
  },
  methods: {
    async getLogs() {
      this.stream && this.stream.cancel()
      this.resetFilters()
      this.resetGraphs()
      this.businessEventLogs = []
      this.filteredBusinessEventLogs = []
      this.stream = await Logs.stream(this.businessEventFilter)

      this.readLogStream(this.stream)
    },
    resetFilters() {
      this.businessEventFiltersData.actions = []
      if (!this.businessEventFilter.action.match(this.businessEventFilter.domain)) {
        this.businessEventFilter.action = ''
      }
    },
    resetGraphs() {
      this.counts = {}
      this.businessEventCountsPerMinute = {
        labels: [],
        datasets: []
      }
      this.graphRerenders += 1
    },
    readLogStream(stream) {
      stream.read().then(({ done, value }) => {
        // decode Uint8Array to utf-8 string
        const data = new TextDecoder().decode(value)

        // this.logs += data
        data.split('\n').map(log => {
          if (log.match(BUSINESS_REGEX)) {
            this.businessEventLogs.push(`${log}`)
            this.importBusinessEventLog(log)
          }
        })

        if (done) {
          stream.cancel()
          } else {
          this.readLogStream(stream)
        }
      })
    },
    importBusinessEventLog(log) {
      const businessEventMatches = log.match(BUSINESS_REGEX)
      if (!businessEventMatches) return

      this.importBusinessEventFilters(businessEventMatches)

      if (this.isLogDomainFiltered(businessEventMatches)) {
        return
      } else {
        this.importActions(businessEventMatches)
      }

      if (this.isLogActionFiltered(businessEventMatches)) {
        return
      }

      this.filteredBusinessEventLogs.push(log)

      const time = new Date(businessEventMatches[1])
      time.setMilliseconds(0)
      time.setSeconds(0)
      const domain = businessEventMatches[3]
      const action = businessEventMatches[4]
      const result = businessEventMatches[5]

      this.populateCounts({ domain, action, result })
      this.populateBusinessEventCountsPerMinute({ time, domain, action })
    },
    importBusinessEventFilters(businessEventMatches) {
      if (!businessEventMatches) return

      const domain = businessEventMatches[3]

      if (!this.businessEventFiltersData.domains.includes(domain)) {
        this.businessEventFiltersData.domains.push(domain)
        this.businessEventFiltersData.domains.sort()
      }
    },
    importActions(businessEventMatches) {
      if (!businessEventMatches) return

      const domain = businessEventMatches[3]
      const action = businessEventMatches[4]

      const label = `${domain} - ${action}`

      if (!this.businessEventFiltersData.actions.includes(label)) {
        this.businessEventFiltersData.actions.push(label)
        this.businessEventFiltersData.actions.sort()
      }
    },
    isLogDomainFiltered(businessEventMatches) {
      if (!businessEventMatches) return

      const domain = businessEventMatches[3]
      if (this.businessEventFilter.domain === '') {
        return false
      }
      return (this.businessEventFilter.domain !== domain)
    },
    isLogActionFiltered(businessEventMatches) {
      if (!businessEventMatches) return

      const domain = businessEventMatches[3]
      const action = businessEventMatches[4]

      const label = `${domain} - ${action}`

      if (this.businessEventFilter.action === '') {
        return false
      }
      return (this.businessEventFilter.action !== label)
    },
    populateCounts({ domain, action, result }) {
      const label = `${domain} - ${action}`

      this.counts[label] = this.counts[label] || {}
      this.counts[label][result] = this.counts[label][result] || 0

      this.counts[label][result] += 1
    },
    populateBusinessEventCountsPerMinute({ time, domain, action }) {
      const currentLabel = `${domain} - ${action}`

      const labels = this.businessEventCountsPerMinute.labels
      const lastLabel = labels.slice(-1)[0]
      if (!lastLabel || !(lastLabel.getTime() == time.getTime())) {
        labels.push(time)
      }

      let dataset = this.businessEventCountsPerMinute.datasets.find(({ label }) => {
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
        this.businessEventCountsPerMinute.datasets.push(dataset)
      }

      const currentData = dataset.data || new Array()
      const nextData = new Array()
      for (let i = 0; i < labels.length; i++) {
        nextData.push(currentData[i] || 0)
      }
      nextData.splice(-1, 1, nextData.slice(-1)[0] + 1)

      dataset.data = nextData.map(value => value === 0 ? NaN : value)
    },
    filter() {
      this.resetGraphs()
      this.resetFilters()
      this.filteredBusinessEventLogs = []
      this.businessEventLogs.map(this.importBusinessEventLog.bind(this))
    },
  },
  watch: {
    businessEventFilter: {
      handler({ startAt, endAt, domain, action }) {
        const query = { startAt, endAt }

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
        domain: to.query.domain || '',
        action: to.query.action || ''
      }

      if (!(to.query.domain === from.query.domain &&
        to.query.action === from.query.action)) this.filter()
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
