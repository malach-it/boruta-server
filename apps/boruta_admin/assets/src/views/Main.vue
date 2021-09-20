<template>
  <div id="app">
    <Header />
    <div id="main">
      <div class="sidebar-menu">
        <div class="ui big vertical inverted fluid tabular menu">
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
  .ui.label {
    margin: 5px;
  }
  pre {
    margin: 0;
  }
  .attribute.list {
    margin: 0;
    .item {
      list-style-type: none;
      margin-bottom: 1rem;
      .header {
        color: #999;
      }
      .description {
        padding-left: 1rem;
        color: inherit;
        text-overflow: ellipsis;
        overflow: hidden;
      }
    }
  }
  .ui.menu>.item {
    border-radius: 0!important;
  }
  .ui.form {
    .ui.input.error>input {
      background-color: #fff6f6;
      border-color: #e0b4b4;
      color: #9f3a38;
      box-shadow: none;
    }
    .ui.input, select, input {
      border: 1px solid rgba(255, 255, 255, 0.15);
      background: #393939;
      color: white;
    }
  }
  .label {
    cursor: default;
  }
  .olive {
    background: rgba(71, 71, 135,1.0)!important;
    &.button:hover, &.label:hover {
      background: rgba(71, 71, 135,0.7)!important;
    }
  }
  .violet {
    background: rgba(205, 97, 51,1.0)!important;
    &.button:hover, &.label:hover {
      background: rgba(205, 97, 51,0.7)!important;
    }
  }
  .blue {
    background: rgba(34, 112, 147,1.0)!important;
    &.button:hover, &.label:hover {
      background: rgba(34, 112, 147,0.7)!important;
    }
  }
  .red {
    background: rgba(179, 57, 57,1.0)!important;
    &.button:hover, &.label:hover {
      background: rgba(179, 57, 57,0.7)!important;
    }
  }
  .teal {
    background: rgba(33, 140, 116,1.0)!important;
    &.button:hover, &.label:hover {
      background: rgba(33, 140, 116,0.7)!important;
    }
  }
}
#main {
  position: relative;
  display: flex;
  min-height: calc(100% - 41px);
  background: #1b1c1d;
  h1 {
    text-align: left;
    padding: 1em;
    margin: 0;
    color: white;
    background: rgba(255,255,255,.05);
    border-bottom: 1px solid rgba(255,255,255,.05);
    margin-bottom: 1rem;
  }
  a {
    cursor: pointer;
  }
  label {
    color: white!important;
  }
  .actions {
    float: right;
    &.main {
      margin: 1em 0;
    }
    .button {
      margin: 5px;
    }
  }
  .sidebar-menu {
    min-width: 200px;
    color: white;
    border-right: 1px solid rgba(255,255,255,.05);
    .menu {
      border: none;
      .active.item {
        background: rgba(255,255,255,.05);
        border: none;
        &:hover {
          background: rgba(255,255,255,.08);
        }
      }
    }
  }
  .ui.grid {
    margin-bottom: 0;
    .column>.segment {
      height: 100%;
    }
  }
  .ui.segments {
    margin-bottom: 0;
  }
  .ui.segment {
    background: rgba(255,255,255,.05);
    color: white;
    border: 1px solid rgba(255, 255, 255, 0.1);
    margin-bottom: 1rem;
    &.highlightable:hover {
      background: rgba(255,255,255,.08);
    }
  }
  .content {
    flex: 1;
    .container {
      padding: 0 1rem;
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
