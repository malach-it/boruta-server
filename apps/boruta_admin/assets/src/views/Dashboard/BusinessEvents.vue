<template>
  <div class="dashboard">
    <div class="container">
      <div class="ui dates form">
        <div class="ui stackable grid">
          <div class="four wide request-times column">
            <h1>Business events</h1>
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
          </div>
          <div class="six wide filter-form column">
            <h3>Success counts</h3>
            <div class="ui business-event-counts celled list">
              <div class="item" v-for="(count, label) in counts">
                <div class="content">
                  <div class="header">{{ count }}</div>
                  {{ label }}
                </div>
              </div>
            </div>
          </div>
        </div>
        <h3>Log trail</h3>
        <div class="ui logs segment">
          <pre>{{ (businessEventLogs).join('\n') }}</pre>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import moment from 'moment'
import Logs from '../../services/logs.service'

const BUSINESS_REGEX = /(\d{4}-\d{2}-\d{2}T[^\s]+Z) request_id=(\w+) \[info\] (\w+) (\w+) - (\w+)( (\w+)=((\".+\")|([^\s]+)))+/

export default {
  name: 'business-events',
  data() {
    return {
      graphRenders: 0,
      businessEventLogs: [],
      filteredBusinessEventLogs: [],
      requestsFilter: {
        startAt: this.$route.query.startAt || moment().utc().startOf('day').format("yyyy-MM-DDTHH:mm"),
        endAt: this.$route.query.endAt || moment().utc().endOf('day').format("yyyy-MM-DDTHH:mm"),
      },
      counts: {}
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
      this.businessEventLogs = []
      this.filteredBusinessEventLogs = []
      this.resetGraphs()
      this.stream && this.stream.cancel()
      this.stream = await Logs.stream(this.requestsFilter)

      this.readLogStream(this.stream)
    },
    resetGraphs() {
      this.counts = {}
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

      this.filteredBusinessEventLogs.push(log)

      const time = new Date(businessEventMatches[1])
      const domain = businessEventMatches[3]
      const action = businessEventMatches[4]
      const result = businessEventMatches[5]

      this.populateCounts({ domain, action, result })
    },
    populateCounts({ domain, action, result }) {
      if (result !== 'success') return

      const label = `${domain} - ${action}`

      this.counts[label] = this.counts[label] || 0

      this.counts[label] += 1
    }
  },
  watch: {
    requestsFilter: {
      handler({ startAt, endAt }) {
        const query = { startAt, endAt }

        this.$router.push({path: this.$route.path, query });
      },
      deep: true
    },
    $route: {
      handler(route) {
        if (to.name !== 'business-event-logs') return

        this.requestsFilter = {
          startAt: route.query.startAt || moment().utc().startOf('day').format("yyyy-MM-DDTHH:mm"),
          endAt: route.query.endAt || moment().utc().endOf('day').format("yyyy-MM-DDTHH:mm")
        }
      },
      deep: true
    }
  }
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
    font-size: 1.1em;
    .header {
      float: right;
    }
  }
}
</style>
