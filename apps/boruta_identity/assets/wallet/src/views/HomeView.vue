<template>
  <div class="home">
    <Consent
      message="You are about to remove a credential from your wallet"
      :event-key="deleteConsentEventKey"
      @abort="abortDelete"
      @consent="deleteConsent"
    />
    <div class="ui segment container" v-if="credentialsError">
      <div class="ui error message">{{ credentialsError }}</div>
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
    <Credentials
      :credentials="credentials"
      :exportable="true"
      @deleteCredential="deleteCredential"
      @importCredentials="importCredentials"
    />
    <div class="reader-overlay" :class="{ 'hidden': !scanning }" @click="hide()">
      <video ref="reader" id="reader"></video>
    </div>
    <div>
      <button class="ui massive violet scan button" @click="scan()" v-show="!code"><i class="ui qrcode icon"></i> Scan a QR Code</button>
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent } from 'vue'
import { mapGetters } from 'vuex'
import QrScanner from 'qr-scanner'
import Credentials from '../components/Credentials.vue'
import Consent from '../components/Consent.vue'

const CREDENTIALS_KEY = 'boruta-client_credentials'

export default defineComponent({
  name: 'HomeView',
  components: { Credentials, Consent },
  data () {
    return {
      qrScanner: null,
      code: '',
      scanning: false,
      deleteConsentEventKey: null,
      credentialPasswordEventKey: null,
      credentialPassword: '',
      credentialPasswordError: null,
      credentialPasswordAborted: false,
      credentialPasswordRequestPending: false,
      credentialPasswordRequestHandler: null
    }
  },
  created () {
    this.credentialPasswordRequestHandler = () => {
      this.showCredentialPasswordPrompt()
    }
    window.addEventListener('access_credential-request~' + CREDENTIALS_KEY, this.credentialPasswordRequestHandler)
  },
  mounted () {
    this.$store.dispatch('refreshCredentials')
    this.qrScanner = new QrScanner(this.$refs.reader, result => {
      const url = new URL(result)
      this.qrScanner?.stop()
      this.scanning = false
      this.$router.push({
        name: 'oid4vc-callback',
        query: Object.fromEntries(url.searchParams)
      })
    })
  },
  beforeUnmount () {
    if (this.credentialPasswordRequestHandler) {
      window.removeEventListener('access_credential-request~' + CREDENTIALS_KEY, this.credentialPasswordRequestHandler)
    }
  },
  computed: {
    params () {
      return this.$route.query
    },
    ...mapGetters(['credentials']),
    ...mapGetters(['credentialsError'])
  },
  methods: {
    showCredentialPasswordPrompt () {
      this.credentialPasswordEventKey = CREDENTIALS_KEY
      this.credentialPassword = ''
      this.credentialPasswordError = null
      this.credentialPasswordAborted = false
      this.credentialPasswordRequestPending = true
    },
    approveCredentialPassword () {
      if (!this.credentialPassword || !this.credentialPasswordEventKey) return

      if (this.credentialPasswordRequestPending) {
        window.dispatchEvent(new CustomEvent(
          'access_credential-approval~' + this.credentialPasswordEventKey,
          { detail: this.credentialPassword }
        ))
      } else {
        this.$store.dispatch('refreshCredentials', this.credentialPassword)
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
    },
    scan () {
      this.scanning = true
      this.qrScanner?.start()
    },
    hide () {
      this.scanning = false
      this.qrScanner?.stop()
    },
    deleteCredential (credential) {
      window.addEventListener('delete_credential-request~' + credential.credential, () => {
        this.deleteConsentEventKey = credential.credential
      })
      this.$store.commit('deleteCredential', credential)
    },
    deleteConsent (eventKey) {
      window.dispatchEvent(new Event('delete_credential-approval~' + eventKey))
      this.deleteConsentEventKey = null
    },
    abortDelete (eventKey) {
      this.deleteConsentEventKey = null
    },
    importCredentials (credentials) {
      this.$store.commit('importCredentials', credentials)
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
  .home {
    padding-top: 4em;
    padding-bottom: 8em;
    .button.scan {
      position: fixed;
      bottom: 1em;
      right: 1em;
    }
    .reader-overlay {
      z-index: 500;
      position: fixed;
      top: 0;
      right: 0;
      bottom: 0;
      left: 0;
      background: rgba(0, 0, 0, 0.9);
      display: flex;
      align-items: center;
      justify-content: center;
      &.hidden {
        display: none;
      }
      #reader {
        border-radius: 1em;
        max-height: 80%;
        max-width: 80%;
        border: 7px solid white;
      }
      .close {
        position: fixed;
        top: 1em;
        right: 1em;
        color: white;
        cursor: pointer;
      }
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
  }
</style>
