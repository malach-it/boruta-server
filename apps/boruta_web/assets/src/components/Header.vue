<template>
  <div class="header">
    <div class="ui secondary pointing menu">
      <router-link :to="{ name: 'home' }" exact class="item">
        Home
      </router-link>
      <router-link :to="{ name: 'client-list' }" class="item">
        Clients
      </router-link>
      <router-link :to="{ name: 'scope-list' }" class="item">
        Scopes
      </router-link>
      <div class="right menu">
        <a v-on:click="login()" class="ui item">
          Login
        </a>
      </div>
    </div>
  </div>
</template>

<script>
import oauth from '@/services/oauth.service'
import { mapGetters } from 'vuex'

export default {
  name: 'Header',
  methods: {
    login () {
      return oauth.login()
    },
  }
}
</script>

<style scoped lang="scss">
.ui.secondary.pointing.menu .router-link-active.item {
  background-color: transparent;
  box-shadow: none;
  border-color: #1b1c1d;
  font-weight: 700;
  color: rgba(0,0,0,.95);
}
</style>
