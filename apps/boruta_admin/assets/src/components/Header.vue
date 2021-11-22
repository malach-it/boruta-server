<template>
  <div class="header">
    <div class="ui main inverted menu">
      <router-link :to="{ name: 'home' }" class="logo item">
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
  background: #1b1c1d;
  max-width: 100%;
  overflow: hidden;
  .item.logo {
    min-width: 200px;
    background: inherit!important;
  }
  .main.menu {
    border-radius: 0;
    border-bottom: 1px solid rgba(255,255,255,.08);
  }

  @media screen and (max-width: 1127px) {
    .item.logo {
      display: none;
    }
  }
}
</style>
