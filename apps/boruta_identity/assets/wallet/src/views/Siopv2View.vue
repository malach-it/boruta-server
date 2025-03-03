<template>
  <div class="ui siopv2 container">
    <form method="POST" :action="redirect_uri">
      <input type="hidden" name="id_token" :value="id_token" />
      <button class="ui blue button" type="submit" v-show="redirect_uri">Present your credentials</button>
      </form>
      <div class="ui info message" v-show="params.code">Successful presentation</div>
  </div>
</template>

<script lang="ts">
import { defineComponent } from 'vue'
import { BorutaOauth } from 'boruta-client'

const oauth = new BorutaOauth({
  host: 'https://oauth.boruta.patatoid.fr',
  jwksPath: '/openid/jwks',
  window: window
})

const client = new oauth.Siopv2({ clientId: '', redirectUri: '' })

export default defineComponent({
  name: 'Siopv2View',
  components: {},
  data () {
    return {
      redirect_uri: null,
      id_token: null
    }
  },
  mounted () {
    client.parseSiopv2Response(window.location).then(({ id_token, redirect_uri }) => {
      this.id_token = id_token
      this.redirect_uri = redirect_uri
    }).catch(console.log)
  },
  computed: {
    params () {
      return this.$route.query
    }
  },
  methods: {
  }
})
</script>

<style scoped lang="scss">
  .home {
    text-align: center;
    .code {
      overflow-wrap: break-word;
    }
    .reader-overlay {
      z-index: 500;
      position: fixed;
      top: 0;
      height: 100vh;
      width: 100vw;
      background: rgba(0, 0, 0, 0.7);
      display: flex;
      align-items: center;
      justify-content: center;
      #reader {
        height: 70vh;
        width: 70vw;
      }
    }
  }
</style>
