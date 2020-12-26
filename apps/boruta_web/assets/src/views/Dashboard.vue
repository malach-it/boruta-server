<template>
  <div class="dashboard">
    <div class="ui container">
      <h1>Dashboard</h1>
      <GatewayRequests />
    </div>
  </div>
</template>

<script>
import GatewayRequests from '@/components/GatewayRequests.vue'

export default {
  name: 'home',
  components: {
    GatewayRequests
  }
}
</script>

<style scoped lang="scss">
.dashboard {
  position: relative;
}
</style>
