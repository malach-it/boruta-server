<template>
  <div class="client-form">
    <div class="ui large segment">
      <FormErrors v-if="client.errors" :errors="client.errors" />
      <form class="ui form" v-on:submit.prevent="submit()">
        <h3>General configuration</h3>
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
        <h3>Authorization</h3>
        <div class="field">
          <div class="ui toggle checkbox">
            <input type="checkbox" v-model="client.authorize_scope">
            <label>Authorize scopes</label>
          </div>
        </div>
        <ScopesField v-if="client.authorize_scope" :currentScopes="client.authorized_scopes" @delete-scope="deleteScope" @add-scope="addScope" />
        <h3>PKCE configuration</h3>
        <div class="ui large segment">
          <div class="ui toggle checkbox">
            <input type="checkbox" v-model="client.pkce">
            <label>PKCE enabled</label>
          </div>
        </div>
        <div class="ui large segment">
          <div class="ui toggle checkbox">
            <input type="checkbox" v-model="client.public_refresh_token">
            <label>Public refresh token</label>
          </div>
        </div>
        <div class="ui large segment">
          <div class="ui toggle checkbox">
            <input type="checkbox" v-model="client.public_revoke">
            <label>Public revoke</label>
          </div>
        </div>
        <div class="field">
          <h3>Supported grant types</h3>
          <div class="ui segments">
            <div class="ui large segment" v-for="grantType in client.grantTypes" :key="grantType.label">
              <div class="ui toggle checkbox">
                <input type="checkbox" v-model="grantType.value">
                <label>{{ grantType.label }}</label>
              </div>
            </div>
          </div>
        </div>
        <hr />
        <button class="ui large right floated violet button" type="submit">{{ action }}</button>
        <a v-on:click="back()" class="ui large button">Back</a>
      </form>
    </div>
  </div>
</template>

<script>
import Scope from '@/models/scope.model'
import ScopesField from '@/components/Forms/ScopesField.vue'
import FormErrors from '@/components/Forms/FormErrors.vue'

export default {
  name: 'client-form',
  props: ['client', 'action'],
  components: {
    ScopesField,
    FormErrors
  },
  mounted () {
    Scope.all().then((scopes) => {
      this.scopes = scopes
    })
  },
  data () {
    return {
      scopes: []
    }
  },
  methods: {
    submit () {
      this.$emit('submit', this.client)
    },
    back () {
      this.$emit('back')
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
.client-form {
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