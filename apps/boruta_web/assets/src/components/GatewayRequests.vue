<template>
  <div class="gateway-requests">
    <div class="request-time">
      <LineChart :chart-data="requestTimes" :options="options" :styles="graphStyles" />
    </div>
    <div class="request-per-second">
      <LineChart :chart-data="requestsPerSecond" :options="options" :styles="graphStyles" />
    </div>
    <div class="status-codes">
      <PieChart :chart-data="statusCodes" />
    </div>
  </div>
</template>

<script>
import palette from 'google-palette'
import { groupBy, sortBy, size, sum } from 'lodash'
import { mapGetters } from 'vuex'
import LineChart from '@/components/LineChart.vue'
import PieChart from '@/components/PieChart.vue'

export default {
  name: 'home',
  components: {
    LineChart,
    PieChart
  },
  data () {
    const options = {
      scales: {
        xAxes: [{
          type: 'time',
          time: {
            unit: 'second'
          }
        }]
      }
    }
    return {
      data: [],
      options,
      graphStyles: {
        position: 'relative'
      }
    }
  },
  computed: {
    formatedData () {
      return sortBy(this.data, 'start_time')
    },
    requestTimes () {
      const data = {
        labels: this.formatedData.map(({ start_time }) => new Date(start_time).toISOString()),
        datasets: [
          {
            label: 'Request time',
            borderColor: 'brown',
            fill: false,
            lineTension: 0,
            data: this.formatedData.map(({ request_time }) => request_time)
          }, {
            label: 'Gateway time',
            borderColor: 'blue',
            fill: false,
            lineTension: 0,
            data: this.formatedData.map(({ gateway_time }) => gateway_time)
          }, {
            label: 'Upstream time',
            borderColor: 'red',
            fill: false,
            lineTension: 0,
            data: this.formatedData.map(({ upstream_time }) => upstream_time)
          }
        ]
      }

      return data
    },
    requestsPerSecond () {
      const data = {
        labels: this.formatedData.map(({ start_time }) => new Date(start_time).toISOString()),
        datasets: [
          {
            label: 'Request count',
            borderColor: 'green',
            fill: false,
            lineTension: 0,
            data: this.formatedData.map(({ count }) => count)
          }
        ]
      }

      return data
    },
    statusCodes () {
      const statusCodes = groupBy(this.formatedData, ({ status_code }) => status_code)
      const data = {
        labels: Object.keys(statusCodes),
        datasets: [
          {
            backgroundColor: palette('sequential', size(statusCodes)).map(hex => `#${hex}`),
            data: Object.values(statusCodes).map(codes => sum(codes.map(({ count }) => count)))
          }
        ]
      }

      return data
    },
    ...mapGetters(['socket'])
  },
  async mounted () {
    await this.$store.dispatch('socketConnection')

    const channel = this.socket.channel('metrics:lobby')

    channel.on('boruta_gateway', ({ request }) => {
      this.data.push(request)
    })
    channel.join()
  }
}
</script>

<style scoped lang="scss">
.gateway-requests {
  display: flex;
  flex-wrap: wrap;
  &>div {
    width: 33%;
  }
  @media (max-width: 1200px) {
    &>div {
      width: 50%;
    }
  }
  @media (max-width: 768px) {
    flex-direction: column;
    &>div {
      width: 100%;
    }
  }
}
</style>
