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
        message="You are about to use your cryptographic key"
        :event-key="keyConsentEventKey"
        @abort="abortKeyConsent"
        @consent="keyConsent"
      />
      <Consent
        message="You are about to insert a credential to your wallet"
        :event-key="insertConsentEventKey"
        @abort="abortInsertConsent"
        @consent="insertConsent"
      />
      <div class="ui segment" v-for="authorizationDetail in authorizationDetails">
        <h2>
          {{ authorizationDetail.credential_configuration_id }}
          <span class="ui brown label">{{ authorizationDetail.format }}</span>
        </h2>
        <button :disabled="fetchingCredential" class="ui fluid violet button" @click="getCredential(authorizationDetail)" :class="{ 'loading': fetchingCredential }">Get credential</button>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent } from 'vue'
import { BorutaOauth, KeyStore, extractKeys, BrowserEventHandler } from 'boruta-client'
import { storage } from '../store'
import Consent from '../components/Consent.vue'

const eventHandler = new BrowserEventHandler(window)
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
  components: { Consent },
  data () {
    return {
      client: null,
      credentialIssuer: null,
      tokenResponse: null,
      credentialId: null,
      authorizationDetails: [],
      keyConsentEventKey: null,
      insertConsentEventKey: null,
      fetchingCredential: false,
      error: null
    }
  },
  async mounted () {
    const keyStore = new KeyStore(eventHandler, storage)
    window.addEventListener('extract_key-request~client', () => {
      setTimeout(() => window.dispatchEvent(new Event('extract_key-approval~client')), 0)
    })
    const { did } = await keyStore.extractKeys('client')

    const client = new oauth.VerifiableCredentialsIssuance({
      clientId: did,
      redirectUri: 'http://localhost:8080/preauthorized-code'
    })
    this.client = client

    client.parsePreauthorizedCodeResponse(window.location).then(({ credential_issuer, preauthorized_code }) => {
      this.credentialIssuer = new URL(credential_issuer).host
      oauth.host = credential_issuer
      return client.getToken(preauthorized_code)
    }).then((tokenResponse) => {
      const { authorization_details } = tokenResponse
      this.tokenResponse = tokenResponse
      this.authorizationDetails = authorization_details
      window.addEventListener('extract_key-request~' + tokenResponse.access_token, () => {
        this.keyConsentEventKey = tokenResponse.access_token
      })
    }).catch(({ error_description }) => {
      this.error = error_description
    })
  },
  computed: {
    params () {
      return this.$route.query
    }
  },
  methods: {
    keyConsent (eventKey) {
      window.dispatchEvent(new Event('extract_key-approval~' + eventKey))
      this.keyConsentEventKey = null
    },
    insertConsent (eventKey) {
      window.dispatchEvent(new Event('insert_credential-approval~' + eventKey))
      this.keyConsentEventKey = null
    },
    abortKeyConsent () {
      this.keyConsentEventKey = null
      this.fetchingCredential = false
    },
    abortInsertConsent () {
      this.insertConsentEventKey = null
      this.fetchingCredential = false
    },
    getCredential({ credential_configuration_id, format }) {
      this.fetchingCredential = true

      this.credentialId = credential_configuration_id
      window.addEventListener('insert_credential-request~' + this.credentialId, () => {
        this.insertConsentEventKey = this.credentialId
      })
      this.client.getCredential(this.tokenResponse, credential_configuration_id, format).then((credential) => {
        this.$store.commit('refreshCredentials')
        this.$router.push({ name: 'home' })
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

