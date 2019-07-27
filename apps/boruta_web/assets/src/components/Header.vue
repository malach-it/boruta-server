<template>
  <div class="header">
    <div class="ui secondary pointing menu">
      <router-link :to="{ name: 'home' }" exact class="item">
        Home
      </router-link>
      <router-link v-if="isAuthenticated" :to="{ name: 'user-list' }" class="item">
        Users
      </router-link>
      <router-link v-if="isAuthenticated" :to="{ name: 'client-list' }" class="item">
        Clients
      </router-link>
      <router-link v-if="isAuthenticated" :to="{ name: 'scope-list' }" class="item">
        Scopes
      </router-link>
      <div class="right menu">
        <span v-if="isAuthenticated" class="ui item">
          {{ currentUser.email }}
        </span>
        <a v-if="isAuthenticated" v-on:click.prevent="logout()" class="ui item">
          Logout
        </a>
        <a v-else v-on:click="login()" class="ui item">
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
  computed: {
    ...mapGetters(['currentUser', 'isAuthenticated'])
  },
  methods: {
    login () {
      this.$store.dispatch('login')
    },
    logout () {
      this.$store.dispatch('logout').then(() => {
        this.$router.push({ name: 'home' })
      })
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
