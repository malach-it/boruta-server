<template>
  <div class="ui client-form segment">
    <FormErrors v-if="client.errors" :errors="client.errors" />
    <form ref="form" class="ui form" @submit.prevent="submit">
      <div ref="tabularMenu" class="ui top attached stackable tabular menu">
        <a id="general-configuration" @click="openTab" class="active item">General configuration</a>
        <a id="authentication" @click="openTab" class="item">Authentication</a>
        <a id="security" @click="openTab" class="item">Security</a>
        <a id="grant-types" @click="openTab" class="item">Grant types</a>
      </div>
      <div ref="general-configuration" data-tab="general-configuration" class="ui bottom attached active tab segment">
        <div class="field" :class="{ 'error': client.errors?.name }">
          <label>Name</label>
          <input v-model="client.name" placeholder="Super client" autocomplete="new-password" />
        </div>
        <div class="field" :class="{ 'error': client.errors?.id }" v-if="!client.isPersisted">
          <label>Client ID</label>
          <input v-model="client.id" autocomplete="new-password" placeholder="Must be an UUIDv4 - Leave blank to autogenerate" />
        </div>
        <div class="field" :class="{ 'error': client.errors?.id }">
          <label>Public client ID</label>
          <input v-model="client.public_client_id" placeholder="https://boruta.host" />
        </div>
        <div class="field" :class="{ 'error': client.errors?.secret }">
          <label>Client secret</label>
          <div class="ui left icon input">
            <input :type="passwordVisible ? 'text' : 'password'" autocomplete="new-password" v-model="client.secret" placeholder="Leave blank to autogenerate" />
            <i class="eye icon" :class="{ 'slash': passwordVisible }" @click="passwordVisibilityToggle()"></i>
          </div>
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
        <div class="field" :class="{ 'error': client.errors?.authorization_request_ttl }">
          <label>Authorization request TTL (seconds)</label>
          <input type="number" v-model="client.authorization_request_ttl" placeholder="60" />
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
        <div class="field" :class="{ 'error': client.errors?.response_mode }">
          <label>Response mode</label>
          <select v-model="client.response_mode">
            <option value="post">post</option>
            <option value="direct_post">direct_post</option>
          </select>
        </div>
      </div>
      <div ref="authentication" data-tab="authentication" class="ui bottom attached tab segment">
        <h3>Client authentication</h3>
        <div class="ui segment">
          <div class="inline fields" :class="{ 'error': client.errors?.token_endpoint_auth_methods }">
            <label>Client authentication methods</label>
            <div class="field" v-for="method in tokenEndpointAuthMethods" :key="method">
              <div class="ui checkbox">
                <input type="checkbox" v-model="client.token_endpoint_auth_methods" :value="method" />
                <label>{{ method }}</label>
              </div>
            </div>
          </div>
        </div>
        <div class="ui segment">
          <div class="inline fields" :class="{ 'error': client.errors?.token_endpoint_jwt_auth_alg }">
            <label>Client JWT authentication signature algorithm</label>
            <div class="field" v-for="alg in clientJwtAuthenticationSignatureAlgorithms" :key="alg">
              <div class="ui radio checkbox">
                <label>{{ alg }}</label>
                <input type="radio" v-model="client.token_endpoint_jwt_auth_alg" :value="alg" />
              </div>
            </div>
          </div>
        </div>
        <div class="field" v-if="client.token_endpoint_jwt_auth_alg.match(/RS/)">
          <label>Client JWT authentication public key (pem)</label>
          <textarea v-model="client.jwt_public_key" placeholder="Your public key here"></textarea>
        </div>
        <div class="ui segment">
          <div class="ui toggle checkbox">
            <input type="checkbox" v-model="client.confidential">
            <label>Confidential</label>
          </div>
        </div>
        <h3>User authentication</h3>
        <div class="field" :class="{ 'error': client.errors?.identity_provider_id }">
          <IdentityProviderField :identityProvider="client.identity_provider.model" @identityProviderChange="setIdentityProvider"/>
        </div>
      </div>
      <div ref="security" data-tab="security" class="ui bottom attached tab segment">
        <h3>Signatures adapter</h3>
        <div class="field" :class="{ 'error': client.errors?.signatures_adapter }">
          <select v-model="client.signatures_adapter">
            <option v-for="adapter in signaturesAdapters" :value="adapter">{{ adapter }}</option>
          </select>
        </div>

        <div class="ui segment" v-if="client.signatures_adapter == 'Elixir.Boruta.Universal.Signatures'">
          <div class="ui info message">
            The usage of the Universal adapter requires an account, please contact Godiddy services <a href="https://godiddy.com/contact" target="_blank">https://godiddy.com/contact</a> and set the API key as an environment variable.
          </div>
          <h4>Key management</h4>
          <h4>Key type</h4>
          <div class="field" :class="{ 'error': client.errors?.key_pair_type }">
            <select v-model="client.key_pair_type.type" @change="keyPairTypeChanged = true">
              <option value="universal">
                universal
              </option>
            </select>
          </div>
          <div class="field">
            <label>method</label>
            <select>
              <option value="key">key</option>
            </select>
          </div>
          <hr />
          <div class="field" v-if="client.did">
            <label>Client did</label>
            <pre>{{ client.did }}</pre>
          </div>
          <div class="field" v-if="clientPublicKey">
            <label>Client public key</label>
            <pre>{{ clientPublicKey }}</pre>
          </div>
          <button type="button" class="ui fluid orange button" :disabled="keyPairTypeChanged" @click="regenerateKeyPair()" v-if="client.isPersisted">Regenerate client key pair</button>
        </div>
        <div class="ui segment" v-if="client.signatures_adapter == 'Elixir.Boruta.Internal.Signatures'">
          <h4>Key type</h4>
          <div class="field" :class="{ 'error': client.errors?.key_pair_type }">
            <select v-model="client.key_pair_type.type" @change="keyPairTypeChanged = true">
              <option v-for="keyPairType in Object.keys(keyPairTypes)" :value="keyPairType" :key="keyPairType">
                {{ keyPairType }}
              </option>
            </select>
          </div>
          <div v-for="(value, param) in keyPairTypes[client.key_pair_type.type]" class="field" :class="{ 'error': client.errors?.key_pair_type }">
            <label>{{ param }}</label>
            <select v-if="value instanceof Array" v-model="client.key_pair_type[param]">
              <option v-for="option in value" :value="option" :key="option">
                {{ option }}
              </option>
            </select>
            <input v-else type="text" v-model="client.key_pair_type[param]" />
          </div>
          <h4>Key management</h4>
          <div class="field">
            <select v-model="client.key_pair_id">
              <option :value="null">Custom key pair</option>
              <option v-for="keyPair in keyPairs" :value="keyPair.id" :key="keyPair.id">
                {{ keyPair.id }}
              </option>
            </select>
          </div>
          <hr />
          <div class="field" v-if="client.did">
            <label>Client did</label>
            <pre>{{ client.did }}</pre>
          </div>
          <div class="field" v-if="clientPublicKey">
            <label>Client public key</label>
            <pre>{{ clientPublicKey }}</pre>
          </div>
          <button type="button" class="ui fluid orange button" :disabled="keyPairTypeChanged" @click="regenerateKeyPair()" v-if="client.isPersisted">Regenerate client key pair</button>
          <hr />
          <a class="ui fluid orange button" @click="regenerateDid()" v-if="client.isPersisted">Regenerate client did</a>
        </div>
        <h3>Token signatures</h3>
        <div class="ui segment">
          <div class="inline fields" :class="{ 'error': client.errors?.id_token_signature_alg }">
            <label>ID token signature algorithm</label>
            <div class="field" v-for="alg in idTokenSignatureAlgorithms" :key="alg">
              <div class="ui radio checkbox">
                <label>{{ alg }}</label>
                <input type="radio" v-model="client.id_token_signature_alg" :value="alg" />
              </div>
            </div>
          </div>
        </div>
        <div class="ui segment">
          <div class="inline fields" :class="{ 'error': client.errors?.userinfo_signed_response_alg }">
            <label>Userinfo response signature algorithm</label>
            <div class="field" v-for="alg in UserinfoResponseSignatureAlgorithms" :key="alg">
              <div class="ui radio checkbox">
                <label>{{ alg || 'none' }}</label>
                <input type="radio" v-model="client.userinfo_signed_response_alg" :value="alg" />
              </div>
            </div>
          </div>
        </div>
        <h3>Authorization</h3>
        <div class="field">
          <div class="ui toggle checkbox">
            <input type="checkbox" v-model="client.enforce_dpop">
            <label>Enforce Demonstration Proof-of-Possession (DPoP)</label>
          </div>
        </div>
        <div class="field">
          <div class="ui toggle checkbox">
            <input type="checkbox" v-model="client.enforce_tx_code">
            <label>Enforce pre-authorized code transaction code</label>
          </div>
        </div>
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
        <div class="ui segment">
          <div class="ui toggle checkbox">
            <input type="checkbox" v-model="client.pkce">
            <label>PKCE enabled</label>
          </div>
        </div>
        <div class="ui segment">
          <div class="ui toggle checkbox">
            <input type="checkbox" v-model="client.public_refresh_token">
            <label>Public refresh token</label>
          </div>
        </div>
        <div class="ui segment">
          <div class="ui toggle checkbox">
            <input type="checkbox" v-model="client.public_revoke">
            <label>Public revoke</label>
          </div>
        </div>
      </div>
      <div ref="grant-types" data-tab="grant-types" class="ui bottom attached tab segment">
        <h3>Supported grant types</h3>
        <div class="ui segment" v-for="grantType in client.grantTypes" :key="grantType.label">
          <div class="ui toggle checkbox">
            <input type="checkbox" v-model="grantType.value">
            <label>{{ grantType.label }}</label>
          </div>
        </div>
      </div>
      <div class="actions">
        <button class="ui violet button" type="submit">{{ action }}</button>
      </div>
    </form>
  </div>
</template>

<script>
import Scope from '../../models/scope.model'
import KeyPair from '../../models/key-pair.model'
import Client from '../../models/client.model'
import ScopesField from './ScopesField.vue'
import IdentityProviderField from './IdentityProviderField.vue'
import FormErrors from './FormErrors.vue'

export default {
  name: 'client-form',
  props: ['client', 'action'],
  components: {
    ScopesField,
    IdentityProviderField,
    FormErrors
  },
  data() {
    return {
      keyPairTypes: Client.keyPairTypes,
      signaturesAdapters: Client.signaturesAdapters,
      keyPairs: [],
      keyPairTypeChanged: false,
      idTokenSignatureAlgorithms: Client.idTokenSignatureAlgorithms,
      UserinfoResponseSignatureAlgorithms: Client.UserinfoResponseSignatureAlgorithms,
      clientJwtAuthenticationSignatureAlgorithms: Client.clientJwtAuthenticationSignatureAlgorithms,
      tokenEndpointAuthMethods: Client.tokenEndpointAuthMethods,
      passwordVisible: false
    }
  },
  mounted () {
    KeyPair.all().then(keyPairs => {
      this.keyPairs = keyPairs
    })
  },
  methods: {
    regenerateKeyPair () {
      if (confirm("Are you sure you want to regenerate this client key pair?")) {
        this.client.regenerateKeyPair().then(() => {
          this.$emit('submit')
        })
      }
    },
    regenerateDid () {
      if (confirm("Are you sure you want to regenerate this client did?")) {
        this.client.regenerateDid().then(() => {
          this.$emit('submit')
        })
      }
    },
    submit () {
      this.keyPairTypeChanged = false
      this.$emit('submit')
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
    setIdentityProvider (identityProvider) {
      this.client.identity_provider = { model: identityProvider }
    },
    addScope () {
      this.client.authorized_scopes.push({ model: new Scope() })
    },
    deleteScope (scope) {
      this.client.authorized_scopes.splice(
        this.client.authorized_scopes.indexOf(scope),
        1
      )
    },
    passwordVisibilityToggle () {
      this.passwordVisible = !this.passwordVisible
    },
    openTab (e) {
      const tab = e.target.id
      Array.from(this.$refs.tabularMenu.getElementsByClassName('item')).forEach(e => {
        if (e.id == tab) {
          e.classList.add('active')
          this.$refs[e.id].classList.add('active')
        } else {
          e.classList.remove('active')
          this.$refs[e.id].classList.remove('active')
        }
      })
    }
  },
  watch: {
    '$route.hash': {
      handler (hash) {
        console.log(this.$refs.tabularMenu)
        Array.from(this.$refs.tabularMenu.getElementsByClassName('item')).forEach(e => {
          console.log(e.classList)
          if (Array.from(e.classList).includes(hash.slice(1))) {
            e.classList.add('active')
          } else {
            e.classList.remove('active')
          }
        })
      }
    },
    'client.errors': {
      deep: true,
      handler (errors) {
        setTimeout(() => {
          Array.from(this.$refs.tabularMenu.getElementsByClassName('error')).forEach(e => {
            e.classList.remove('error')
          })
          Array.from(this.$refs.form.getElementsByClassName('error')).forEach(elt => {
            const tab = elt.closest('.tab').getAttribute('data-tab')
            this.$refs.tabularMenu.querySelector('#' + tab).classList.add('error')
          })
        }, 100)
      }
    },
    'client.public_key': {
      deep: true,
      handler (newPublicKey) {
        this.clientPublicKey = newPublicKey
      }
    },
    'client.key_pair_id': {
      deep: true,
      handler (newKeyPairId) {
        if (newKeyPairId) {
          this.clientPublicKey = this.keyPairs.find(({ id }) => {
            return id === newKeyPairId
          }).public_key
        } else {
          const keyPair = this.keyPairs.find(({ public_key }) => {
            return public_key === this.client.public_key
          })
          this.client.key_pair_id = keyPair ? keyPair.id : null
          this.clientPublicKey = this.client.public_key
        }
      }
    }
  }
}
</script>

<style scoped lang="scss">
.client-form {
  .field {
    position: relative;
    pre {
      overflow: hidden;
      text-overflow: ellipsis;
    }
  }
}
</style>
