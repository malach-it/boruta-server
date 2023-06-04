<template>
  <div class="client-form">
    <div class="ui segment">
      <FormErrors v-if="client.errors" :errors="client.errors" />
      <form class="ui form" @submit.prevent="submit">
        <h3>General configuration</h3>
        <div class="field" :class="{ 'error': client.errors?.name }">
          <label>Name</label>
          <input v-model="client.name" placeholder="Super client" autocomplete="new-password" />
          <i class="ui blue large help question outline circle icon"></i>
          <div class="documentation">
            <div class="ui info message">
            Lorem ipsum dolor sit amet, consectetur adipiscing elit. Proin rutrum mattis neque. Praesent et sem est. Fusce mollis nisl et justo blandit ullamcorper. Nunc pulvinar ligula semper eleifend scelerisque. In tincidunt, mauris a porta mollis, augue mi vehicula nibh, elementum feugiat mauris lectus in felis. Nullam finibus lorem in nibh eleifend molestie.
            </div>
          </div>
        </div>
        <div class="field" :class="{ 'error': client.errors?.id }" v-if="!client.isPersisted">
          <label>Client ID</label>
          <input v-model="client.id" autocomplete="new-password" placeholder="Must be an UUIDv4 - Leave blank to autogenerate" />
          <i class="ui blue large help question outline circle icon"></i>
          <div class="documentation">
            <div class="ui info message">
            Lorem ipsum dolor sit amet, consectetur adipiscing elit. Proin rutrum mattis neque. Praesent et sem est. Fusce mollis nisl et justo blandit ullamcorper. Nunc pulvinar ligula semper eleifend scelerisque. In tincidunt, mauris a porta mollis, augue mi vehicula nibh, elementum feugiat mauris lectus in felis. Nullam finibus lorem in nibh eleifend molestie.
            </div>
          </div>
        </div>
        <div class="field" :class="{ 'error': client.errors?.secret }">
          <label>Client secret</label>
          <div class="ui left icon input">
            <input :type="passwordVisible ? 'text' : 'password'" autocomplete="new-password" v-model="client.secret" placeholder="Leave blank to autogenerate" />
            <i class="eye icon" :class="{ 'slash': passwordVisible }" @click="passwordVisibilityToggle()"></i>
          </div>
          <i class="ui blue large help question outline circle icon"></i>
          <div class="documentation">
            <div class="ui info message">
            Lorem ipsum dolor sit amet, consectetur adipiscing elit. Proin rutrum mattis neque. Praesent et sem est. Fusce mollis nisl et justo blandit ullamcorper. Nunc pulvinar ligula semper eleifend scelerisque. In tincidunt, mauris a porta mollis, augue mi vehicula nibh, elementum feugiat mauris lectus in felis. Nullam finibus lorem in nibh eleifend molestie.
            </div>
          </div>
        </div>
        <div class="ui segment">
          <a class="ui fluid orange button" @click="regenerateKeyPair()" v-if="client.isPersisted">Regenerate client key pair</a>
          <hr />
          <div class="field">
            <select v-model="client.key_pair_id">
              <option :value="null">Custom key pair</option>
              <option v-for="keyPair in keyPairs" :value="keyPair.id" :key="keyPair.id">
                {{ keyPair.id }}
              </option>
            </select>
          </div>
          <hr />
          <div class="field" v-if="clientPublicKey">
            <label>Client public key</label>
            <pre>{{ clientPublicKey }}</pre>
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
        <h3>Authentication</h3>
        <div class="field" :class="{ 'error': client.errors?.identity_provider_id }">
          <IdentityProviderField :identityProvider="client.identity_provider.model" @identityProviderChange="setIdentityProvider"/>
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
        <div class="field">
          <h3>Supported grant types</h3>
          <div class="ui segment" v-for="grantType in client.grantTypes" :key="grantType.label">
            <div class="ui toggle checkbox">
              <input type="checkbox" v-model="grantType.value">
              <label>{{ grantType.label }}</label>
            </div>
          </div>
        </div>
        <hr />
        <button class="ui right floated violet button" type="submit">{{ action }}</button>
        <a v-on:click="back()" class="ui button">Back</a>
      </form>
    </div>
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
      keyPairs: [],
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
    back () {
      this.$emit('back')
    },
    regenerateKeyPair () {
      if (confirm("Are you sure you want to regenerate this client key pair?")) {
        this.client.regenerateKeyPair().then(() => {
          this.$emit('submit')
        })
      }
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
    }
  },
  watch: {
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
    .documentation {
      display: none;
      position: absolute;
      left: 100%;
      top: 0;
      padding-left: 2em;
      margin: 1em;
      width: 70%;
      &:hover {
        display: block;
      }
    }
    .help {
      position: absolute;
      right: -1em;
      top: 1.6em;
      cursor: help;
      &:hover ~ .documentation {
        display: block;
      }
    }
    @media (max-width: 768px) {
      .documentation {
        position: relative;
        width: auto;
        left: 0;
      }
    }
  }
  .authorized-scopes-select {
    margin-right: 3em;
  }
}
</style>
