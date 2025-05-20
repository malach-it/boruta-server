<template>
  <div class="ui verifiable-presentations container">
    <h1>Verifiable presentation</h1>
      <Consent
        message="You are about to add a new cryptographic key"
        :event-key="generateKeyConsentEventKey"
        @abort="abortKeyConsent"
        @consent="generateKeyConsent"
      />
    <div class="ui segment" v-if="error">
      <div class="ui placeholder segment">
        <div class="ui header">
          {{ error }}
        </div>
      </div>
      <router-link to="/" class="ui large fluid blue button">Back</router-link>
    </div>
    <KeySelect v-if="keyConsentEventKey && !error" @selected="selectKey" @abort="keyConsentEventKey = null"/>
    <div class="ui segment" v-if="!success && presentation_submission && !credentials.length">
      <div class="ui placeholder segment">
        <div class="ui header">
          No credential match the presentation
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
    <div v-if="credentials.length">
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
import { BorutaOauth, KeyStore, CustomEventHandler } from 'boruta-client'
import { storage } from '../store'

import Consent from '../components/Consent.vue'
import Credentials from '../components/Credentials.vue'
import KeySelect from '../components/KeySelect.vue'

const eventHandler = new CustomEventHandler(window)
const oauth = new BorutaOauth({
  host: window.env.BORUTA_OAUTH_BASE_URL,
  jwksPath: window.env.BORUTA_OAUTH_BASE_URL + '/openid/jwks',
  storage,
  eventHandler
})


export default defineComponent({
  name: 'VerifiablePresentationsView',
  components: { Consent, Credentials, KeySelect },
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
      keyConsentEventKey: null,
      generateKeyConsentEventKey: null,
      keyIdentifier: null
    }
  },
  async mounted () {
    const client = new oauth.VerifiablePresentations({
      clientId: window.env.BORUTA_OAUTH_BASE_URL + '/accounts/wallet',
      redirectUri: window.env.BORUTA_OAUTH_BASE_URL + '/accounts/wallet/verifiable-presentation'
    })

    this.client = client
    client.parseVerifiablePresentationAuthorization(window.location).then((presentation) => {
      this.presentation = presentation

      eventHandler.listen('extract_key-request', this.presentation.id, () => {
        this.keyConsentEventKey = this.presentation.id
      })
      eventHandler.listen('generate_key-request', '', () => {
        this.generateKeyConsentEventKey = this.presentation.id
      })

      return presentation
    }).then(this.client.generatePresentation.bind(this.client))
      .then(({ credentials, redirect_uri, vp_token, presentation_submission }) => {
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
  methods: {
    async selectKey (identifier) {
      this.keyConsentEventKey = null
      eventHandler.dispatch('extract_key-approval', this.presentation.id, identifier)
    },
    deleteCredential (credential) {
      const credentials = this.credentials.map(e => e)
      credentials.splice(this.credentials.indexOf(credential), 1)

      this.client.generatePresentation(this.presentation, credentials)
        .then(({ credentials, redirect_uri, vp_token, presentation_submission }) => {
          this.credentials = credentials

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
    generateKeyConsent (eventKey) {
      eventHandler.dispatch('generate_key-approval', '')
      this.generateKeyConsentEventKey = null
    },
    abortKeyConsent () {
      this.generateKeyConsentEventKey = null
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

