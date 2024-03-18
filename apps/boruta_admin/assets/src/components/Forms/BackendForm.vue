<template>
  <div class="backend-form">
    <div class="ui segment">
      <FormErrors :errors="backend.errors" v-if="backend.errors" />
      <form class="ui form" @submit.prevent="submit">
        <h2>General configuration</h2>
        <div class="field" :class="{ 'error': backend.errors?.name }">
          <label>Name</label>
          <input type="text" v-model="backend.name" placeholder="Shiny new backend">
        </div>
        <div class="field" :class="{ 'error': backend.errors?.is_default }">
          <div class="ui toggle checkbox">
            <input type="checkbox" v-model="backend.is_default">
            <label>Default</label>
          </div>
        </div>
        <div class="ui info message">
          Default backend will be used in case of resource owner password credentials requests.
        </div>
        <div class="field" :class="{ 'error': backend.errors?.create_default_organization }">
          <div class="ui toggle checkbox">
            <input type="checkbox" v-model="backend.create_default_organization">
            <label>Create default organization</label>
          </div>
        </div>
        <div class="ui info message">
          Newly created users will have a default organization along with them.
        </div>
        <h2>Roles</h2>
        <RolesField :currentRoles="backend.roles" @delete-role="deleteRole" @add-role="addRole" />
        <div class="field" :class="{ 'error': backend.errors?.type }">
          <label>Type</label>
          <select v-model="backend.type">
            <option value="Elixir.BorutaIdentity.Accounts.Internal">Internal</option>
            <option value="Elixir.BorutaIdentity.Accounts.Ldap">LDAP</option>
          </select>
        </div>
        <section v-if="backend.type == 'Elixir.BorutaIdentity.Accounts.Internal'">
          <h2>Internal configuration</h2>
          <div class="field" :class="{ 'error': backend.errors?.password_hashing_alg }">
            <label>Password hashing algorithm</label>
            <select v-model="backend.password_hashing_alg" @change="onAlgorithmChange">
              <option :value="alg.name" v-for="alg in passwordHashingAlgorithms" :key="alg">{{ alg.label }}</option>
            </select>
          </div>
          <h3>Password hashing algorithm options</h3>
          <div class="field" v-for="opt in passwordHashingOpts" :key="opt.name" :class="{ 'error': backend.errors?.password_hashing_opts }">
            <label>{{ opt.label }}</label>
            <input :type="opt.type" v-model="backend.password_hashing_opts[opt.name]" :placeholder="opt.default">
          </div>
        </section>
        <section v-if="backend.type == 'Elixir.BorutaIdentity.Accounts.Ldap'">
          <h2>LDAP configuration</h2>
          <div class="field" :class="{ 'error': backend.errors?.ldap_host }">
            <label>Host</label>
            <input type="text" v-model="backend.ldap_host" placeholder="example.com">
          </div>
          <div class="field" :class="{ 'error': backend.errors?.ldap_user_rdn_attribute }">
            <label>User RDN attribute</label>
            <input :type="text" v-model="backend.ldap_user_rdn_attribute" placeholder="sn" />
          </div>
          <div class="field" :class="{ 'error': backend.errors?.ldap_base_dn }">
            <label>Base distinguished name (dn)</label>
            <input type="text" v-model="backend.ldap_base_dn" placeholder="dc=example,dc=com">
          </div>
          <div class="field" :class="{ 'error': backend.errors?.ldap_ou }">
            <label>Users organization unit (ou)</label>
            <input type="text" v-model="backend.ldap_ou" placeholder="ou=People">
          </div>
          <div class="field" :class="{ 'error': backend.errors?.ldap_master_dn }">
            <label>Master distinguished name <i>(needed only for user edition)</i></label>
            <input type="text" v-model="backend.ldap_master_dn" placeholder="cn=admin,dc=ldap,dc=test">
          </div>
          <div class="field" :class="{ 'error': backend.errors?.ldap_master_password }">
            <label>Master password <i>(needed only for user edition)</i></label>
            <div class="ui left icon input">
              <input :type="ldapMasterPasswordVisible ? 'text' : 'password'" autocomplete="new-password" v-model="backend.ldap_master_password" />
              <i class="eye icon" :class="{ 'slash': ldapMasterPasswordVisible }" @click="ldapMasterPasswordVisibilityToggle()"></i>
            </div>
          </div>
          <div class="field" :class="{ 'error': backend.errors?.ldap_pool_size }">
            <label>Pool size</label>
            <input type="number" v-model="backend.ldap_pool_size" placeholder="5">
          </div>
        </section>
        <h2>Email configuration</h2>
        <h3>SMTP configuration</h3>
        <div class="field" :class="{ 'error': backend.errors?.smtp_from }">
          <label>From</label>
          <input type="email" v-model="backend.smtp_from" placeholder="from@mail.example">
        </div>
        <div class="field" :class="{ 'error': backend.errors?.smtp_relay }">
          <label>Relay</label>
          <input type="text" v-model="backend.smtp_relay" placeholder="smtp.example.com">
        </div>
        <div class="field" :class="{ 'error': backend.errors?.smtp_username }">
          <label>Username</label>
          <input type="text" v-model="backend.smtp_username" placeholder="username">
        </div>
        <div class="field" :class="{ 'error': backend.errors?.smtp_password }">
          <label>Password</label>
          <div class="ui left icon input">
            <input :type="smtpPasswordVisible ? 'text' : 'password'" autocomplete="new-password" v-model="backend.smtp_password" />
            <i class="eye icon" :class="{ 'slash': smtpPasswordVisible }" @click="smtpPasswordVisibilityToggle()"></i>
          </div>
        </div>
        <div class="field" :class="{ 'error': backend.errors?.smtp_ssl }">
          <div class="ui toggle checkbox">
            <input type="checkbox" v-model="backend.smtp_ssl">
            <label>SSL</label>
          </div>
        </div>
        <div class="field" :class="{ 'error': backend.errors?.smtp_tls }">
          <label>TLS</label>
          <select v-model="backend.smtp_tls">
            <option value="always">Always</option>
            <option value="never">Never</option>
            <option value="if_available">If available</option>
          </select>
        </div>
        <div class="field" :class="{ 'error': backend.errors?.smtp_port }">
          <label>Port</label>
          <input type="number" v-model="backend.smtp_port" placeholder="25">
        </div>
        <h3>Email templates</h3>
        <div v-if="backend.isPersisted" class="ui segment">
          <router-link
            :to="{ name: 'edit-confirmation-instructions-email-template', params: { backendId: backend.id } }"
            class="ui fluid blue button">Edit confirmation template</router-link>
        </div>
        <div v-if="backend.isPersisted" class="ui segment">
          <router-link
            :to="{ name: 'edit-reset-password-instructions-email-template', params: { backendId: backend.id } }"
            class="ui fluid blue button">Edit reset password template</router-link>
        </div>
        <h2>Identity federation (login with)</h2>
        <div v-for="federatedServer in backend.federated_servers" class="ui federated-server-field segment">
          <i class="ui large close icon" @click="deleteFederatedServer(federatedServer)"></i>
          <h3>Federated server</h3>
          <div class="field" :class="{ 'error': backend.errors?.federated_servers }">
            <label>Server name</label>
            <input type="text" v-model="federatedServer.name" placeholder="boruta">
          </div>
          <div class="field" :class="{ 'error': backend.errors?.federated_servers }">
            <label>Client ID</label>
            <input type="text" v-model="federatedServer.client_id">
          </div>
          <div class="field" :class="{ 'error': backend.errors?.federated_servers }">
            <label>Client secret</label>
            <div class="ui left icon input">
              <input :type="federatedServer.clientSecretVisible ? 'text' : 'password'" autocomplete="new-password" v-model="federatedServer.client_secret" />
              <i class="eye icon" :class="{ 'slash': federatedServer.clientSecretVisible }" @click="federatedServerVisibilityToggle(federatedServer)"></i>
            </div>
          </div>
          <div class="ui info message">
            You'll need to fill the redirect uri on the remote server `${BORUTA_OAUTH_HOST}/accounts/backends/:backend_id/:federated_server_name/callback`
          </div>
          <div class="field" :class="{ 'error': backend.errors?.federated_servers }">
            <label>Base URL</label>
            <input type="text" v-model="federatedServer.base_url">
          </div>
          <div class="field" :class="{ 'error': backend.errors?.federated_servers }">
            <label>scope <i>(separated with a whitespace)</i></label>
            <input type="text" v-model="federatedServer.scope">
          </div>
          <h4>Federated metadata</h4>
          <div class="ui federated-metadata-fields segment" v-for="metadataEndpoint in federatedServer.metadata_endpoints || []">
            <h5>Metadata endpoint configuration</h5>
            <i class="ui large close icon" @click="deleteMetadataEndpoint(federatedServer, metadataEndpoint)"></i>
            <div class="field" :class="{ 'error': backend.errors?.federated_servers }">
              <label>Metadata endpoint URL</label>
              <input type="text" v-model="metadataEndpoint.endpoint">
            </div>
            <div class="field" :class="{ 'error': backend.errors?.federated_servers }">
              <label>Metadata endpoint claims <i>(separated with a whitespace)</i></label>
              <input type="text" v-model="metadataEndpoint.claims">
            </div>
          </div>
          <div class="field">
            <a class="ui blue fluid button" @click="addMetadataEndpoint(federatedServer)">Add a federated metadata endpoint</a>
          </div>
          <h4>Federated server endpoints</h4>
          <div class="field">
            <div class="ui toggle checkbox">
              <input type="checkbox" v-model="federatedServer.isDiscovery">
              <label>Use OpenID discovery</label>
            </div>
          </div>
          <div v-if="federatedServer.isDiscovery">
            <div class="field" :class="{ 'error': backend.errors?.federated_servers }">
              <label>Discovery path</label>
              <input type="text" v-model="federatedServer.discovery_path">
            </div>
          </div>
          <div v-else>
            <div class="field" :class="{ 'error': backend.errors?.federated_servers }">
              <label>Userinfo path</label>
              <input type="text" v-model="federatedServer.userinfo_path">
            </div>
            <div class="field" :class="{ 'error': backend.errors?.federated_servers }">
              <label>Authorize path</label>
              <input type="text" v-model="federatedServer.authorize_path">
            </div>
            <div class="field" :class="{ 'error': backend.errors?.federated_servers }">
              <label>Token path</label>
              <input type="text" v-model="federatedServer.token_path">
            </div>
          </div>
        </div>
        <div class="field">
          <a class="ui blue fluid button" @click="addFederatedServer()">Add a federated server</a>
        </div>
        <hr />
        <h2>Verifiable credentials</h2>
        <div v-for="credential in backend.verifiable_credentials" class="ui credential-field segment">
          <i class="ui large close icon" @click="deleteVerifiableCredential(credential)"></i>
          <h3>Verifiable cerdential</h3>
          <div class="field" :class="{ 'error': backend.errors?.verifiable_credentials }">
            <label>Credential identifier</label>
            <input type="text" v-model="credential.credential_identifier" placeholder="BorutaCredential">
          </div>
          <div class="field" :class="{ 'error': backend.errors?.verifiable_credentials }">
            <label>Format</label>
            <select v-model="credential.format">
              <option value="jwt_vc_json">jwt_vc_json</option>
              <option value="jwt_vc">jwt_vc</option>
              <option value="vc+sd-jwt">vc+sd-jwt</option>
            </select>
          </div>
          <div class="field" :class="{ 'error': backend.errors?.verifiable_credentials }">
            <label>Types <i>(separated with a whitespace)</i></label>
            <input type="text" v-model="credential.types" placeholder="VerifiableCredential BorutaCredential">
          </div>
          <div class="field" :class="{ 'error': backend.errors?.verifiable_credentials }">
            <label>Time to live <i>(in seconds)</i></label>
            <input type="number" v-model="credential.time_to_live" placeholder="31536000">
          </div>
          <h4>Claims</h4>
          <div class="ui claim segment" v-for="claim in credential.claims">
            <i class="ui large close icon" @click="deleteVerifiableCredentialClaim(credential, claim)"></i>
            <h5>Claim definition</h5>
            <div class="field" :class="{ 'error': backend.errors?.verifiable_credentials }">
              <label>Name</label>
              <input type="text" v-model="claim.name" placeholder="family_name">
            </div>
            <div class="field" :class="{ 'error': backend.errors?.verifiable_credentials }">
              <label>Label</label>
              <input type="text" v-model="claim.label" placeholder="Family name">
            </div>
            <div class="field" :class="{ 'error': backend.errors?.verifiable_credentials }">
              <label>pointer</label>
              <input type="text" v-model="claim.pointer" placeholder="family_name">
            </div>
          </div>
          <div class="field">
            <a class="ui blue fluid button" @click="addVerifiableCredentialClaim(credential)">Add a claim</a>
          </div>
          <h4>Display</h4>
          <div class="field" :class="{ 'error': backend.errors?.verifiable_credentials }">
            <label>Name</label>
            <input type="text" v-model="credential.display.name" placeholder="Boruta Credential">
          </div>
          <div class="field" :class="{ 'error': backend.errors?.verifiable_credentials }">
            <label>Background color</label>
            <input type="text" v-model="credential.display.background_color" placeholder="#53b29f">
          </div>
          <div class="field" :class="{ 'error': backend.errors?.verifiable_credentials }">
            <label>Text color</label>
            <input type="text" v-model="credential.display.text_color" placeholder="#ffffff">
          </div>
          <div class="field" :class="{ 'error': backend.errors?.verifiable_credentials }">
            <label>Logo URL</label>
            <input type="text" v-model="credential.display.logo.url" placeholder="https://io.malach.it/assets/images/logo.png">
          </div>
          <div class="field" :class="{ 'error': backend.errors?.verifiable_credentials }">
            <label>Logo alt text</label>
            <input type="text" v-model="credential.display.logo.alt_text" placeholder="Boruta credential logo">
          </div>
        </div>
        <div class="field">
          <a class="ui blue fluid button" @click="addVerifiableCredential()">Add a verifiable credential</a>
        </div>
        <hr />
        <h2>User metadata configuration</h2>
        <div v-for="field in backend.metadata_fields" class="ui metadata-field segment">
          <i class="ui large close icon" @click="deleteMetadataField(field)"></i>
          <h3>Metadata field</h3>
          <div class="field" :class="{ 'error': backend.errors?.metadata_fields }">
            <div class="ui toggle checkbox">
              <input type="checkbox" v-model="field.user_editable">
              <label>User editable</label>
            </div>
          </div>
          <div class="field" :class="{ 'error': backend.errors?.metadata_fields }">
            <label>Scope restriction <i>(leave blank for no restriction)</i></label>
            <ScopesFieldByName :currentScopes="field.scopes" :scopes="scopes" @add-scope="addMetadataFieldScope(field)" @delete-scope="scope => deleteMetadataFieldScope(field, scope)" />
          </div>
          <div class="field" :class="{ 'error': backend.errors?.metadata_fields }">
            <label>Attribute name</label>
            <input type="text" v-model="field.attribute_name" placeholder="family_name">
          </div>
        </div>
        <div class="field">
          <a class="ui blue fluid button" @click="addMetadataField()">Add a metadata field</a>
        </div>
        <hr />
        <button class="ui right floated violet button" type="submit">{{ action }}</button>
        <a v-on:click="back()" class="ui button">Back</a>
      </form>
    </div>
  </div>
</template>

<script>
import Backend from '../../models/backend.model'
import RolesField from './RolesField.vue'
import Role from '../../models/role.model'
import Scope from '../../models/scope.model'
import FormErrors from './FormErrors.vue'
import ScopesFieldByName from './ScopesFieldByName.vue'

export default {
  name: 'backend-form',
  props: ['backend', 'action'],
  components: {
    FormErrors,
    RolesField,
    ScopesFieldByName
  },
  data () {
    return {
      passwordHashingAlgorithms: Backend.passwordHashingAlgorithms,
      ldapMasterPasswordVisible: false,
      smtpPasswordVisible: false,
      scopes: []
    }
  },
  computed: {
    passwordHashingOpts () {
      return Backend.passwordHashingOpts[this.backend.password_hashing_alg]
    }
  },
  mounted () {
    Scope.all().then(scopes => {
      this.scopes = scopes
    })
  },
  methods: {
    onAlgorithmChange () {
      this.backend.resetPasswordAlgorithmOpts()
      if (this.backend.isPersisted) {
        alert('Changing the password hashing algorithm may invalidate already saved passwords. Use this feature with care.')
      }
    },
    ldapMasterPasswordVisibilityToggle () {
      this.ldapMasterPasswordVisible = !this.ldapMasterPasswordVisible
    },
    smtpPasswordVisibilityToggle () {
      this.smtpPasswordVisible = !this.smtpPasswordVisible
    },
    federatedServerVisibilityToggle (federatedServer) {
      federatedServer.clientSecretVisible = !federatedServer.clientSecretVisible
    },
    addFederatedServer () {
      this.backend.federated_servers.push({})
    },
    addMetadataEndpoint (federatedServer) {
      federatedServer.metadata_endpoints ||= []
      federatedServer.metadata_endpoints.push({})
    },
    deleteMetadataEndpoint (federatedServer, endpoint) {
      federatedServer.metadata_endpoints.splice(
        federatedServer.metadata_endpoints.indexOf(endpoint),
        1
      )
    },
    addVerifiableCredentialClaim (credential) {
      credential.claims.push({})
    },
    deleteVerifiableCredentialClaim (credential, claim) {
      credential.claims.splice(
        credential.claims.indexOf(claim),
        1
      )
    },
    addVerifiableCredential () {
      this.backend.verifiable_credentials.push({display: {logo: {}}, claims: []})
    },
    addMetadataField () {
      this.backend.metadata_fields.push({ scopes: [] })
    },
    deleteMetadataField (field) {
      this.backend.metadata_fields.splice(
        this.backend.metadata_fields.indexOf(field),
        1
      )
    },
    deleteFederatedServer (federatedServer) {
      this.backend.federated_servers.splice(
        this.backend.federated_servers.indexOf(federatedServer),
        1
      )
    },
    deleteVerifiableCredential (credential) {
      this.backend.verifiable_credentials.splice(
        this.backend.verifiable_credentials.indexOf(credential),
        1
      )
    },
    addMetadataFieldScope (field) {
      field.scopes ||= []
      field.scopes.push({})
    },
    deleteMetadataFieldScope (field, scope) {
      field.scopes.splice(field.scopes.indexOf(scope), 1)
    },
    back () {
      this.$emit('back')
    },
    addRole () {
      this.backend.roles.push({ model: new Role() })
    },
    deleteRole (role) {
      this.backend.roles.splice(
        this.backend.roles.indexOf(role),
        1
      )
    }
  }
}
</script>

<style scoped lang="scss">
.metadata-field.segment, .federated-server-field.segment, .credential-field.segment {
  .field {
    margin-bottom: 1em!important;
  }
  .close.icon {
    position: absolute;
    cursor: pointer;
    top: 1.17em;
    right: .5em;
  }
}
</style>
