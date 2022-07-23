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
            <button class="ui fluid blue button">Filter</button>
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
      businessEventLogs: [],
      requestsFilter: {
        startAt: this.$route.query.startAt || moment().startOf('day').format("yyyy-MM-DDTHH:mm"),
        endAt: this.$route.query.endAt || moment().endOf('day').format("yyyy-MM-DDTHH:mm"),
      }
    }
  },
  computed: {
    logCount() {
      return this.businessEventLogs.length
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
          if (log.match(BUSINESS_REGEX)) this.businessEventLogs.push(`${log}`)
        })

        if (done) {
          stream.cancel()
          } else {
          read(stream)
        }
      })
    }

    read(stream)
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
        this.requestsFilter = {
          startAt: route.query.startAt || moment().startOf('day').format("yyyy-MM-DDTHH:mm"),
          endAt: route.query.endAt || moment().endOf('day').format("yyyy-MM-DDTHH:mm")
        }
        // this.filter()
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
}
</style>
