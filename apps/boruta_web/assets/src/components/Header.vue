<template>
  <div class="header">
    <div class="ui secondary pointing menu">
      <router-link :to="{ name: 'home' }" class="logo item active">
        Boruta
      </router-link>
      <div class="right menu">
        <span class="ui item">
          {{ currentUser.email }}
        </span>
        <a v-on:click.prevent="logout()" class="ui item">
          Logout
        </a>
      </div>
    </div>
  </div>
</template>

<script>
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
      this.$store.dispatch('logout')
    }
  }
}
</script>

<style scoped lang="scss">
.header {
  .logo {
    min-width: 200px;
  }
  .ui.secondary.pointing.menu .router-link-active.item {
    background-color: transparent;
    box-shadow: none;
    border-color: #1b1c1d;
    font-weight: 700;
    color: rgba(0,0,0,.95);
  }

  @media screen and (max-width: 1127px) {
    .logo {
      min-width: auto;
    }
  }
}
</style>
