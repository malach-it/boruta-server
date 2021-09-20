<template>
  <div class="edit-client">
    <h1>Edit a client</h1>
    <div class="ui container">
      <div class="ui large segment">
        <FormErrors v-if="errors" :errors="errors" />
        <div class="ui large segment">
          <div class="ui attribute list">
            <div class="item">
              <span class="header">Client ID</span>
              <span class="description">{{ client.id }}</span>
            </div>
            <div class="item">
              <span class="header">Client secret</span>
              <span class="description">{{ client.secret }}</span>
            </div>
          </div>
        </div>
        <form class="ui form" v-on:submit.prevent="updateClient()">
          <div class="ui large segment">
            <div class="field">
              <label>Name</label>
              <input v-model="client.name" placeholder="Super client" />
            </div>
            <div class="field">
              <label>Access token TTL (seconds)</label>
              <input type="number" v-model="client.access_token_ttl" placeholder="3600" />
            </div>
            <div class="field">
              <label>Authorization code TTL (seconds)</label>
              <input type="number" v-model="client.authorization_code_ttl" placeholder="60" />
            </div>
            <div class="field">
              <label>Refresh token TTL (seconds)</label>
              <input type="number" v-model="client.refresh_token_ttl" placeholder="2592000" />
            </div>
            <div class="field">
              <label>ID token TTL (seconds)</label>
              <input type="number" v-model="client.id_token_ttl" placeholder="3600" />
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
          <div class="ui segments">
            <div class="ui large segment">
              <div class="ui toggle checkbox">
                <input type="checkbox" v-model="client.pkce">
                <label>PKCE enabled</label>
              </div>
            </div>
          </div>
          <div class="ui large segment">
            <div class="field">
              <label>Supported grant types</label>
              <div class="ui segments">
                <div class="ui large segment" v-for="grantType in client.grantTypes" :key="grantType.label">
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
    addRedirectUri () {
      this.client.redirect_uris.push({})
    },
    deleteRedirectUri (redirectUri) {
      this.client.redirect_uris.splice(
        this.client.redirect_uris.indexOf(redirectUri),
        1
      )
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
