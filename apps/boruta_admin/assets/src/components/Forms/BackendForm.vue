<template>
  <div class="ui backend-form segment">
    <FormErrors :errors="backend.errors" v-if="backend.errors" />
    <form class="ui form" @submit.prevent="submit">
      <div ref="tabularMenu" class="ui top attached stackable tabular menu">
        <a id="general-configuration" @click="openTab" class="active item">General configuration</a>
        <a id="type" @click="openTab" class="item">Type</a>
        <a id="email-configuration" @click="openTab" class="item">Email configuration</a>
        <a id="identity-federation" @click="openTab" class="item">Identity federation</a>
        <a id="verifiable-credentials" @click="openTab" class="item">Verifiable credentials</a>
        <a id="user-metadata" @click="openTab" class="item">User metadata</a>
      </div>
      <div ref="form">
        <div ref="general-configuration" data-tab="general-configuration" class="ui bottom attached active tab segment">
          <h2>General configuration</h2>
          <div class="field" :class="{ 'error': backend.errors?.name }">
            <label>Name</label>
            <input type="text" v-model="backend.name" placeholder="Shiny new backend">
          </div>
          <div class="ui info message">
            Default backend will be used in case of resource owner password credentials requests.
          </div>
          <div class="field" :class="{ 'error': backend.errors?.is_default }">
            <div class="ui toggle checkbox">
              <input type="checkbox" v-model="backend.is_default">
              <label>Default</label>
            </div>
          </div>
          <div class="ui info message">
            Newly created users will have a default organization along with them.
          </div>
          <div class="field" :class="{ 'error': backend.errors?.create_default_organization }">
            <div class="ui toggle checkbox">
              <input type="checkbox" v-model="backend.create_default_organization">
              <label>Create default organization</label>
            </div>
          </div>
          <h2>Roles</h2>
          <RolesField :currentRoles="backend.roles" @delete-role="deleteRole" @add-role="addRole" />
        </div>
        <div ref="type" data-tab="type" class="ui bottom attached tab segment">
          <h2>Backend type</h2>
          <div class="field" :class="{ 'error': backend.errors?.type }">
            <label>Type</label>
            <select v-model="backend.type">
              <option value="Elixir.BorutaIdentity.Accounts.Internal">Internal</option>
              <option value="Elixir.BorutaIdentity.Accounts.Ldap">LDAP</option>
            </select>
          </div>
          <section v-if="backend.type == 'Elixir.BorutaIdentity.Accounts.Internal'">
            <h3>Internal configuration</h3>
            <div class="field" :class="{ 'error': backend.errors?.password_hashing_alg }">
              <label>Password hashing algorithm</label>
              <select v-model="backend.password_hashing_alg" @change="onAlgorithmChange">
                <option :value="alg.name" v-for="alg in passwordHashingAlgorithms" :key="alg">{{ alg.label }}</option>
              </select>
            </div>
            <h4>Password hashing algorithm options</h4>
            <div class="field" v-for="opt in passwordHashingOpts" :key="opt.name" :class="{ 'error': backend.errors?.password_hashing_opts }">
              <label>{{ opt.label }}</label>
              <input :type="opt.type" v-model="backend.password_hashing_opts[opt.name]" :placeholder="opt.default">
            </div>
          </section>
          <section v-if="backend.type == 'Elixir.BorutaIdentity.Accounts.Ldap'">
            <h3>LDAP configuration</h3>
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
        </div>
        <div ref="email-configuration" data-tab="email-configuration" class="ui bottom attached tab segment">
          <h2>Email configuration</h2>
          <h3>SMTP configuration</h3>
          <div class="field" :class="{ 'error': backend.errors?.smtp_from }">
            <label>From</label>
            <input type="text" v-model="backend.smtp_from" placeholder="from@mail.example">
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
          <div v-if="backend.isPersisted" class="ui segment">
            <router-link
              :to="{ name: 'edit-tx-code-email-template', params: { backendId: backend.id } }"
              class="ui fluid blue button">Edit transaction code template</router-link>
          </div>
        </div>
        <div ref="identity-federation" data-tab="identity-federation" class="ui bottom attached tab segment">
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
        </div>
        <div ref="verifiable-credentials" data-tab="verifiable-credentials" class="ui bottom attached tab segment">
          <h2>Verifiable credentials</h2>
          <div v-for="credential in backend.verifiable_credentials" class="ui credential-field segment">
            <i class="ui large close icon" @click="deleteVerifiableCredential(credential)"></i>
            <h3>Verifiable credential</h3>
            <div class="field" :class="{ 'error': backend.errors?.verifiable_credentials }">
              <label>Credential identifier</label>
              <input type="text" v-model="credential.credential_identifier" placeholder="BorutaCredential">
            </div>
            <div class="field" :class="{ 'error': backend.errors?.verifiable_credentials }">
              <label>Version</label>
              <select v-model="credential.version">
                <option value="11">11</option>
                <option value="13">13</option>
              </select>
            </div>
            <div class="field" :class="{ 'error': backend.errors?.verifiable_credentials }">
              <label>Format</label>
              <select v-model="credential.format">
                <option value="jwt_vc_json">jwt_vc_json</option>
                <option value="jwt_vc">jwt_vc</option>
                <option value="vc+sd-jwt">vc+sd-jwt</option>
              </select>
            </div>
            <div class="field">
              <div class="ui toggle checkbox">
                <input type="checkbox" v-model="credential.defered">
                <label>Defered</label>
              </div>
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
                <label>Pointer</label>
                <input type="text" v-model="claim.pointer" placeholder="family_name">
              </div>
              <div class="field" v-if="credential.format === 'vc+sd-jwt'" :class="{ 'error': backend.errors?.verifiable_credentials }">
                <label>Expiration</label>
                <input type="text" v-model="claim.expiration" placeholder="3784320000">
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
          <h2>Verifiable presentations</h2>
          <div v-for="presentation in backend.verifiable_presentations" class="ui presentation-field segment">
            <i class="ui large close icon" @click="deleteVerifiablePresentation(presentation)"></i>
            <h3>Verifiable presentation</h3>
            <div class="field" :class="{ 'error': backend.errors?.verifiable_presentations }">
              <label>Presentation identifier</label>
              <input type="text" v-model="presentation.presentation_identifier" placeholder="BorutaPresentation">
            </div>
            <div class="field" :class="{ 'error': backend.errors?.verifiable_presentations }">
              <label>Presentation definition</label>

              <TextEditor :content="presentation.presentation_definition" @codeUpdate="setPresentationDefitiion($event, presentation)" />
            </div>
          </div>
          <div class="field">
            <a class="ui blue fluid button" @click="addVerifiablePresentation()">Add a verifiable presentation</a>
          </div>
        </div>
        <div ref="user-metadata" data-tab="user-metadata" class="ui bottom attached tab segment">
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
        </div>
      </div>
      <div class="actions">
        <button class="ui right floated violet button" type="submit">{{ action }}</button>
      </div>
    </form>
  </div>
</template>

<script>
import Backend from '../../models/backend.model'
import RolesField from './RolesField.vue'
import Role from '../../models/role.model'
import Scope from '../../models/scope.model'
import FormErrors from './FormErrors.vue'
import ScopesFieldByName from './ScopesFieldByName.vue'
import TextEditor from '../../components/Forms/TextEditor.vue'

export default {
  name: 'backend-form',
  props: ['backend', 'action'],
  components: {
    FormErrors,
    RolesField,
    ScopesFieldByName,
    TextEditor
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
      credential.claims.push({defered: false})
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
    addVerifiablePresentation () {
      this.backend.verifiable_presentations.push({})
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
    deleteVerifiablePresentation (presentation) {
      this.backend.verifiable_presentations.splice(
        this.backend.verifiable_presentations.indexOf(presentation),
        1
      )
    },
    setPresentationDefitiion (content, presentation) {
      presentation.presentation_definition = content
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
    'backend.errors': {
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
