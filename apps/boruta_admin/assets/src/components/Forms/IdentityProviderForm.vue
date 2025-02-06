<template>
  <div class="ui identity-provider-form segment">
    <FormErrors v-if="identityProvider.errors" :errors="identityProvider.errors" />
    <form ref="form" class="ui form" @submit.prevent="submit">
      <div ref="tabularMenu" class="ui top attached stackable tabular menu">
        <a id="general-configuration" @click="openTab" class="active item">General configuration</a>
        <a id="features" @click="openTab" class="item">Features</a>
      </div>
      <div ref="general-configuration" data-tab="general-configuration" class="ui bottom attached active tab segment">
        <div class="field" :class="{ 'error': identityProvider.errors?.name }">
          <label>Name</label>
          <input type="text" v-model="identityProvider.name" placeholder="Super identity provider">
        </div>
        <div class="field" :class="{ 'error': identityProvider.errors?.backend_id }">
          <label>Backend</label>
          <select v-model="identityProvider.backend_id">
            <option :value="backend.id" v-for="backend in backends">{{ backend.name }}</option>
          </select>
        </div>
        <div v-if="identityProvider.isPersisted" class="ui segment">
          <router-link
            :to="{ name: 'edit-layout-template', params: { identityProviderId: identityProvider.id } }"
            class="ui fluid blue button">Edit layout template</router-link>
        </div>
        <section v-if="identityProvider.isPersisted">
          <h3>Sessions</h3>
          <div class="ui segment">
            <div class="ui toggle checkbox">
              <input type="checkbox" v-model="identityProvider.check_password">
              <label>check password</label>
            </div>
            <hr />
            <router-link
              :to="{ name: 'edit-session-template', params: { identityProviderId: identityProvider.id } }"
              class="ui fluid blue button">Edit login template</router-link>
          </div>
          <div v-show="displayResetPassword">
            <div class="ui segment">
              <router-link
                :to="{ name: 'edit-new-reset-password-template', params: { identityProviderId: identityProvider.id } }"
                class="ui fluid blue button">Edit send reset password instructions template</router-link>
            </div>
            <div class="ui segment">
              <router-link
                :to="{ name: 'edit-edit-reset-password-template', params: { identityProviderId: identityProvider.id } }"
                class="ui fluid blue button">Edit reset password template</router-link>
            </div>
          </div>
        </section>
      </div>
      <div ref="features" data-tab="features" class="ui bottom attached tab segment">
        <section v-if="identityProvider.isPersisted">
          <h3>Choose session</h3>
          <div class="ui segment">
            <div class="ui toggle checkbox">
              <input type="checkbox" v-model="identityProvider.choose_session">
              <label>choose session</label>
            </div>
            <p class="ui info message">
              Give the ability for the user to choose to keep current session or to create a new one on authorization
            </p>
            <div v-if="identityProvider.choose_session">
              <router-link
                :to="{ name: 'edit-choose-session-template', params: { identityProviderId: identityProvider.id } }"
                class="ui fluid blue button">Edit choose session template</router-link>
            </div>
          </div>
        </section>
        <section v-show="displayWebauthnable">
          <h3>Webauthn</h3>
          <div class="ui segment">
            <div class="field">
              <div class="ui toggle checkbox">
                <input type="checkbox" v-model="identityProvider.webauthnable">
                <label>enable Webauthn</label>
              </div>
            </div>
            <hr />
            <div class="field">
              <div class="ui toggle checkbox">
                <input type="checkbox" v-model="identityProvider.enforce_webauthn">
                <label>enforce Webauthn</label>
              </div>
            </div>
            <p class="ui info message">
              Give the ability for end users to register an authentication second factor with Passkeys.
            </p>
            <div v-if="identityProvider.webauthnable">
              <router-link
                :to="{ name: 'edit-webauthn-registration-template', params: { identityProviderId: identityProvider.id } }"
                class="ui fluid blue button">Edit Webauthn registration template</router-link>
              <hr />
              <router-link
                :to="{ name: 'edit-webauthn-authentication-template', params: { identityProviderId: identityProvider.id } }"
                class="ui fluid blue button">Edit Webauthn authentication template</router-link>
            </div>
          </div>
        </section>
        <section v-show="displayTotpable">
          <h3>Time based One Time Password</h3>
          <div class="ui segment">
            <div class="field">
              <div class="ui toggle checkbox">
                <input type="checkbox" v-model="identityProvider.totpable">
                <label>enable TOTP</label>
              </div>
            </div>
            <hr />
            <div class="field">
              <div class="ui toggle checkbox">
                <input type="checkbox" v-model="identityProvider.enforce_totp">
                <label>enforce TOTP</label>
              </div>
            </div>
            <p class="ui info message">
              Give the ability for end users to register an authentication second factor with TOTP.
            </p>
            <div v-if="identityProvider.totpable">
              <router-link
                :to="{ name: 'edit-totp-registration-template', params: { identityProviderId: identityProvider.id } }"
                class="ui fluid blue button">Edit TOTP registration template</router-link>
              <hr />
              <router-link
                :to="{ name: 'edit-totp-authentication-template', params: { identityProviderId: identityProvider.id } }"
                class="ui fluid blue button">Edit TOTP authentication template</router-link>
            </div>
          </div>
        </section>
        <section v-show="displayRegistrable">
          <h3>Registration</h3>
          <div class="ui segment">
            <div class="ui toggle checkbox">
              <input type="checkbox" v-model="identityProvider.registrable">
              <label>registrable</label>
            </div>
            <p class="ui info message">
              Give the ability for end users to register within the given identity provider. If activated the user have access to registration page and can provide its own credentials.
            </p>
            <div v-if="identityProvider.registrable">
              <router-link
                :to="{ name: 'edit-registration-template', params: { identityProviderId: identityProvider.id } }"
                class="ui fluid blue button">Edit registration template</router-link>
            </div>
          </div>
        </section>
        <section v-show="displayUserEditable">
          <h3>User information edition</h3>
          <div class="ui segment">
            <div class="ui toggle checkbox">
              <input type="checkbox" v-model="identityProvider.user_editable">
              <label>user editable</label>
            </div>
            <p class="ui info message">
              Give the ability for end users to update their account information.
            </p>
            <div v-if="identityProvider.user_editable">
              <router-link
                :to="{ name: 'edit-edit-user-template', params: { identityProviderId: identityProvider.id } }"
                class="ui fluid blue button">Edit user edition template</router-link>
            </div>
          </div>
        </section>
        <section v-show="displayConfirmable">
          <h3>Email confirmation</h3>
          <div class="ui segment">
            <div class=" field">
              <div class="ui toggle checkbox">
                <input type="checkbox" v-model="identityProvider.confirmable">
                <label>confirmable</label>
              </div>
              <p class="ui info message">
                Confirm new registred accounts. sends an email in order to confirm user's email.
              </p>
              <div v-if="identityProvider.confirmable">
                <router-link
                  :to="{ name: 'edit-new-confirmation-template', params: { identityProviderId: identityProvider.id } }"
                  class="ui fluid blue button">Edit send confirmation template</router-link>
              </div>
            </div>
          </div>
        </section>
        <section v-show="displayConsentable">
          <h3>User consent</h3>
          <div class="ui segment">
            <div class=" field">
              <div class="ui toggle checkbox">
                <input type="checkbox" v-model="identityProvider.consentable">
                <label>user consent</label>
              </div>
              <p class="ui info message">
                Users have to consent requested scopes to be authorized.
              </p>
              <div v-if="identityProvider.consentable">
                <router-link
                  :to="{ name: 'edit-new-consent-template', params: { identityProviderId: identityProvider.id } }"
                  class="ui fluid blue button">Edit consent template</router-link>
              </div>
            </div>
          </div>
        </section>
        <section v-show="identityProvider.isPersisted">
          <h3>Credential offer</h3>
          <div class="ui segment">
            <div class=" field">
              <p class="ui info message">
                SSI credential offer page
              </p>
              <div>
                <router-link
                  :to="{ name: 'edit-credential-offer-template', params: { identityProviderId: identityProvider.id } }"
                  class="ui fluid blue button">Edit credential offer template</router-link>
              </div>
            </div>
          </div>
          <h3>Credential presentation (cross device)</h3>
          <div class="ui segment">
            <div class=" field">
              <p class="ui info message">
                SSI credential presentation page
              </p>
              <div>
                <router-link
                  :to="{ name: 'edit-cross-device-presentation-template', params: { identityProviderId: identityProvider.id } }"
                  class="ui fluid blue button">Edit cross device presentation template</router-link>
              </div>
            </div>
          </div>
        </section>
      </div>
      <div class="actions">
        <button class="ui violet button" type="submit">{{ action }}</button>
      </div>
    </form>
  </div>
</template>

<script>
import Backend from '../../models/backend.model'
import FormErrors from './FormErrors.vue'

export default {
  name: 'identity-provider-form',
  props: ['identityProvider', 'action'],
  components: {
    FormErrors
  },
  data() {
    return {
      backends: []
    }
  },
  computed: {
    displayConfirmable () {
      return this.identityProvider.isPersisted && this.identityProvider.backend.features?.includes('confirmable')
    },
    displayResetPassword () {
      return this.identityProvider.backend.features?.includes('reset_password')
    },
    displayRegistrable () {
      return this.identityProvider.isPersisted && this.identityProvider.backend.features?.includes('registrable')
    },
    displayWebauthnable () {
      return this.identityProvider.isPersisted && this.identityProvider.backend.features?.includes('webauthnable')
    },
    displayTotpable () {
      return this.identityProvider.isPersisted && this.identityProvider.backend.features?.includes('totpable')
    },
    displayUserEditable () {
      return this.identityProvider.isPersisted && this.identityProvider.backend.features?.includes('user_editable')
    },
    displayConsentable () {
      return this.identityProvider.isPersisted && this.identityProvider.backend.features?.includes('consentable')
    }
  },
  mounted () {
    Backend.all().then(backends => this.backends = backends)
  },
  methods: {
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
    identityProvider: {
      handler ({ backend_id }) {
        this.identityProvider.backend = this.backends.find(({ id }) => id === backend_id) || this.identityProvider.backend
      },
      deep: true
    },
    'identityProvider.errors': {
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
.identity-provider-form {
  section {
    margin-bottom: 1rem;
  }
}
</style>
