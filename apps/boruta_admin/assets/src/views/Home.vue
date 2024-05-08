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
        <div class="ui segment">
          <router-link class="ui fluid blue button" :to="{ name: 'configuration-file-upload', params: { type: 'example-configuration-file' } }">Load example configuration</router-link>
        </div>
        <div class="ui segment">
          <a class="ui fluid blue button" :href="preauthorizeUrl">Trigger example pre-authorized code flow (load example data first)</a>
        </div>

      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'home',
  computed: {
    preauthorizeUrl () {
     return window.env.BORUTA_ADMIN_OAUTH_BASE_URL +
      "/oauth/authorize?client_id=00000000-0000-0000-0000-000000000001&redirect_uri=https%3A%2F%2Fredirect.uri.boruta&scope=BorutaCredentialSdJwt&response_type=urn%3Aietf%3Aparams%3Aoauth%3Aresponse-type%3Apre-authorized_code&state=qrm0c4xm&prompt=login"
    }
  }
}
</script>

<style scoped lang="scss">
</style>
