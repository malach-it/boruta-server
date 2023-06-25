<template>
  <div id="app" :class="{ 'dark': currentMode }">
    <Header ref="header" :darkMode="currentMode" />
    <div id="main" ref="main">
      <div class="sidebar-menu" ref="menu">
        <i class="ui large burger bars icon" @click="toggleMenu()"></i>
        <i class="ui large burger close icon" @click="toggleMenu()"></i>
        <div class="ui vertical fluid tabular menu" :class="{ 'inverted': currentMode }">
          <router-link
            v-slot="{ href, route, navigate, isActive, isExactActive }"
            :to="{ name: 'dashboard' }">
            <div class="dashboard item" :class="{'active': isActive }">
              <a :href="href" @click="navigate">
                <i class="chart area icon"></i>
                <span>Dashboard</span>
              </a>
              <div class="dropdown">
                <div class="subitem">
                  <router-link :to="{ name: 'request-logs' }">
                    <span>Requests</span>
                  </router-link>
                </div>
                <div class="subitem">
                  <router-link :to="{ name: 'business-event-logs' }">
                    <span>Business events</span>
                  </router-link>
                </div>
              </div>
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
              <div class="dropdown">
                <div class="subitem">
                  <router-link :to="{ name: 'client-list' }">
                    <span>Client list</span>
                  </router-link>
                </div>
                <div class="subitem">
                  <router-link :to="{ name: 'key-pair-list' }">
                    <span>Key pair list</span>
                  </router-link>
                </div>
              </div>
            </div>
          </router-link>
          <router-link
            v-slot="{ href, route, navigate, isActive, isExactActive }"
            :to="{ name: 'identity-providers' }">
            <div class="identity-providers item" :class="{'active': isActive }">
              <a :href="href" @click="navigate">
                <i class="users icon"></i>
                <span>Identity providers</span>
              </a>
              <div class="dropdown">
                <div class="subitem">
                  <router-link :to="{ name: 'identity-provider-list' }">
                    <span>identity provider list</span>
                  </router-link>
                </div>
                <div class="subitem">
                  <router-link :to="{ name: 'backend-list' }">
                    <span>backend list</span>
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
              <div class="dropdown">
                <div class="subitem">
                  <router-link :to="{ name: 'scope-list' }">
                    <span>scope list</span>
                  </router-link>
                </div>
                <div class="subitem">
                  <router-link :to="{ name: 'role-list' }">
                    <span>role list</span>
                  </router-link>
                </div>
              </div>
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
    <footer>
      <a @click="toggleDarkMode()" class="dark-mode">
        <i class="sun icon" :class="{ 'outline': currentMode }"></i>
      </a>
      &copy; 2022 patatoid
    </footer>
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
  data () {
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
    toggleMenu () {
      this.$refs.menu.classList.toggle('opened')
    },
    toggleDarkMode () {
      this.currentMode = !this.currentMode
      localStorage.setItem('dark_mode', this.currentMode)
    }
  },
  beforeRouteUpdate () {
    this.$refs.menu.classList.remove('opened')
  }
}
</script>

<style lang="scss">
#app {
  min-height: 100vh;
  position: relative;
  display: flex;
  flex-direction: column;
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
  footer {
    z-index: 200;
    text-align: right;
    padding: 1rem;
    border-top: 1px solid rgba(34,36,38,.15);
    .dark-mode {
      cursor: pointer;
      float: left;
      color: rgba(0,0,0,.87);
    }
  }
}
#main {
  position: relative;
  flex: 1;
  display: flex;
  min-height: calc(100% - 41px);
  .main.create.button {
    position: absolute;
    top: .53em;
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
  .main.buttons {
    position: absolute;
    top: .53em;
    right: .5em;
    .create.button {
      position: relative;
      top: 0;
    }
    @media screen and (max-width: 1127px) {
      position: relative;
      display: block;
      top: 0;
      right: 0;
    }
  }
  a {
    cursor: pointer;
  }
  h3, h4, h5 {
    margin: .5em 0;
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
    position: relative;
    min-width: 200px;
    border-right: 1px solid #d4d4d5;
    .menu {
      margin-top: 0!important;
      background: white;
      height: 100%;
      border: none;
      .item {
        background: white;
        position: relative;
        padding: 0;
        min-width: 3em;
        min-height: 2.5em;
        border: none;
        cursor: pointer;
        span {
          margin-left: 2.5em;
          margin-right: 1em;
          line-height: 2.5rem;
        }
        i {
          position: absolute;
          top: .625em;
          left: .75em;
        }
        &.active {
          background: inherit;
          .dropdown {
            display: block;
            border-right: 1px solid #d4d4d5;
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
            top: 0px;
            width: 200px;
            z-index: 1000;
            .subitem {
              text-align: left;
              border: 1px solid #d4d4d5;
              border-top: none;
              span {
                margin-left: 1em;
              }
            }
            @media screen and (max-width: 1127px) {
              display: none;
            }
          }
        }
        &:hover {
          background: #e7e7e8;
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
              background: #e7e7e8;
            }
          }
        }
      }
    }
    .burger {
      display: none;
      cursor: pointer;
      position: absolute;
      top: -1.5em;
      left: .5em;
    }
    @media screen and (max-width: 1127px) {
      position: fixed;
      z-index: 100;
      width: 100%;
      .menu {
        display: none;
        z-index: 100;
        .item {
          border-bottom: 1px solid #d4d4d5;
        }
      }
      .burger.bars {
        display: block;
      }
      &.opened {
        .burger.close {
          display: block;
        }
        .burger.bars {
          display: none;
        }
        .menu {
          display: block;
        }
      }
      height: auto;
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
        height: 100%;
      }
    }
  }
  .ui.message {
    word-break: break-word;
  }
  .ui.button {
    font-size: .9em;
  }
  .ui.list {
    & .item:last-child {
      margin: 0;
    }
  }
  .ui.grid {
    margin: -1rem 0 0 0;
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
    label i {
      font-weight: normal;
    }
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
    .inline.fields>.field {
      margin: 0;
    }
    .ui.icon.input>i.icon {
      cursor: pointer;
      pointer-events: all;
      position: absolute;
    }
    .field {
      margin-bottom: 1em;
      &.error label {
        color: #9f3a38!important;
      }
    }
  }
  .ui.segments {
    margin: 0;
    .segment{
      border: 1px solid rgba(34,36,38,.15)!important;
      &:last-child {
        margin: 0;
      }
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
    padding-top: 3em;
    flex-direction: column;
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
    border-right: 1px solid rgba(255,255,255,.05);
    color: white;
    .menu {
      background: #1b1c1d;
      border: none;
      .item {
        background: #1b1c1d;
        border: none;
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
          background: rgba(255,255,255,.08);
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
            }
            &.router-link-exact-active {
              background: rgba(255,255,255,.05);
              border: none;
              &:hover {
                background: rgba(255,255,255,.08);
              }
            }
            &:hover {
              background: rgba(255,255,255,.08)!important;
            }
          }
        }
      }
    }
    @media screen and (max-width: 1127px) {
      .menu .item {
        border-bottom: 1px solid rgba(255,255,255,.05);
      }
    }
  }
  .ui.form {
    position: relative;
    select, input, textarea {
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
    border: 1px solid rgba(255, 255, 255, 0.1)!important;
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
  .ui.list {
    &>.item .header {
      color: white;
    }
    &.celled {
      &>.item {
        border-top: 1px solid rgba(255, 255, 255, 0.1);
      }
    }
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
  .text-editor {
    .codejar-wrap {
      height: 100%;
      .codejar-linenumbers {
        color: white;
      }
    }
    .editor {
      background: rgba(255,255,255,.05);
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
  footer {
    background: #1b1c1d;
    border-top: 1px solid rgba(255,255,255,.08);
    .dark-mode {
      color: white;
      &:hover {
        background: inherit!important;
      }
    }
  }
}
</style>
