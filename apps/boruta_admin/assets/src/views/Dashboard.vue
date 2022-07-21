<template>
  <div class="dashboard">
    <div class="container">
      <GatewayRequests />
      <h2>Logs</h2>
      <div class="ui logs segment">
        <pre>{{ logs }}</pre>
      </div>
    </div>
  </div>
</template>

<script>
import Logs from '../services/logs.service'
import GatewayRequests from '../components/GatewayRequests.vue'

export default {
  name: 'home',
  components: {
    GatewayRequests
  },
  data() {
    return {
      logs: ''
    }
  },
  async mounted() {
    const stream = await Logs.stream()

    const read = (stream) => {
      console.log(stream)

      stream.read().then(({ done, value }) => {
        // decode Uint8Array to utf-8 string
        this.logs += new TextDecoder().decode(value)

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
    max-height: 60vh;
  }
}
</style>
