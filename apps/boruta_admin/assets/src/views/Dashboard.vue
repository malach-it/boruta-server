<template>
  <div class="dashboard">
    <div class="main header">
      <h1>Dashboard</h1>
    </div>
    <div class="container">
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
