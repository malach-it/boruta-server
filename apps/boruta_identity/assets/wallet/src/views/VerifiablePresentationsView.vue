<template>
  <div class="ui verifiable-presentations container">
    <h1>Verifiable presentation</h1>
    <div v-if="error">
      <div class="ui error message">
        {{ error }}
      </div>
      <router-link to="/" class="ui large fluid blue button">Back</router-link>
    </div>
    <div v-if="success">
      <div class="ui success message">
        {{ success }}
      </div>
      <router-link to="/" class="ui large fluid blue button">Back</router-link>
    </div>
    <div v-if="!error && !success">
      <Credentials :credentials="credentials" />
      <div class="ui segment">
        <form :action="redirect_uri" method="POST">
          <input type="hidden" name="vp_token" :value="vp_token" />
          <input type="hidden" name="presentation_submission" :value="presentation_submission" />
          <button class="ui violet large fluid button" type="submit">Present your credential</button>
        </form>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent } from 'vue'
import { BorutaOauth, KeyStore, extractKeys, BrowserEventHandler } from 'boruta-client'
import { storage } from '../store'

import Consent from '../components/Consent.vue'
import Credentials from '../components/Credentials.vue'

const eventHandler = new BrowserEventHandler(window)
const oauth = new BorutaOauth({
  host: window.env.BORUTA_OAUTH_BASE_URL,
  jwksPath: window.env.BORUTA_OAUTH_BASE_URL + '/openid/jwks',
  storage,
  eventHandler
})


export default defineComponent({
  name: 'VerifiablePresentationsView',
  components: { Consent, Credentials },
  data () {
    return {
      client: null,
      error: null,
      success: null,
      credentials: [],
      redirect_uri: null,
      vp_token: null,
      presentation_submission: null
    }
  },
  async mounted () {
    const keyStore = new KeyStore(eventHandler, storage)
    window.addEventListener('extract_key-request~client', () => {
      setTimeout(() => window.dispatchEvent(new Event('extract_key-approval~client')), 0)
    })
    const { did } = await keyStore.extractKeys('client')

    const client = new oauth.VerifiablePresentations({
      clientId: did,
      redirectUri: 'http://localhost:8080/preauthorized-code'
    })
    this.client = client

    client.parseVerifiablePresentationAuthorization(window.location).then((presentation) => {
      window.addEventListener('extract_key-request~vp_token~' + presentation.id, () => {
        setTimeout(() => window.dispatchEvent(new Event('extract_key-approval~vp_token~' + presentation.id)), 0)
      })
      window.addEventListener('extract_key-request~presentation_submission~' + presentation.id, () => {
        setTimeout(() => window.dispatchEvent(new Event('extract_key-approval~presentation_submission~' + presentation.id)), 0)
      })
      return client.generatePresentation(presentation)
    }).then(({ credentials, redirect_uri, vp_token, presentation_submission }) => {
      this.redirect_uri = redirect_uri
      this.vp_token = vp_token
      this.presentation_submission = presentation_submission
      this.credentials = credentials
    }).catch(response => {
      if (response.error) {
        this.error = response.error_description
      } else {
        this.success = response
      }
    })
  },
  computed: {
  },
  methods: {
  }
})
</script>

<style scoped lang="scss">
.verifiable-presentations {
  padding: 1.5em 0;
  h1 {
    padding: 1em .5em;
    text-align: center
  }
}
</style>

