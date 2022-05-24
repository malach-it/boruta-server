<template>
  <div class="client-form">
    <div class="ui large segment">
      <FormErrors v-if="client.errors" :errors="client.errors" />
      <form class="ui form" @submit.prevent="submit">
        <h3>General configuration</h3>
        <div class="field" :class="{ 'error': client.errors?.name }">
          <label>Name</label>
          <input v-model="client.name" placeholder="Super client" />
        </div>
        <div class="field" :class="{ 'error': client.errors?.id }" v-if="!client.isPersisted">
          <label>Client ID</label>
          <input v-model="client.id" placeholder="Must be an UUIDv4 - Leave blank to autogenerate" />
        </div>
        <div class="field" :class="{ 'error': client.errors?.secret }">
          <label>Client secret</label>
          <input v-model="client.secret" placeholder="Leave blank to autogenerate" />
        </div>
        <div class="field" :class="{ 'error': client.errors?.access_token_ttl }">
          <label>Access token TTL (seconds)</label>
          <input type="number" v-model="client.access_token_ttl" placeholder="3600" />
        </div>
        <div class="field" :class="{ 'error': client.errors?.authorization_code_ttl }">
          <label>Authorization code TTL (seconds)</label>
          <input type="number" v-model="client.authorization_code_ttl" placeholder="60" />
        </div>
        <div class="field" :class="{ 'error': client.errors?.refresh_token_ttl }">
          <label>Refresh token TTL (seconds)</label>
          <input type="number" v-model="client.refresh_token_ttl" placeholder="2592000" />
        </div>
        <div class="field" :class="{ 'error': client.errors?.id_token_ttl }">
          <label>ID token TTL (seconds)</label>
          <input type="number" v-model="client.id_token_ttl" placeholder="3600" />
        </div>
        <div class="field" :class="{ 'error': client.errors?.redirect_uris }">
          <label>Redirect URIs</label>
          <div v-for="(redirectUri, index) in client.redirect_uris" class="field" :key="index">
            <div class="ui right icon input">
              <input type="text" v-model="redirectUri.uri" placeholder="http://redirect.uri" />
              <i v-on:click="deleteRedirectUri(redirectUri)" class="close icon"></i>
            </div>
          </div>
          <a v-on:click.prevent="addRedirectUri()" class="ui blue fluid button">Add a redirect uri</a>
        </div>
        <h3>Authentication</h3>
        <div class="field" :class="{ 'error': client.errors?.relying_party_id }">
          <RelyingPartyField :relyingParty="client.relying_party.model" @relyingPartyChange="setRelyingParty"/>
        </div>
        <h3>Authorization</h3>
        <div class="field">
          <div class="ui toggle checkbox">
            <input type="checkbox" v-model="client.authorize_scope">
            <label>Authorize scopes</label>
          </div>
        </div>
        <div class="field" :class="{ 'error': client.errors?.authorized_scopes }">
          <ScopesField v-if="client.authorize_scope" :currentScopes="client.authorized_scopes" @delete-scope="deleteScope" @add-scope="addScope" />
        </div>
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
import Scope from '../../models/scope.model'
import ScopesField from './ScopesField.vue'
import RelyingPartyField from './RelyingPartyField.vue'
import FormErrors from './FormErrors.vue'

export default {
  name: 'client-form',
  props: ['client', 'action'],
  components: {
    ScopesField,
    RelyingPartyField,
    FormErrors
  },
  methods: {
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
    setRelyingParty (relyingParty) {
      this.client.relying_party = { model: relyingParty }
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
