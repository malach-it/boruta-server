<template>
  <div class="dashboard">
    <div class="container">
      <h2>Request logs</h2>
      <div class="ui logs segment">
        <pre>{{ requestLogs.join('\n') }}</pre>
      </div>
      <div class="ui one column stackable grid">
        <div class="column request-time">
          <LineChart :chartData="requestTimes" :options="requestTimesOptions" height="500" />
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
import { LineChart } from "vue-chart-3";
import Logs from '../services/logs.service'
import GatewayRequests from '../components/GatewayRequests.vue'

const REQUEST_REGEX = /(\d{4}-\d{2}-\d{2}T[^\s]+Z) request_id=(\w+) \[info\] (\w+) (\w+) ([^\s]+) - (\w+) (\d{3}) in (\d+)(\w{2})/
const BUSINESS_REGEX = /(\d{4}-\d{2}-\d{2}T[^\s]+Z) request_id=(\w+) \[info\] (\w+) (\w+) - (\w+)( (\w+)=((\".+\")|([^\s]+)))+/

export default {
  name: 'home',
  components: {
    LineChart
  },
  data() {
    return {
      // logs: '',
      requestLogs: [],
      businessLogs: '',
      requestTimes: {
        labels: [],
        datasets: []
      },
      requestTimesOptions: {
        plugins: {
          title: {
            display: true,
            text: 'Requests per minute'
          }
        },
        scales: {
          xAxis: {
            display: false
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
          const requestMatches = log.match(REQUEST_REGEX)
          if (requestMatches) {
            this.requestLogs.push(`${log}`)
            const time = new Date(requestMatches[1])
            time.setMilliseconds(0)
            time.setSeconds(0)
            const application = requestMatches[3]
            if (application == 'boruta_admin') return
            const method = requestMatches[4]
            const path = requestMatches[5]

            const currentLabel = `${application} - ${method} ${path}`

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
            nextData.splice(-1, 1, nextData.slice(-1)[0] + 1)

            dataset.data = nextData.map(value => value === 0 ? NaN : value)
          }
          if (log.match(BUSINESS_REGEX)) this.businessLogs += `${log}\n`
        })

        if (done) {
          stream.cancel()
          } else {
          read(stream)
        }
      })
    }

    read(stream)
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
}
</style>
