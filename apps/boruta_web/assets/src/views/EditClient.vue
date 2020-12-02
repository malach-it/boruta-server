<template>
  <div class="edit-client">
    <div class="ui container">
      <h1>Edit a client</h1>
      <div class="ui big segment">
        <FormErrors v-if="errors" :errors="errors" />
        <div class="ui big segment">
          <p><strong>Client id:</strong> {{ client.id }}</p>
          <p><strong>Client secret:</strong> {{ client.secret }}</p>
        </div>
        <form class="ui form" v-on:submit.prevent="updateClient()">
          <div class="ui big segment">
            <div class="field">
              <label>Access token TTL (seconds)</label>
              <input type="number" v-model="client.access_token_ttl" placeholder="3600" />
            </div>
            <div class="field">
              <label>Authorization code TTL (seconds)</label>
              <input type="number" v-model="client.authorization_code_ttl" placeholder="60" />
            </div>
            <div class="field">
              <label>Redirect URIs</label>
              <div v-for="(redirectUri, index) in client.redirect_uris" class="field" :key="index">
                <div class="ui right icon input">
                  <input type="text" v-model="redirectUri.uri" placeholder="http://redirect.uri" />
                  <i v-on:click="deleteRedirectUri(redirectUri)" class="close icon"></i>
                </div>
              </div>
              <a v-on:click.prevent="addRedirectUri()" class="ui blue fluid button">Add a redirect uri</a>
            </div>
          </div>
          <div class="ui segment">
            <div class="field">
              <div class="ui toggle checkbox">
                <input type="checkbox" v-model="client.authorize_scope">
                <label>Authorize scopes</label>
              </div>
            </div>
            <ScopesField v-if="client.authorize_scope" :currentScopes="client.authorized_scopes" @delete-scope="deleteScope" @add-scope="addScope" />
          </div>
          <div class="ui big segment">
            <div class="field">
              <label>Supported grant types</label>
              <div class="ui segments">
                <div class="ui big segment" v-for="grantType in client.grantTypes" :key="grantType.label">
                  <div class="ui toggle checkbox">
                    <input type="checkbox" v-model="grantType.value">
                    <label>{{ grantType.label }}</label>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <button class="ui big violet button" type="submit">Update</button>
          <router-link :to="{ name: 'client-list' }" class="ui button">Back</router-link>
        </form>
      </div>
    </div>
  </div>
</template>

<script>
import Client from '@/models/client.model'
import Scope from '@/models/scope.model'
import ScopesField from '@/components/ScopesField.vue'
import FormErrors from '@/components/FormErrors.vue'

export default {
  name: 'clients',
  // TODO look for async components
  components: {
    ScopesField,
    FormErrors
  },
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
        console.log(errors)
        this.errors = errors
      })
    },
    addRedirectUri () {
      this.client.redirect_uris.push({})
    },
    addScope () {
      this.client.authorized_scopes.push({ model: new Scope() })
    },
    deleteRedirectUri (redirectUri) {
      this.client.redirect_uris.splice(
        this.client.redirect_uris.indexOf(redirectUri),
        1
      )
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
  .field {
    position: relative;
  }
  .ui.icon.input>i.icon.close {
    cursor: pointer;
    pointer-events: all;
    position: absolute;
  }
  .authorized-scopes-select {
    margin-right: 3em;
  }
}
</style>
