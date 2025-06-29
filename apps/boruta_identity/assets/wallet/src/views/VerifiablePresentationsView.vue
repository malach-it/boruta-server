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
    <div class="ui segment" v-if="id_token">
      <form method="POST" :action="redirect_uri" class="ui large segment">
        <input type="hidden" name="id_token" :value="id_token" />
        <button class="ui fluid blue button" type="submit">Present your cryptographic key</button>
      </form>
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
      host: null,
      error: null,
      success: null,
      presentation: null,
      credentials: [],
      id_token: null,
      redirect_uri: null,
      vp_token: null,
      requestedKey: null,
      presentation_submission: null,
      keyConsentEventKey: null,
      generateKeyConsentEventKey: null,
      keyIdentifier: null
    }
  },
  async mounted () {
    if (this.$route.query.error) {
      this.error = this.$route.query.error_description
    }

    if (this.$route.query.code) {
      this.success = 'Your credential has successfully been presented.'
    }

    if (this.$route.query.response_type == 'vp_token') {
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
    }

    if (this.$route.query.response_type == 'id_token') {
      eventHandler.listen('extract_key-request', this.$route.query.client_id, () => {
        this.keyConsentEventKey = this.$route.query.client_id
      })
      eventHandler.listen('generate_key-request', '', () => {
        this.generateKeyConsentEventKey = this.$route.query.client_id
      })

      const client = new oauth.Siopv2({ clientId: '', redirectUri: '' })
      client.parseSiopv2Response(window.location).then(({ id_token, redirect_uri }) => {
        localStorage.setItem('keySelection', Date.now() + '~' + this.selectedKey)
        this.id_token = id_token
        this.redirect_uri = redirect_uri
      }).catch(({ error_description }) => {
        this.error = error_description
      })
    }
  },
  methods: {
    async selectKey (identifier) {
      this.selectedKey = identifier
      eventHandler.dispatch('extract_key-approval', this.keyConsentEventKey, identifier)
      this.keyConsentEventKey = null
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

