<template>
  <div id="app">
    <Header />
    <div id="main">
      <router-view/>
    </div>
  </div>
</template>

<script>
import Header from '@/components/Header.vue'

export default {
  name: 'App',
  components: {
    Header
  }
}
</script>

<style lang="scss">
h1 {
  padding: 1em 0;
  margin: 0;
}
a {
  cursor: pointer;
}
.actions {
  text-align: right;
  margin: 1em 0;
}
</style>
