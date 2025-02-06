<template>
  <div class="ui user-form segment">
    <FormErrors :errors="user.errors" v-if="user.errors" />
    <form class="ui form" @submit.prevent="submit">
      <div ref="tabularMenu" class="ui top attached stackable tabular menu">
        <a id="general-configuration" @click="openTab" class="active item">General configuration</a>
        <a id="authorization" @click="openTab" class="item">Authorization</a>
      </div>
      <div ref="general-configuration" data-tab="general-configuration" class="ui bottom attached active tab segment">
        <h2>General configuration</h2>
        <div class="field" v-if="!user.isPersisted" :class="{ 'error': user.errors?.backend }">
          <label>Backend</label>
          <select v-model="user.backend_id">
            <option :value="backend.id" v-for="backend in backends" :key="backend.id">{{ backend.name }}</option>
          </select>
        </div>
        <div class="field" v-if="!user.isPersisted" :class="{ 'error': user.errors?.email }">
          <label>Email</label>
          <input type="text" v-model="user.email" placeholder="email@example.com" />
        </div>
        <div class="field" v-if="!user.isPersisted" :class="{ 'error': user.errors?.password }">
          <label>Password</label>
          <input type="password" v-model="user.password" />
        </div>
        <div class="field" :class="{ 'error': user.errors?.group }">
          <label>Group</label>
          <input type="text" v-model="user.group" />
        </div>
        <section v-if="user.backend.metadata_fields.length">
          <h3>Metadata</h3>
          <div class="ui metadata segment" v-for="field in user.backend.metadata_fields">
            <h4>{{ field.attribute_name }}</h4>
            <div class="ui three column stackable grid">
              <div class="column">
                <div class="field" :class="{ 'error': user.errors?.metadata }">
                  <label>Value</label>
                  <input type="text" v-model="user.metadata[field.attribute_name].value" placeholder="metadata" />
                </div>
              </div>
              <div class="column">
                <div class="field" :class="{ 'error': user.errors?.metadata }">
                  <label>Verifiable credential status</label>
                  <select v-model="user.metadata[field.attribute_name].status">
                    <option value="valid">valid</option>
                    <option value="suspended">suspended</option>
                    <option value="revoked">revoked</option>
                  </select>
                </div>
              </div>
              <div class="column">
                <div class="field">
                  <label>Claim format</label>
                  <div class="ui toggle checkbox">
                    <input type="checkbox" v-model="user.metadata[field.attribute_name].displayStatus">
                    <label>display status</label>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>
        <h3>Organizations</h3>
        <OrganizationsField :currentOrganizations="user.organizations" @delete-organization="deleteOrganization" @add-organization="addOrganization" />
      </div>
      <div ref="authorization" data-tab="authorization" class="ui bottom attached tab segment">
        <h2>Authorization</h2>
        <h3>Roles</h3>
        <RolesField :currentRoles="user.roles" @delete-role="deleteRole" @add-role="addRole" />
        <h3>Authorized scopes</h3>
        <ScopesField :currentScopes="user.authorized_scopes" @delete-scope="deleteScope" @add-scope="addScope" />
      </div>
      <div class="actions">
        <button class="ui right floated violet button" type="submit">{{ action }}</button>
      </div>
    </form>
  </div>
</template>

<script>
import Scope from '../../models/scope.model'
import Role from '../../models/role.model'
import Organization from '../../models/organization.model'
import Backend from '../../models/backend.model'
import ScopesField from './ScopesField.vue'
import RolesField from './RolesField.vue'
import OrganizationsField from './OrganizationsField.vue'
import FormErrors from './FormErrors.vue'

export default {
  name: 'user-form',
  props: ['user', 'action'],
  components: {
    ScopesField,
    RolesField,
    OrganizationsField,
    FormErrors
  },
  data () {
    return {
      scopes: [],
      backends: []
    }
  },
  mounted () {
    Scope.all().then((scopes) => {
      this.scopes = scopes
    })
    Backend.all().then((backends) => {
      this.backends = backends
    })
  },
  methods: {
    addScope () {
      this.user.authorized_scopes.push({ model: new Scope() })
    },
    deleteScope (scope) {
      this.user.authorized_scopes.splice(
        this.user.authorized_scopes.indexOf(scope),
        1
      )
    },
    addRole () {
      this.user.roles.push({ model: new Role() })
    },
    deleteRole (role) {
      this.user.roles.splice(
        this.user.roles.indexOf(role),
        1
      )
    },
    addOrganization () {
      this.user.organizations.push({ model: new Organization() })
    },
    deleteOrganization (organization) {
      this.user.organizations.splice(
        this.user.organizations.indexOf(organization),
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
    user: {
      handler ({ backend_id }) {
        this.user.backend = this.backends.find(({ id }) => id === backend_id) || this.user.backend
      },
      deep: true
    },
    'user.backend': {
      handler() {
        this.user.backend.metadata_fields.forEach((field) => {
          this.user.metadata[field.attribute_name] ||= { status: 'valid' }
        })
      }
    },
    'user.errors': {
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
  }
}
</script>

<style lang="scss">
.metadata .toggle {
  padding: 8px;
}
</style>
