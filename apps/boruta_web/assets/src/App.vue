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
  },
  mounted () {
    this.$store.dispatch('getCurrentUser')
  }
}
</script>

<style lang="scss">
#main {
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
  .ui.input.error>input {
    background-color: #fff6f6;
    border-color: #e0b4b4;
    color: #9f3a38;
    box-shadow: none;
  }
}
</style>
