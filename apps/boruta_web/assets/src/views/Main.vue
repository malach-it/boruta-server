<template>
  <div id="app">
    <Header />
    <div id="main">
      <div class="sidebar-menu">
        <div class="ui big vertical fluid tabular menu">
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
      <div class="content">
        <router-view/>
      </div>
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
#app {
  height: 100%;
  position: relative;
}
#main {
  position: relative;
  display: flex;
  height: calc(100% - 40px);
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
  .sidebar-menu {
    min-width: 200px;
    border: 1px solid #d4d4d5;
    height: 100%;
    .menu {
      border-right: none;
    }
  }
  .content {
    flex: 1;
    .container {
      padding: 0 20px;
    }
  }
  @media screen and (max-width: 1127px) {
    flex-direction: column;
    .sidebar-menu {
      height: auto;
    }
    .menu {
      border-right: none;
      .item {
        border-right: 1px solid #d4d4d5;
        border-left: 1px solid #d4d4d5;
        border-bottom: 1px solid #d4d4d5;
        &.active {
          background: #d4d4d5;
        }
      }
    }
  }
}
</style>
