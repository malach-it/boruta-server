<template>
  <div class="ui verifiable-credentials-issuance container">
    <h1>{{ credentialIssuer }} offer those credentials</h1>
    <div class="ui error message" v-show="error">
      {{ error }}
    </div>
    <div class="ui center aligned segment" v-if="displayConsent">
      <h2>You are about to use your cryptographic key</h2>
      <div class="ui fluid two buttons">
        <button class="ui orange button" @click="abort()">Abort</button>
        <button class="ui green button" @click="consent()">Proceed</button>
      </div>
    </div>
    <div class="ui center aligned segment" v-if="displayInsert">
      <h2>You are about to insert a credential to your wallet</h2>
      <div class="ui fluid two buttons">
        <button class="ui orange button" @click="abort()">Abort</button>
        <button class="ui green button" @click="insert()">Proceed</button>
      </div>
    </div>
    <div class="ui segments">
      <div class="ui segment" v-for="authorizationDetail in authorizationDetails">
        <h2>
          {{ authorizationDetail.credential_configuration_id }}
          <span class="ui orange label">{{ authorizationDetail.format }}</span>
        </h2>
        <button :disabled="fetchingCredential" class="ui fluid violet button" @click="getCredential(authorizationDetail)" :class="{ 'loading': fetchingCredential }">Get credential</button>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent } from 'vue'
import { BorutaOauth, KeyStore, extractKeys } from 'boruta-client'

const oauth = new BorutaOauth({
  host: window.env.BORUTA_OAUTH_BASE_URL,
  tokenPath: '/oauth/token',
  credentialPath: '/openid/credential',
  window: window
})


export default defineComponent({
  name: 'VerifiableCredentialsIssuanceView',
  components: {},
  data () {
    return {
      client: null,
      credentialIssuer: null,
      tokenResponse: null,
      credentialId: null,
      authorizationDetails: [],
      displayConsent: null,
      displayInsert: false,
      fetchingCredential: false,
      error: null
    }
  },
  async mounted () {
    const keyStore = new KeyStore(window)
    window.addEventListener('extract_key-request~client', () => {
      this.displayConsent = 'client'
    })
    const { did } = await extractKeys(keyStore, 'client')

    const client = new oauth.VerifiableCredentialsIssuance({
      clientId: did,
      redirectUri: 'http://localhost:8080/preauthorized-code'
    })
    this.client = client

    client.parsePreauthorizedCodeResponse(window.location).then(({ credential_issuer, preauthorized_code }) => {
      this.credentialIssuer = credential_issuer
      oauth.host = credential_issuer
      return client.getToken(preauthorized_code)
    }).then((tokenResponse) => {
      const { authorization_details } = tokenResponse
      this.tokenResponse = tokenResponse
      this.authorizationDetails = authorization_details
      window.addEventListener('extract_key-request~' + tokenResponse.access_token, () => {
        this.displayConsent = tokenResponse.access_token
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
    consent () {
      window.dispatchEvent(new Event('extract_key-approval~' + this.displayConsent))
      this.displayConsent = false
    },
    abort () {
      this.fetchingCredential = false
      this.displayConsent = false
      this.displayInsert = false
    },
    insert () {
      window.dispatchEvent(new Event('insert_credential-approval~' + this.credentialId))
      this.displayConsent = false
    },
    getCredential({ credential_configuration_id, format }) {
      this.fetchingCredential = true

      this.credentialId = credential_configuration_id
      window.addEventListener('insert_credential-request~' + this.credentialId, () => {
        this.displayInsert = true
      })
      this.client.getCredential(this.tokenResponse, credential_configuration_id, format).then((credential) => {
        this.$store.commit('addCredential', {
          credential_configuration_id,
          ...credential
        })
        this.$router.push({ name: 'home' })
      })
    }
  }
})
</script>

<style scoped lang="scss">
.verifiable-credentials-issuance {
  h1 {
    padding: 1em .5em;
    text-align: center
  }
}
</style>

