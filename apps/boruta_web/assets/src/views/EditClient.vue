<template>
  <div class="edit-client">
    <div class="ui container">
      <h1>Edit a client</h1>
      <div class="ui big teal segment">
        <div v-if="errors" class="ui error message">
          <ul>
            <li v-for="key in Object.keys(errors)"><strong>{{ key }} :</strong> {{ errors[key][0] }}</li>
          </ul>
        </div>
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
            <div v-for="(authorizedScope, index) in client.authorized_scopes" class="field" :key="index">
              <div class="ui right icon input">
                <select type="text" v-model="authorizedScope.model" class="authorized-scopes-select">
                  <option :value="scope" v-for="scope in scopeModels(authorizedScope)">{{ scope.name }}</option>
                </select>
                <i v-on:click="deleteScope(authorizedScope)" class="close icon"></i>
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
import Scope from '@/models/scope.model'

export default {
  name: 'clients',
  // TODO look for async components
  mounted () {
    const { clientId } = this.$route.params
    Client.get(clientId).then((client) => {
      this.client = client
    })
    Scope.all().then((scopes) => {
      this.scopes = scopes
    })
  },
  data () {
    return {
      errors: null,
      scopes: [],
      client: new Client()
    }
  },
  computed: {
    scopeModels () {
      const vm = this
      return function (authorizedScope) {
        return vm.scopes.map((scope) => {
          if (authorizedScope.id === scope.id) {
            return authorizedScope
          }
          return scope
        })
      }
    }
  },
  methods: {
    updateClient () {
      this.errors = null
      this.client.validate().then(() => {
        return this.client.save().then(() => {
          this.$router.push({ name: 'client-list' })
        })
      }).catch((errors) => {
        this.errors = errors
      })
    },
    addScope () {
      this.client.authorized_scopes.push({ model: new Scope() })
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
.edit-client {
  .ui.icon.input>i.icon.close {
    cursor: pointer;
    pointer-events: all;
  }
  .authorized-scopes-select {
    margin-right: 3em;
  }
}
</style>
