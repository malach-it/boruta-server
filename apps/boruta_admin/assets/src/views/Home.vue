<template>
  <div class="home">
    <div class="ui container">
      <div class="ui center aligned segment">
        <h2>Welcome to boruta administration</h2>
        <div class="ui three column stackable grid">
          <div class="column">
            <router-link :to="{ name: 'dashboard' }" class="ui placeholder segment">
              <div class="ui icon header">
                <i class="chart area icon"></i>
                Dashboard
              </div>
            </router-link>
          </div>
          <div class="column">
            <router-link :to="{ name: 'upstreams' }" class="ui placeholder segment">
              <div class="ui icon header">
                <i class="server icon"></i>
                Upstreams
              </div>
            </router-link>
          </div>
          <div class="column">
            <router-link :to="{ name: 'clients' }" class="ui placeholder segment">
              <div class="ui icon header">
                <i class="certificate icon"></i>
                Clients
              </div>
            </router-link>
          </div>
          <div class="column">
            <router-link :to="{ name: 'identity-providers' }" class="ui placeholder segment">
              <div class="ui icon header">
                <i class="users icon"></i>
                Identity providers
              </div>
            </router-link>
          </div>
          <div class="column">
            <router-link :to="{ name: 'scopes' }" class="ui placeholder segment">
              <div class="ui icon header">
                <i class="cogs icon"></i>
                Scopes
              </div>
            </router-link>
          </div>
          <div class="column">
            <router-link :to="{ name: 'configuration' }" class="ui placeholder segment">
              <div class="ui icon header">
                <i class="columns icon"></i>
                Configuration
              </div>
            </router-link>
          </div>
        </div>
      </div>
      <div class="ui center aligned segment">
        <div class="ui segment">
          <router-link class="ui fluid blue button" :to="{ name: 'configuration-file-upload', params: { type: 'example-configuration-file' } }">Load example configuration</router-link>
        </div>
        <div class="ui info message">
          <h2>Example decentralized identity flow</h2>
          <p>Use integrated <a target="_blank" :href="walletUrl">web wallet</a> to request, store, and present verifiable credentials</p>
          <p>In order to execute example decentralized identity flows, you must generate client did first - <router-link :to="{ name: 'edit-client', params: { clientId: '00000000-0000-0000-0000-000000000001' } }">client configuration</router-link></p>
          <hr />
          <div class="ui form segment">
            <h3>Verifiable credential issuance</h3>
            <div class="field">
              <label>Select a wallet</label>
              <select v-model="issuanceRedirectUri">
                <option :value="walletRedirectUri + '/preauthorized-code'">Internal wallet</option>
                <option value="openid-credential-offer://">Mobile wallet</option>
              </select>
            </div>
            <a class="ui fluid blue button" target="_blank" :href="preauthorizeUrl">Trigger example pre-authorized code flow with associated boruta wallet (load example data first)</a>
          </div>
          <div class="ui form segment">
            <h3>Verifiable credential presentation</h3>
            <div class="field">
              <label>Select a wallet</label>
              <select v-model="presentationRedirectUri">
                <option :value="walletRedirectUri + '/verifiable-presentation'">Internal wallet</option>
                <option value="openid4vp://">Mobile wallet</option>
              </select>
            </div>
            <a class="ui fluid blue button" target="_blank" :href="presentationUrl">Trigger example presentation with associated boruta wallet (issue example credential first)</a>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'home',
  data () {
    return {
      walletRedirectUri: `${window.env.BORUTA_OAUTH_BASE_URL}/accounts/wallet`,
      issuanceRedirectUri: `${window.env.BORUTA_OAUTH_BASE_URL}/accounts/wallet/preauthorized-code`,
      presentationRedirectUri: `${window.env.BORUTA_OAUTH_BASE_URL}/accounts/wallet/verifiable-presentation`
    }
  },
  computed: {
    walletUrl () {
     return window.env.BORUTA_OAUTH_BASE_URL +
      '/accounts/wallet'
    },
    presentationUrl () {
      if (this.presentationRedirectUri === this.walletRedirectUri) {
        return window.env.BORUTA_OAUTH_BASE_URL +
          `/oauth/authorize?client_id=00000000-0000-0000-0000-000000000001&redirect_uri=${this.presentationRedirectUri}&scope=BorutaCredentialJwtVc&response_type=code&client_metadata={}&prompt=login`
      } else {
        return window.env.BORUTA_OAUTH_BASE_URL +
          `/oauth/authorize?client_id=00000000-0000-0000-0000-000000000001&redirect_uri=${this.presentationRedirectUri}&scope=BorutaCredentialJwtVc&response_type=vp_token&client_metadata={}&prompt=login`
      }
    },
    preauthorizeUrl () {
     return window.env.BORUTA_OAUTH_BASE_URL +
      `/oauth/authorize?client_id=00000000-0000-0000-0000-000000000001&redirect_uri=${this.issuanceRedirectUri}&response_type=urn%3Aietf%3Aparams%3Aoauth%3Aresponse-type%3Apre-authorized_code&state=qrm0c4xm&prompt=login`
    }
  }
}
</script>

<style scoped lang="scss">
</style>
