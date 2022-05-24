<template>
  <div id="app">
    <Header ref="header" />
    <div id="main" ref="main">
      <div class="sidebar-menu">
        <div class="ui big vertical inverted fluid tabular menu">
          <router-link
            v-slot="{ href, route, navigate, isActive, isExactActive }"
            :to="{ name: 'dashboard' }">
            <div class="dashboard item" :class="{'active': isActive }">
              <a :href="href" @click="navigate">
                <i class="chart area icon"></i>
                <span>Dashboard</span>
              </a>
            </div>
          </router-link>
          <router-link
            v-slot="{ href, route, navigate, isActive, isExactActive }"
            :to="{ name: 'upstreams' }">
            <div class="upstreams item" :class="{'active': isActive }">
              <a :href="href" @click="navigate">
                <i class="server icon"></i>
                <span>Upstreams</span>
              </a>
            </div>
          </router-link>
          <router-link
            v-slot="{ href, route, navigate, isActive, isExactActive }"
            :to="{ name: 'clients' }">
            <div class="clients item" :class="{'active': isActive }">
              <a :href="href" @click="navigate">
                <i class="certificate icon"></i>
                <span>Clients</span>
              </a>
            </div>
          </router-link>
          <router-link
            v-slot="{ href, route, navigate, isActive, isExactActive }"
            :to="{ name: 'relying-parties' }">
            <div class="users item" :class="{'active': isActive }">
              <a :href="href" @click="navigate">
                <i class="users icon"></i>
                <span>Relying parties</span>
              </a>
              <div class="dropdown">
                <div class="subitem">
                  <router-link :to="{ name: 'relying-party-list' }">
                    <span>relying party list</span>
                  </router-link>
                </div>
                <div class="subitem">
                  <router-link :to="{ name: 'user-list' }">
                    <span>user list</span>
                  </router-link>
                </div>
              </div>
            </div>
          </router-link>
          <router-link
            v-slot="{ href, route, navigate, isActive, isExactActive }"
            :to="{ name: 'scopes' }">
            <div class="scopes item" :class="{'active': isActive }">
              <a :href="href" @click="navigate">
                <i class="cogs icon"></i>
                <span>Scopes</span>
              </a>
            </div>
          </router-link>
        </div>
      </div>
      <div class="content-wrapper">
        <Breadcrumb class="main-breadcrumb" />
        <router-view class="content" />
      </div>
    </div>
  </div>
</template>

<script>
import Header from '../../components/Header.vue'
import Breadcrumb from '../../components/Breadcrumb.vue'

export default {
  name: 'Main',
  components: {
    Header,
    Breadcrumb
  },
  mounted () {
    const sidebarOffset = this.$refs.header.$el.offsetHeight

    document.addEventListener('scroll', () => {
      const main = this.$refs.main

      if (window.scrollY < sidebarOffset) {
        main.classList.remove('fixed-sidebar')
      } else {
        main.classList.add('fixed-sidebar')
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
    label {
      color: white!important;
    }
    .ui.input {
      color: white;
    }
    .error-message {
      color: #e09494!important;
      position: absolute;
      bottom: -.2em;
      left: 1em;
    }
    .error.field {
      label {
        color: #e09494!important;
      }
      select, input {
        border: 1px solid #e09494;
        background: #493939;
      }
    }
  }
  input[disabled]~label {
    color: #ddd!important;
  }
  .label {
    cursor: default;
  }
  .olive {
    background: rgba(61, 61, 61, 1.0)!important;
    &.button:hover, &.label:hover {
      background: rgba(61, 61, 61, 0.7)!important;
    }
  }
  .violet {
    background: rgba(131, 52, 113, 1.0)!important;
    &.button:hover, &.label:hover {
      background: rgba(131, 52, 113, 0.7)!important;
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
  color: white;
  .main.create.button {
    position: absolute;
    top: .5em;
    right: .5em;
    @media screen and (max-width: 1127px) {
      position: relative;
      display: block;
      top: 0;
      right: 0;
      margin: 0 1rem;
      margin-bottom: 1rem;

    }
  }
  a {
    cursor: pointer;
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
      .item {
        position: relative;
        padding: 0;
        min-width: 4em;
        min-height: 4em;
        span {
          margin-left: 1.5em;
          margin-right: 4em;
          line-height: 4em;
        }
        i {
          position: absolute;
          top: 1.5em;
          right: 1.5em;
        }
        &.active {
          background: rgba(255,255,255,.05);
          border: none;
          .dropdown {
            display: block;
          }
          &:hover {
            background: rgba(255,255,255,.08);
          }
        }
        &:not(.active):hover {
          .dropdown {
            display: block;
            position: absolute;
            left: 100%;
            top: -2px;
            width: 200px;
            z-index: 1000;
            border: 1px solid rgba(255,255,255,.03);
            .subitem {
              text-align: left;
            }
          }
        }
        &:hover {
          background: rgba(255,255,255,.08);
        }
      }
      a {
        display: block;
        height: 100%;
      }
      .dropdown {
        display: none;
        background: #1b1c1d;
        .subitem {
          text-align: right;
          position: relative;
          font-size: .85em;
          height: 3rem;
          span {
            padding-left: 2rem;
            margin: 1em;
          }
          a {
            color: white;
            &.active {
              background: inherit;
              &:hover {
                background: rgba(255,255,255,.08);
              }
            }
            &.router-link-exact-active {
              background: rgba(255,255,255,.05);
              border: none;
              &:hover {
                background: rgba(255,255,255,.08);
              }
            }
            &:hover {
              background: rgba(255,255,255,.08);
            }
          }
          span {
            line-height: 3rem;
          }
        }
      }
    }
  }
  .ui.grid {
    margin: -1rem 0 1rem 0;
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
  .content-wrapper {
    flex: 1;
    width: calc(100vw - 250px);
    display: flex;
    flex-direction: column;
    .content {
      flex: 1;
    }
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
    .content-wrapper {
      width: auto;
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
    .sidebar-menu {
      height: 100%;
    }
    &.fixed-sidebar {
      padding-left: 200px;
      .sidebar-menu {
        position: fixed;
        left: 0;
        top: 0;
        bottom: 0;
      }
    }
  }
}
</style>
