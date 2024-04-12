<template>
  <div class="user-form">
    <div class="ui segment">
      <FormErrors :errors="user.errors" v-if="user.errors" />
      <form class="ui form" @submit.prevent="submit">
        <div class="field" v-if="!user.isPersisted">
          <label>Backend</label>
          <select v-model="user.backend_id">
            <option :value="backend.id" v-for="backend in backends" :key="backend.id">{{ backend.name }}</option>
          </select>
        </div>
        <div class="field" v-if="!user.isPersisted">
          <label>Email</label>
          <input type="text" v-model="user.email" placeholder="email@example.com" />
        </div>
        <div class="field" v-if="!user.isPersisted">
          <label>Password</label>
          <input type="password" v-model="user.password" />
        </div>
        <section v-if="user.backend.metadata_fields.length">
          <h2>Metadata</h2>
          <div class="ui segment" v-for="field in user.backend.metadata_fields">
            <h3>{{ field.attribute_name }}</h3>
            <div class="ui two column stackable grid">
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
            </div>
          </div>
        </section>
        <div class="field">
          <label>Group</label>
          <input type="text" v-model="user.group" />
        </div>
        <section>
          <h2>Roles</h2>
          <RolesField :currentRoles="user.roles" @delete-role="deleteRole" @add-role="addRole" />
          <h2>Authorized scopes</h2>
          <ScopesField :currentScopes="user.authorized_scopes" @delete-scope="deleteScope" @add-scope="addScope" />
          <h2>Organizations</h2>
          <OrganizationsField :currentOrganizations="user.organizations" @delete-organization="deleteOrganization" @add-organization="addOrganization" />
          </section>
        <hr />
        <button class="ui right floated violet button" type="submit">{{ action }}</button>
        <a v-on:click="back()" class="ui button">Back</a>
      </form>
    </div>
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
    back () {
      this.$emit('back')
    },
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
    }
  }
}
</script>
