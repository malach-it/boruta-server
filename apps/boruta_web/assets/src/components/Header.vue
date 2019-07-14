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
        <a v-if="isAuthenticated" v-on:click="logout()" class="ui item">
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
export default {
  name: 'Header',
  data () {
    return {
      isAuthenticated: this.$auth.isAuthenticated()
    }
  },
  methods: {
    login () {
      this.$auth.authenticate('boruta').then(({ access_token, expires_in }) => {
        this.isAuthenticated = this.$auth.isAuthenticated()
      })
    },
    logout () {
      localStorage.removeItem('vue-authenticate.vueauth_token')
      this.isAuthenticated = this.$auth.isAuthenticated()
    }
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
