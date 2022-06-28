<template>
  <div id="app" :class="{ 'dark': currentMode }">
    <Header ref="header" :darkMode="currentMode" />
    <div id="main" ref="main">
      <div class="sidebar-menu">
        <div class="ui vertical fluid tabular menu" :class="{ 'inverted': currentMode }">
          <a @click="toggleDarkMode()">
            <div class="dark-mode item">
              <i class="sun icon" :class="{ 'outline': currentMode }"></i>
            </div>
          </a>
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
            :to="{ name: 'identity-providers' }">
            <div class="identity-providers item" :class="{'active': isActive }">
              <a :href="href" @click="navigate">
                <i class="users icon"></i>
                <span>identity providers</span>
              </a>
              <div class="dropdown">
                <div class="subitem">
                  <router-link :to="{ name: 'identity-provider-list' }">
                    <span>identity provider list</span>
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
          <router-link
            v-slot="{ href, route, navigate, isActive, isExactActive }"
            :to="{ name: 'configuration' }">
            <div class="configuration item" :class="{'active': isActive }">
              <a :href="href" @click="navigate">
                <i class="columns icon"></i>
                <span>Configuration</span>
              </a>
              <div class="dropdown">
                <div class="subitem">
                  <router-link :to="{ name: 'error-template-list' }">
                    <span>Error templates</span>
                  </router-link>
                </div>
              </div>
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
  data() {
    return {
      currentMode: JSON.parse(localStorage.getItem('dark_mode'))
    }
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
  },
  methods: {
    toggleDarkMode() {
      this.currentMode = !this.currentMode
      localStorage.setItem('dark_mode', this.currentMode)
    }
  }
}
</script>

<style lang="scss">
#app {
  min-height: 100vh;
  position: relative;
  .ui.label {
    margin: 5px;
  }
  pre {
    margin: 0;
  }
  hr {
    border: none;
    border-bottom: 1px solid #d4d4d5;
    margin: 1rem 0;
  }
  .attribute.list {
    margin: 0;
    .item {
      list-style-type: none;
      .header {
        color: #999;
      }
      .description {
        padding-left: .5rem;
        color: inherit;
        text-overflow: ellipsis;
        overflow: hidden;
      }
    }
  }
  .ui.menu>.item {
    border-radius: 0!important;
  }
  .label {
    cursor: default;
  }
}
#main {
  position: relative;
  display: flex;
  min-height: calc(100% - 41px);
  .main.create.button {
    position: absolute;
    top: .6em;
    right: .5em;
    font-size: .825rem;
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
    min-width: 200px;
    .menu {
      height: 100%;
      border: none;
      .item {
        position: relative;
        padding: 0;
        min-width: 3em;
        min-height: 3em;
        border: 1px solid #d4d4d5;
        border-top: none;
        cursor: pointer;
        span {
          margin-left: 1.5em;
          margin-right: 3em;
          line-height: 3rem;
        }
        i {
          position: absolute;
          top: 1em;
          right: 1em;
        }
        &.active {
          .dropdown {
            display: block;
            .subitem {
              &:last-child {
                border-bottom: none;
              }
            }
          }
        }
        &:not(.active):hover {
          .dropdown {
            display: block;
            position: absolute;
            left: 100%;
            top: -1px;
            width: 200px;
            z-index: 1000;
            .subitem {
              text-align: left;
              border: 1px solid #d4d4d5;
              border-top: none;
            }
            @media screen and (max-width: 1127px) {
              display: none;
            }
          }
        }
        &:hover {
          background: rgba(255,255,255,.08);
        }
      }
      a {
        color: rgba(0,0,0,.87);
        display: block;
      }
      .dropdown {
        display: none;
        background: white;
        border-top: 1px solid #d4d4d5;
        .subitem {
          position: relative;
          border-top: none;
          text-align: right;
          font-size: .9em;
          height: 2rem;
          span {
            line-height: 2rem;
            padding-left: .5rem;
          }
          a {
            font-weight: normal!important;
            &.router-link-exact-active {
              font-weight: bold!important;
            }
            &:hover {
              font-weight: bold!important;
            }
          }
        }
      }
    }
    .dark-mode {
      text-align: center;
      @media screen and (min-width: 1127px) {
        border: none!important;
        position: fixed!important;
        bottom: 0;
        left: 0;
      }
    }
  }
  &.fixed-sidebar {
    @media screen and (min-width: 1127px) {
      padding-left: 200px;
      .sidebar-menu {
        position: fixed;
        left: 0;
        top: 0;
        z-index: 100;
      }
    }
  }
  .ui.list {
    & .item:last-child {
      margin: 0;
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
  .ui.form {
    position: relative;
    .error-message {
      position: absolute;
      bottom: -.2em;
      left: 1em;
    }
    .ui.checkbox input[type=radio] {
      opacity: 1!important;
    }
    .inline.fields>label {
      display: block;
      width: 100%;
    }
    .ui.icon.input>i.icon {
      cursor: pointer;
      pointer-events: all;
      position: absolute;
    }
  }
  .ui.segments {
    margin: 0;
    .segment:last-child {
      margin: 0;
    }
  }
  .ui.segment {
    margin-top: 0;
    margin-bottom: 1rem;
    &>.field, &>.fields {
      margin: 0;
    }
  }
  .ui.pagination {
    .item {
      border: none;
      cursor: pointer;
      &:hover {
        font-weight: bold;
      }
      &:disabled {
        opacity: .5;
        cursor: inherit;
        &:hover {
          font-weight: normal;
        }
      }
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
}
#app.dark {
  background: #1b1c1d;
  color: white;
  hr {
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  }
  .sidebar-menu {
    background: #1b1c1d;
    color: white;
    .menu {
      border: none;
      .item {
        border: 1px solid rgba(255,255,255,.05);
        border-top: none;
        &.active {
          border: none;
          background: rgba(255,255,255,.05);
          &:hover {
            background: rgba(255,255,255,.08);
            &:not(.active) {
              border: 1px solid rgba(255,255,255,.03);
            }
          }
        }
        &:hover {
          color: white;
        }
        a {
          color: white;
        }
      }
      .dropdown {
        border: none;
        background: #1b1c1d;
        border-top: 1px solid rgba(255,255,255,.05);
        .subitem {
          border: none!important;
          a {
            color: white;
            font-weight: normal!important;
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
        }
      }
    }
  }
  .ui.form {
    position: relative;
    select, input {
      border: 1px solid rgba(255, 255, 255, 0.15);
      background: #393939;
      color: white;
      &:focus {
        border: 1px solid #85b7d9!important;
      }
    }
    label {
      color: white!important;
    }
    .ui.input {
      color: white;
    }
    .error-message {
      color: #e09494!important;
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
  .ui.segment {
    background: rgba(255,255,255,.05);
    color: white;
    border: 1px solid rgba(255, 255, 255, 0.1);
    &.highlightable:hover {
      background: rgba(255,255,255,.08);
    }
  }
  .ui.breadcrumb {
    .divider {
      color: white!important;
    }
    a.section {
      font-weight: bold;
      color: rgba(153, 153, 153, 1.0)!important;
      &:hover {
        color: rgba(153, 153, 153, 0.7)!important;
      }
    }
  }
  .ui.header {
    color: white;
  }
  .ui.pagination.menu {
    background: #1b1c1d;
    border: 1px solid rgba(255,255,255,.08);
    .item {
      border: none!important;
      color: white;
      &.active {
        background: rgba(255,255,255,.05);
      }
    }
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
  .dark-mode {
    &:hover {
      background: inherit!important;
    }
  }
}
</style>
