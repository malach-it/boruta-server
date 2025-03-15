<template>
  <div class="ui verifiable-presentations container">
    <h1>Verifiable presentation</h1>
    <Consent
      message="You are about to use your cryptographic key"
      :event-key="keyConsentEventKey"
      @abort="abortKeyConsent"
      @consent="keyConsent"
    />
    <div class="ui segment" v-if="error">
      <div class="ui placeholder segment">
        <div class="ui header">
          {{ error }}
        </div>
      </div>
      <router-link to="/" class="ui large fluid blue button">Back</router-link>
    </div>
    <div class="ui segment" v-if="success">
      <div class="ui placeholder segment">
        <div class="ui header">
          {{ success }}
        </div>
      </div>
      <router-link to="/" class="ui large fluid blue button">Back</router-link>
    </div>
    <div v-if="!error && !success">
      <Credentials :credentials="credentials" delete-label="Unselect" @deleteCredential="deleteCredential" />
      <div class="ui segment">
        <form :action="redirect_uri" method="POST">
          <input type="hidden" name="vp_token" :value="vp_token" />
          <input type="hidden" name="presentation_submission" :value="presentation_submission" />
          <button class="ui violet large fluid button" type="submit">Present your credential to {{ host }}</button>
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
      hots: null,
      error: null,
      success: null,
      presentation: null,
      credentials: [],
      redirect_uri: null,
      vp_token: null,
      presentation_submission: null,
      keyConsentEventKey: null
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
      this.presentation = presentation
      const eventKey = 'vp_token~' + presentation.id

      window.addEventListener('extract_key-request~' + eventKey, () => {
        this.keyConsentEventKey = eventKey
      })

      return client.generatePresentation(presentation)
    }).then(({ credentials, redirect_uri, vp_token, presentation_submission }) => {
      this.redirect_uri = redirect_uri
      this.host = new URL(redirect_uri).host
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
    deleteCredential (credential) {
      this.credentials.splice(this.credentials.indexOf(credential), 1)

      this.client.generatePresentation(this.presentation, this.credentials)
        .then(({ credentials, redirect_uri, vp_token, presentation_submission }) => {
          console.log('changed')
          this.redirect_uri = redirect_uri
          this.host = new URL(redirect_uri).host
          this.vp_token = vp_token
          this.presentation_submission = presentation_submission
          this.credentials = credentials
        }).catch(response => {
          if (response.error) {
            this.error = response.error_description
          }
        })
    },
    keyConsent () {
      window.dispatchEvent(new Event('extract_key-approval~' + this.keyConsentEventKey))
      this.keyConsentEventKey = null
    },
    abortConsent () {
      this.keyConsentEventKey = null
    }
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

