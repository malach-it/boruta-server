<template>
  <router-view></router-view>
</template>

<script>
import { getTheme, setTheme } from './services/theme.service'

export default {
  name: 'App',
  created () {
    setTheme(getTheme(), false)
  }
}
</script>

<style lang="scss">
body {
  min-height: 100%;
  height: auto;
  width: 100%;
  overflow-x: hidden;
}
</style>
