<template>
  <div class="home">
    <Consent
      message="You are about to remove a credential from your wallet"
      :event-key="deleteConsentEventKey"
      @abort="abortDelete"
      @consent="deleteConsent"
    />
    <Credentials :credentials="credentials" @deleteCredential="deleteCredential" />
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

export default defineComponent({
  name: 'HomeView',
  components: { Credentials, Consent },
  data () {
    return {
      qrScanner: null,
      code: '',
      scanning: false,
      deleteConsentEventKey: null
    }
  },
  mounted () {
    this.qrScanner = new QrScanner(this.$refs.reader, result => {
      const url = new URL(result)
      this.qrScanner?.stop()
      this.scanning = false
      this.$router.push(url.pathname + url.search)
    })
  },
  computed: {
    params () {
      return this.$route.query
    },
    ...mapGetters(['credentials'])
  },
  methods: {
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
  }
</style>
