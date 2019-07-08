<template>
  <div class="edit-client">
    <div class="ui container">
      <h1>Edit a client</h1>
      <div class="ui big teal segment">
        <p><strong>Client id:</strong> {{ client.id }}</p>
        <p><strong>Client secret:</strong> {{ client.secret }}</p>
        <form class="ui form" v-on:submit.prevent="updateClient()">
          <div class="field">
            <label>Redirect URI</label>
            <input type="text" v-model="client.redirect_uri" placeholder="http://redirect.uri">
          </div>
          <div class="field">
            <div class="ui toggle checkbox">
              <input type="checkbox" v-model="client.authorize_scope" placeholder="http://redirect.uri">
              <label>Authorize scopes</label>
            </div>
          </div>
          <div v-if="client.authorize_scope" class="field">
            <div v-for="(scope, index) in client.authorized_scopes" class="field" :key="index">
              <div class="ui right icon input">
                <input type="text" v-model="scope.name" placeholder="iam:a:scope">
                <i v-on:click="deleteScope(scope)" class="close icon"></i>
              </div>
            </div>
            <button v-on:click.prevent="addScope()" class="ui blue fluid button">Add a scope</button>
          </div>
          <button class="ui violet button" type="submit">Update</button>
          <router-link :to="{ name: 'client-list' }" class="ui button">Back</router-link>
        </form>
      </div>
    </div>
  </div>
</template>

<script>
import Client from '@/models/client.model'

export default {
  name: 'clients',
  // TODO look for async components
  beforeRouteEnter (to, from, next) {
    next(vm => {
      if (!vm.$auth.isAuthenticated()) {
        return vm.$router.push({ name: 'home' })
      }
      const { clientId } = vm.$route.params
      return Client.get(clientId).then((client) => {
        vm.client = client
      })
    })
  },
  data () {
    return { client: new Client() }
  },
  methods: {
    updateClient () {
      this.client.save().then(() => {
        this.$router.push({ name: 'client-list' })
      })
    },
    addScope () {
      this.client.authorized_scopes.push({})
    },
    deleteScope (scope) {
      this.client.authorized_scopes.splice(
        this.client.authorized_scopes.indexOf(scope),
        1
      )
    }
  }
}
</script>

<style scoped lang="scss">
.ui.icon.input>i.icon.close {
  cursor: pointer;
  pointer-events: all;
}
</style>
