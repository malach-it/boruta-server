<template>
  <div class="ui verifiable-presentations container">
    <h1 v-if="mode == 'oid4vp'">Verifiable presentation</h1>
    <h1 v-if="mode == 'siopv2'">Key presentation</h1>
      <Consent
        message="You are about to add a new cryptographic key"
        :event-key="generateKeyConsentEventKey"
        @abort="abortKeyConsent"
        @consent="generateKeyConsent"
      />
    <div class="credential-password" v-if="credentialPasswordEventKey">
      <div class="ui center aligned segment">
        <h2>Unlock credentials</h2>
        <div class="ui error message" v-if="credentialPasswordError">{{ credentialPasswordError }}</div>
        <div class="ui form">
          <input
            type="password"
            v-model="credentialPassword"
            placeholder="Credentials password"
            autocomplete="current-password"
            @keyup.enter="approveCredentialPassword"
          />
        </div>
        <div class="ui fluid two buttons">
          <button class="ui orange button" @click="abortCredentialPassword">Abort</button>
          <button :disabled="!credentialPassword" class="ui green button" @click="approveCredentialPassword">Unlock</button>
        </div>
      </div>
    </div>
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
      <div v-for="input_descriptor of presentation_definition.input_descriptors">
        <div v-for="field of input_descriptor.constraints.fields">
          <p :key="field.path" v-if="field.id" class="ui purpose segment">
            <strong>{{ field.id }}</strong> {{ field.purpose }}
          </p>
        </div>
      </div>
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
      <form method="POST" :action="redirect_uri" class="ui form large segment">
        <input type="hidden" name="id_token" :value="id_token" />
        <input type="hidden" name="metadata_policy" :value="metadata_policy">
        <button class="ui fluid blue button" type="submit">Present your cryptographic key</button>
      </form>
    </div>
    <div class="issuance" v-if="mode == 'oid4vci'">
      <VerifiableCredentialsIssuanceView />
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent } from 'vue'
import { BorutaOauth, CustomEventHandler } from 'boruta-client'
import { storage } from '../store'
import VerifiableCredentialsIssuanceView from './VerifiableCredentialsIssuanceView.vue'

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

const CREDENTIALS_KEY = 'boruta-client_credentials'

export default defineComponent({
  name: 'Oid4vcCallbackView',
  components: { Consent, Credentials, KeySelect, VerifiableCredentialsIssuanceView },
  data () {
    return {
      mode: null,
      client: null,
      host: null,
      error: null,
      success: null,
      presentation: null,
      credentials: [],
      id_token: null,
      metadata_policy: "{}",
      redirect_uri: null,
      vp_token: null,
      requestedKey: null,
      presentation_definition: null,
      presentation_submission: null,
      keyConsentEventKey: null,
      generateKeyConsentEventKey: null,
      keyIdentifier: null,
      selectedKeyPassword: null,
      credentialPasswordEventKey: null,
      credentialPassword: '',
      credentialPasswordError: null,
      credentialPasswordRequestPending: false
    }
  },
  async mounted () {
    this.parseLocation()
  },
  methods: {
    async parseLocation () {
      this.mode = null

      if (this.$route.query.error) {
        this.mode = 'oid4vc_error'
        this.error = this.$route.query.error_description
      }

      if (this.$route.query.code) {
        this.mode = 'presentation_success'
        this.success = 'Your credential has successfully been presented.'
      }

      if (this.$route.query.response_type == 'vp_token') {
        this.mode = 'oid4vp'
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
          eventHandler.listen('access_credential-request', CREDENTIALS_KEY, () => {
            this.credentialPasswordEventKey = CREDENTIALS_KEY
            this.credentialPassword = ''
            this.credentialPasswordError = null
            this.credentialPasswordRequestPending = true
          })

          this.presentation_definition = presentation.presentation_definition

          return presentation
        }).then(this.client.generatePresentation.bind(this.client))
          .then(this.applyPresentationResult)
          .catch(this.handlePresentationError)
      }

      if (this.$route.query.response_type == 'id_token') {
        this.mode = 'siopv2'
        eventHandler.listen('extract_key-request', this.$route.query.client_id, () => {
          this.keyConsentEventKey = this.$route.query.client_id
        })
        eventHandler.listen('generate_key-request', '', () => {
          this.generateKeyConsentEventKey = this.$route.query.client_id
        })

        const client = new oauth.Siopv2({ clientId: '', redirectUri: '' })
        client.parseSiopv2Response(window.location).then(({ id_token, redirect_uri }) => {
          const keySelection = localStorage.getItem('keySelection') || ''
          localStorage.setItem('keySelection', keySelection + '|' + Date.now() + '~' + this.selectedKey)
          this.id_token = id_token
          this.redirect_uri = redirect_uri
        }).catch(({ error_description }) => {
          this.error = error_description
        })
      }

      if (this.$route.query.credential_offer) {
        this.mode = 'oid4vci'
      }

      if (!this.mode) {
        this.$router.push({ name: 'home' })
      }
    },
    async selectKey (identifier, did, password) {
      this.selectedKey = identifier
      this.selectedKeyPassword = password
      eventHandler.dispatch('extract_key-approval', this.keyConsentEventKey, { identifier, password })
      this.keyConsentEventKey = null
    },
    async approveCredentialPassword () {
      if (!this.credentialPassword || !this.credentialPasswordEventKey) return

      const password = this.credentialPassword

      if (this.credentialPasswordRequestPending) {
        eventHandler.dispatch('access_credential-approval', this.credentialPasswordEventKey, password)
      } else {
        try {
          const credentials = await this.client.credentialsStore.credentials(password)
          const result = await this.client.generatePresentation(this.presentation, credentials)
          this.applyPresentationResult(result)
        } catch (error) {
          this.credentialPassword = ''
          this.credentialPasswordError = 'Unable to unlock credentials.'
          return
        }
      }

      this.credentialPasswordEventKey = null
      this.credentialPassword = ''
      this.credentialPasswordError = null
      this.credentialPasswordRequestPending = false
    },
    abortCredentialPassword () {
      if (this.credentialPasswordEventKey && this.credentialPasswordRequestPending) {
        eventHandler.dispatch('access_credential-approval', this.credentialPasswordEventKey, null)
      }

      this.credentialPasswordEventKey = null
      this.credentialPassword = ''
      this.credentialPasswordError = null
      this.credentialPasswordRequestPending = false
    },
    applyPresentationResult ({ credentials, redirect_uri, vp_token, presentation_submission }) {
      const keySelection = localStorage.getItem('keySelection') || ''
      localStorage.setItem('keySelection', keySelection + '|' + Date.now() + '~' + this.selectedKey)
      this.redirect_uri = redirect_uri
      this.host = new URL(redirect_uri).host
      this.vp_token = vp_token
      this.presentation_submission = presentation_submission
      this.credentials = credentials
    },
    handlePresentationError (response) {
      if (response?.error) {
        this.error = response.error_description
        return
      }

      if (this.mode == 'oid4vp') {
        this.credentialPasswordEventKey = CREDENTIALS_KEY
        this.credentialPassword = ''
        this.credentialPasswordError = 'Unable to unlock credentials.'
        this.credentialPasswordRequestPending = false
        return
      }

      this.success = response
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
      eventHandler.dispatch('generate_key-approval', '', { password: this.selectedKeyPassword })
      this.generateKeyConsentEventKey = null
    },
    abortKeyConsent () {
      this.generateKeyConsentEventKey = null
      this.selectedKeyPassword = null
    },
  },
  watch: {
    '$route.query': {
      handler: function () { this.parseLocation() },
      deep: true
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
  .purpose {
    margin-bottom: 1.5em;
  }
}
</style>
