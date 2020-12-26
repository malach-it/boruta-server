<template>
  <div id="app">
    <Header />
    <div id="main">
      <div class="ui left internal rail">
        <div class="ui big vertical fluid tabular menu">
          <span class="item">&nbsp;</span>
          <router-link :to="{ name: 'dashboard' }" class="dashboard item">
            <i class="chart area icon"></i>
            Dashboard
          </router-link>
          <router-link :to="{ name: 'upstream-list' }" class="upstreams item">
            <i class="server icon"></i>
            Upstreams
          </router-link>
          <router-link :to="{ name: 'user-list' }" class="users item">
            <i class="users icon"></i>
            Users
          </router-link>
          <router-link :to="{ name: 'client-list' }" class="clients item">
            <i class="certificate icon"></i>
            Clients
          </router-link>
          <router-link :to="{ name: 'scope-list' }" class="scopes item">
            <i class="cogs icon"></i>
            Scopes
          </router-link>
        </div>
      </div>
      <router-view/>
    </div>
  </div>
</template>

<script>
import Header from '@/components/Header.vue'

export default {
  name: 'Main',
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
  .rail {
    z-index: 100;
  }
}
</style>
