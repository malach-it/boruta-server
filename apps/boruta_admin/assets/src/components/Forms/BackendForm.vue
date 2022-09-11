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
            <input type="checkbox" v-model="backend.is_default" placeholder="Shiny new backend">
            <label>Default</label>
          </div>
        </div>
        <div class="ui info message">
          Default backend will be used in case of resource owner password credentials requests.
        </div>
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
          <div class="field" :class="{ 'error': backend.errors?.ldap_password }">
            <label>Master password</label>
            <div class="ui left icon input">
              <input :type="ldapPasswordVisible ? 'text' : 'password'" autocomplete="new-password" v-model="backend.ldap_password" />
              <i class="eye icon" :class="{ 'slash': ldapPasswordVisible }" @click="ldapPasswordVisibilityToggle()"></i>
            </div>
          </div>
          <div class="field" :class="{ 'error': backend.errors?.ldap_base_dn }">
            <label>Base distinguished name (dn)</label>
            <input type="text" v-model="backend.ldap_base_dn" placeholder="dc=example,dc=com">
          </div>
          <div class="field" :class="{ 'error': backend.errors?.ldap_ou }">
            <label>Users organization unit (ou)</label>
            <input type="text" v-model="backend.ldap_ou" placeholder="ou=People">
          </div>
          <div class="field" :class="{ 'error': backend.errors?.ldap_pool_size }">
            <label>Pool size</label>
            <input type="number" v-model="backend.ldap_pool_size" placeholder="5">
          </div>
        </section>
        <h2>SMTP configuration</h2>
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
          <input type="number" v-model="backend.smtp_port" placeholder="smtp.example.com">
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
import FormErrors from './FormErrors.vue'

export default {
  name: 'backend-form',
  props: ['backend', 'action'],
  components: {
    FormErrors
  },
  data () {
    return {
      passwordHashingAlgorithms: Backend.passwordHashingAlgorithms,
      ldapPasswordVisible: false,
      smtpPasswordVisible: false
    }
  },
  computed: {
    passwordHashingOpts () {
      return Backend.passwordHashingOpts[this.backend.password_hashing_alg]
    }
  },
  methods: {
    onAlgorithmChange () {
      this.backend.resetPasswordAlgorithmOpts()
      if (this.backend.isPersisted) {
        alert('Changing the password hashing algorithm may invalidate already saved passwords. Use this feature with care.')
      }
    },
    ldapPasswordVisibilityToggle () {
      this.ldapPasswordVisible = !this.ldapPasswordVisible
    },
    smtpPasswordVisibilityToggle () {
      this.smtpPasswordVisible = !this.smtpPasswordVisible
    },
    back () {
      this.$emit('back')
    }
  }
}
</script>
