<template>
  <div id="app">
    <Header ref="header" />
    <div id="main">
      <div class="sidebar-menu" ref="sidebar">
        <div class="ui big vertical inverted fluid tabular menu">
          <router-link :to="{ name: 'dashboard' }" class="dashboard item">
            <i class="chart area icon"></i>
            <span>Dashboard</span>
          </router-link>
          <router-link :to="{ name: 'upstream-list' }" class="upstreams item">
            <i class="server icon"></i>
            <span>Upstreams</span>
          </router-link>
          <router-link :to="{ name: 'user-list' }" class="users item">
            <i class="users icon"></i>
            <span>Users</span>
          </router-link>
          <router-link :to="{ name: 'client-list' }" class="clients item">
            <i class="certificate icon"></i>
            <span>Clients</span>
          </router-link>
          <router-link :to="{ name: 'scope-list' }" class="scopes item">
            <i class="cogs icon"></i>
            <span>Scopes</span>
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
    const sidebarOffset = this.$refs.header.$el.offsetHeight

    document.addEventListener('scroll', () => {
      const nav = this.$refs.sidebar

      if (window.scrollY < sidebarOffset) {
        nav.classList.remove('fixed')
      } else {
        nav.classList.add('fixed')
      }
    })
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
  hr {
    border: 1px solid rgba(255, 255, 255, 0.15);
    margin: 1rem 0;
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
    position: relative;
    select, input {
      border: 1px solid rgba(255, 255, 255, 0.15);
      background: #393939;
      color: white;
    }
    .ui.input {
      color: white;
    }
    .error-message {
      position: absolute;
      bottom: -1em;
      left: 1em;
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
  .main.header {
    text-align: center;
    position: relative;
    padding: .6rem;
    background: rgba(255,255,255,.05);
    margin-bottom: 1rem;
    h1 {
      margin: 0;
      color: white;
      line-height: 1.7em;
    }
    .button {
      position: absolute;
      right: .6rem;
      top: .6rem;
    }
    @media screen and (max-width: 753px) {
      .button {
        position: relative;
      }
    }
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
      margin: 1rem 0;
    }
    .button {
      margin: 5px;
    }
  }
  .sidebar-menu {
    background: #1b1c1d;
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
    @media (min-width: 1127px) {
      &.fixed {
        position: fixed;
        top: 0;
        bottom: 0;
      }
    }
  }
  .ui.grid {
    margin: 0;
    margin: -1rem 0;
    .column {
      padding: 0;
      padding-top: 1rem;
      padding-right: 1rem;
    }
    .column>.segment {
      height: 100%;
    }
    &.two.column {
      .column {
        &:nth-child(2n) {
          padding-right: 0;
        }
      }
    }
    &.three.column {
      .column {
        &:nth-child(3n) {
          padding-right: 0;
        }
      }
    }
  }
  .ui.header {
    color: white;
  }
  .ui.segments {
    margin: 0;
    .segment:last-child {
      margin: 0;
    }
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
      @media screen and (max-width: 768px) {
        padding: 0;
      }
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
        border-right: 1px solid rgba(255,255,255,.05);
        border-left: 1px solid rgba(255,255,255,.05);
        border-bottom: 1px solid rgba(255,255,255,.05);
        &.active {
          background: rgba(255,255,255,.05);
        }
      }
    }
  }
  @media screen and (min-width: 1127px) {
    padding-left: 4.7em;
    .sidebar-menu {
      position: absolute;
      left: 0;
      z-index: 100;
      height: 100%;
      width: 4.7em;
      min-width: 0;
      overflow: hidden;
      transition: width .2s ease-in-out;
      .menu {
        .item {
          position: relative;
          padding: 0;
          min-width: 4em;
          height: 4em;
          span {
            margin-left: 1.5em;
            margin-right: 4em;
            line-height: 4em;
            opacity: 0;
            transition: opacity .2s ease-in-out;
          }
          i {
            position: absolute;
            top: 1.5em;
            right: 1.5em;
          }
        }
      }
      &:hover {
        width: 200px;
        .item span {
          opacity: 1;
        }
      }
    }
  }
}
</style>
