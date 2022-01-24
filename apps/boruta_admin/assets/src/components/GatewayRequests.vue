<template>
  <div class="gateway-requests">
    <div class="ui two column stackable grid">
      <div class="column request-time">
        <LineChart :chartData="requestTimes" :options="options" height="500" />
      </div>
      <div class="column request-per-second">
        <LineChart :chartData="requestsPerSecond" :options="options" height="500" />
      </div>
      <div class="column status-codes">
        <PieChart :chart-data="statusCodes" />
      </div>
    </div>
  </div>
</template>

<script>
import palette from 'google-palette'
import { groupBy, sortBy, size, sum } from 'lodash'
import { mapGetters } from 'vuex'
import { LineChart, PieChart } from "vue-chart-3";
import { Chart, registerables } from 'chart.js';
Chart.register(...registerables);

export default {
  name: 'home',
  components: {
    LineChart,
    PieChart
  },
  data () {
    const options = {
      scales: {
        xAxis: {
          display: false
        }
      }
    }
    return {
      data: [],
      options
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
}
</style>
