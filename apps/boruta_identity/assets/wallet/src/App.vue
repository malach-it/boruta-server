<template>
  <div class="main header">
    <router-link to="/">
      <img src="./assets/accounts/wallet/images/logo.png" />
    </router-link>
  </div>
  <div class="ui container">
    <div class="ui warning message">
      This wallet is aimed for demo purposes. Only use this wallet on a trusted device that you control.
    </div>
  </div>
  <div class="credential-password" v-if="credentialPasswordEventKey">
    <div class="ui center aligned segment">
      <h2>Unlock credentials</h2>
      <div class="ui error message" v-if="credentialPasswordError">{{ credentialPasswordError }}</div>
      <div class="ui form">
        <input type="hidden" name="username" value="Credentials lock" />
        <input
          type="password"
          v-model="credentialPassword"
          placeholder="Credentials password"
          @keyup.enter="approveCredentialPassword"
        />
      </div>
      <div class="ui fluid two buttons">
        <button class="ui orange button" @click="abortCredentialPassword">Abort</button>
        <button :disabled="!credentialPassword" class="ui green button" @click="approveCredentialPassword">Unlock</button>
      </div>
    </div>
  </div>
  <router-view/>
</template>

<script lang="ts">
import { defineComponent } from 'vue'

const CREDENTIALS_KEY = 'boruta-client_credentials'

export default defineComponent({
  name: 'App',
  data () {
    return {
      credentialPasswordEventKey: null,
      credentialPassword: '',
      credentialPasswordError: null,
      credentialPasswordAborted: false,
      credentialPasswordRequestPending: false
    }
  },
  computed: {
    credentialsError () {
      return this.$store.getters.credentialsError
    }
  },
  mounted () {
    window.addEventListener('access_credential-request~' + CREDENTIALS_KEY, () => {
      this.credentialPasswordEventKey = CREDENTIALS_KEY
      this.credentialPassword = ''
      this.credentialPasswordError = null
      this.credentialPasswordAborted = false
      this.credentialPasswordRequestPending = true
    })
  },
  methods: {
    approveCredentialPassword () {
      if (!this.credentialPassword || !this.credentialPasswordEventKey) return

      if (this.credentialPasswordRequestPending) {
        window.dispatchEvent(new CustomEvent(
          'access_credential-approval~' + this.credentialPasswordEventKey,
          { detail: this.credentialPassword }
        ))
      } else {
        this.$store.commit('refreshCredentials', this.credentialPassword)
      }

      this.credentialPasswordEventKey = null
      this.credentialPassword = ''
      this.credentialPasswordError = null
      this.credentialPasswordRequestPending = false
    },
    abortCredentialPassword () {
      if (this.credentialPasswordEventKey) {
        this.credentialPasswordAborted = true

        if (this.credentialPasswordRequestPending) {
          window.dispatchEvent(new CustomEvent(
            'access_credential-approval~' + this.credentialPasswordEventKey,
            { detail: null }
          ))
        }
      }

      this.credentialPasswordEventKey = null
      this.credentialPassword = ''
      this.credentialPasswordError = null
      this.credentialPasswordRequestPending = false
    }
  },
  watch: {
    credentialsError (error) {
      if (!error) return

      if (this.credentialPasswordAborted) {
        this.credentialPasswordAborted = false
        return
      }

      this.credentialPasswordEventKey = CREDENTIALS_KEY
      this.credentialPassword = ''
      this.credentialPasswordError = error
      this.credentialPasswordRequestPending = false
    }
  }
})
</script>

<style lang="scss">
html, body {
  width: 100%;
  overflow-x: hidden;
}
.main.header {
  border-bottom: 1px solid #eee;
  padding: 1em;
  background: white;
  display: flex;
  justify-content: center;
  img {
    width: 4em;
  }
}
#app {
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  background: #f8f8f8;
  min-height: 100vh;
}
.warning.message {
  text-align: center;
}
.credential-password {
  position: fixed;
  z-index: 1000;
  top: 0;
  right: 0;
  bottom: 0;
  left: 0;
  background: rgba(0, 0, 0, 0.7);
  display: flex;
  align-items: center;
  justify-content: center;

  .segment {
    width: min(28em, 90vw);
  }

  .form {
    margin: 1em 0;
  }
}
nav {
  text-align: center;
  padding: 30px;

  a {
    font-weight: bold;
    color: black;

    &:hover {
      color: #555;
    }
    &.router-link-exact-active {
      color: #f5ba00;
    }
  }
}
</style>
