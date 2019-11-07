<template>
  <div id="app">
    <Header />
    <div id="main">
      <div class="ui left internal rail">
        <div class="ui big vertical fluid tabular menu">
          <span class="item">&nbsp;</span>
          <router-link v-if="isAuthenticated" :to="{ name: 'user-list' }" class="users item">
            Users
          </router-link>
          <router-link v-if="isAuthenticated" :to="{ name: 'client-list' }" class="clients item">
            Clients
          </router-link>
          <router-link v-if="isAuthenticated" :to="{ name: 'scope-list' }" class="scopes item">
            Scopes
          </router-link>
        </div>
      </div>
      <router-view/>
    </div>
  </div>
</template>

<script>
import { mapGetters } from 'vuex'
import Header from '@/components/Header.vue'

export default {
  name: 'App',
  components: {
    Header
  },
  computed: {
    ...mapGetters(['isAuthenticated'])
  },
  mounted () {
    this.$store.dispatch('getCurrentUser')
  }
}
</script>

<style lang="scss">
#main {
  position: relative;
  h1 {
    text-align: center;
    padding: 1em 0;
    margin: 0;
  }
  a {
    cursor: pointer;
  }
  .actions {
    float: right;
    &.main {
      margin: 1em 0;
    }
  }
  .ui.input.error>input {
    background-color: #fff6f6;
    border-color: #e0b4b4;
    color: #9f3a38;
    box-shadow: none;
  }
  @media screen and (max-width: 1780px) {
    .rail {
      position: relative;
      width: 60%;
      margin: auto;
      padding: 0;
    }
    .menu {
      text-align: center;
      border-right: none;
      .item {
        border-right: 1px solid #d4d4d5;
        border-left: 1px solid #d4d4d5;
        border-bottom: 1px solid #d4d4d5;
        &.active {
          background: #d4d4d5;
        }
        &:nth-child(1) {
          display: none;
        }
      }
    }
  }
}
</style>
