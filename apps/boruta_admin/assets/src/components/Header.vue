<template>
  <div class="header" :class="{ 'dark': darkMode }">
    <div class="ui main menu" :class="{ 'inverted': darkMode }">
      <router-link :to="{ name: 'home' }" class="logo item">
        <img src="../assets/images/logo-inverted.png" v-if="darkMode" />
        <img src="../assets/images/logo.png" v-else />
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
import oauth from '../services/oauth.service'

export default {
  name: 'Header',
  props: ['darkMode'],
  computed: {
    currentUser() {
      return oauth.currentUser
    },
    ...mapGetters(['isAuthenticated'])
  },
  methods: {
    logout () {
      this.$store.dispatch('logout')
    }
  }
}
</script>

<style scoped lang="scss">
.header.dark {
  background: #1b1c1d;
  .main.menu {
    border-bottom: 1px solid rgba(255,255,255,.08);
  }
}
.header {
  max-width: 100%;
  overflow: hidden;
  .item.logo {
    min-width: 199px;
    background: inherit!important;
    padding: 0 1rem 0 1.5rem;
    &:before {
      display: none;
    }
    img {
      max-width: calc(199px - 2.5rem);
      max-height: 22px;
      width: auto;
    }
  }
  .main.menu {
    border-radius: 0;
  }

  @media screen and (max-width: 1127px) {
    .item.logo {
      display: none;
    }
  }
}
</style>
