<template>
  <div class="ui verifiable-credentials-issuance container">
    <div class="ui segment" v-if="error">
      <div class="ui placeholder segment">
        <div class="ui header">
          {{ error }}
        </div>
      </div>
      <router-link to="/" class="ui large fluid blue button">Back</router-link>
    </div>
    <div v-else>
      <h1 v-if="credentialIssuer">{{ credentialIssuer }} offer those credentials</h1>
      <Consent
        message="You are about to add a new cryptographic key"
        :event-key="generateKeyConsentEventKey"
        @abort="abortKeyConsent"
        @consent="generateKeyConsent"
      />
      <Consent
        message="You are about to insert a credential to your wallet"
        :event-key="insertConsentEventKey"
        @abort="abortInsertConsent"
        @consent="insertConsent"
      />
      <KeySelect v-if="keyConsentEventKey && !error" @selected="selectKey" @abort="keyConsentEventKey = null"/>
      <div class="ui segment" v-for="authorizationDetail in authorizationDetails">
        <h2>
          {{ authorizationDetail.credential_configuration_id }}
          <span class="ui brown label">{{ authorizationDetail.format }}</span>
        </h2>
        <button :disabled="fetchingCredential" class="ui fluid violet button" @click="getCredential(authorizationDetail)" :class="{ 'loading': fetchingCredential }" v-if="tokenResponse">Get credential</button>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent } from 'vue'
import { BorutaOauth, KeyStore, CustomEventHandler } from 'boruta-client'
import { storage } from '../store'
import Consent from '../components/Consent.vue'
import KeySelect from '../components/KeySelect.vue'

const eventHandler = new CustomEventHandler()
const oauth = new BorutaOauth({
  host: window.env.BORUTA_OAUTH_BASE_URL,
  tokenPath: '/oauth/token',
  credentialPath: '/openid/credential',
  window,
  storage,
  eventHandler
})


export default defineComponent({
  name: 'VerifiableCredentialsIssuanceView',
  components: { KeySelect, Consent },
  data () {
    const keyStore = new KeyStore(eventHandler, storage)
    return {
      keyStore,
      client: null,
      keys: [],
      keyIdentifier: null,
      newIdentifier: null,
      credentialIssuer: null,
      credentialId: null,
      tokenResponse: null,
      authorizationDetails: [],
      keyConsentEventKey: null,
      generateKeyConsentEventKey: null,
      insertConsentEventKey: null,
      fetchingCredential: false,
      error: null
    }
  },
  computed: {
    params () {
      return this.$route.query
    }
  },
  async mounted () {
    const client = new oauth.VerifiableCredentialsIssuance({
      clientId: '00000000-0000-0000-0000-000000000001',
      redirectUri: window.env.BORUTA_OAUTH_BASE_URL + '/accounts/wallet/preauthorized-code'
    })
    this.client = client

    client.parsePreauthorizedCodeResponse(window.location).then(({ credential_issuer, preauthorized_code }) => {
      oauth.host = credential_issuer
      return client.getToken(preauthorized_code)
    }).then((tokenResponse) => {
      this.credentialIssuer = new URL(oauth.host).host

      const { authorization_details } = tokenResponse
      this.tokenResponse = tokenResponse
      this.authorizationDetails = authorization_details
    }).catch(({ error_description }) => {
      this.error = error_description
    })
  },
  methods: {
    async selectKey (identifier) {
      this.keyConsentEventKey = null
      eventHandler.dispatch('extract_key-approval', this.credentialId, identifier)
    },
    insertConsent (eventKey) {
      eventHandler.dispatch('insert_credential-approval', eventKey)
      this.keyConsentEventKey = null
    },
    generateKeyConsent (eventKey) {
      eventHandler.dispatch('generate_key-approval', '')
      this.generateKeyConsentEventKey = null
    },
    abortKeyConsent () {
      this.keyConsentEventKey = null
      this.generateKeyConsentEventKey = null
      this.fetchingCredential = false
      this.keyIdentifier = null
    },
    abortInsertConsent () {
      this.insertConsentEventKey = null
      this.fetchingCredential = false
    },
    getCredential({ credential_configuration_id, format }) {
      this.fetchingCredential = true

      this.credentialId = credential_configuration_id
      eventHandler.listen('extract_key-request', this.credentialId, () => {
        this.keyConsentEventKey = this.credentialId
      })
      eventHandler.listen('generate_key-request', '', () => {
        this.generateKeyConsentEventKey = this.credentialId
      })
      eventHandler.listen('insert_credential-request', this.credentialId, () => {
        this.insertConsentEventKey = this.credentialId
      })
      this.client.getCredential(this.tokenResponse, credential_configuration_id, format).then((credential) => {
        this.$store.commit('refreshCredentials')
        this.$router.push({ name: 'home' })
      }).catch(({ error_description }) => {
        this.error = error_description
      })
    }
  }
})
</script>

<style scoped lang="scss">
.verifiable-credentials-issuance {
  padding: 1.5em 0;
  h1 {
    padding: 1em .5em;
    text-align: center
  }
}
</style>

