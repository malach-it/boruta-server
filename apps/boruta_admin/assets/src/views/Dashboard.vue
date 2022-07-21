<template>
  <div class="dashboard">
    <div class="container">
      <GatewayRequests />
      <h2>Request logs</h2>
      <div class="ui logs segment">
        <pre>{{ requestLogs }}</pre>
      </div>
      <h2>Business logs</h2>
      <div class="ui logs segment">
        <pre>{{ businessLogs }}</pre>
      </div>
    </div>
  </div>
</template>

<script>
import Logs from '../services/logs.service'
import GatewayRequests from '../components/GatewayRequests.vue'

const REQUEST_REGEX = /([^\s]+) request_id=(\w+) \[info\] (\w+) (\w+) ([^\s]+) - (\w+) (\d{3}) in (\d+)(\w{2})/
const BUSINESS_REGEX = /([^\s]+) request_id=(\w+) \[info\] (\w+) (\w+) - (\w+)( (\w+)=((\".+\")|([^\s]+)))+/

export default {
  name: 'home',
  components: {
    GatewayRequests
  },
  data() {
    return {
      // logs: '',
      requestLogs: '',
      businessLogs: ''
    }
  },
  async mounted() {
    const stream = await Logs.stream()

    const read = (stream) => {
      console.log(stream)

      stream.read().then(({ done, value }) => {
        // decode Uint8Array to utf-8 string
        const data = new TextDecoder().decode(value)

        // this.logs += data
        data.split('\n').map(log => {
          if (log.match(REQUEST_REGEX)) this.requestLogs += `${log}\n`
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
