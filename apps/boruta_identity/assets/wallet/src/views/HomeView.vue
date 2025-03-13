<template>
  <div class="home">
    <Credentials :credentials="credentials" />
    <div class="reader-overlay" :class="{ 'hidden': !scanning }">
      <i class="ui large close icon" @click="hide()"></i>
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

export default defineComponent({
  name: 'HomeView',
  components: { Credentials },
  data () {
    return {
      qrScanner: null,
      code: '',
      scanning: false
    }
  },
  mounted () {
    this.qrScanner = new QrScanner(this.$refs.reader, result => {
      const url = new URL(result)
      this.qrScanner?.stop()
      this.scanning = false
      this.$router.push('/preauthorized-code' + url.search)
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
