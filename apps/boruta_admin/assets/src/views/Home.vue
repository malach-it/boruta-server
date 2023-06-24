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
    </div>
  </div>
</template>

<script>
export default {
  name: 'home'
}
</script>

<style scoped lang="scss">
</style>
