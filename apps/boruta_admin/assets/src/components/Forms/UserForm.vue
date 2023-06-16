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
          <div v-for="field in user.backend.metadata_fields">
            <div class="field">
              <label>{{ field.attribute_name }}</label>
              <input type="text" v-model="user.metadata[field.attribute_name]" placeholder="metadata" />
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
import Backend from '../../models/backend.model'
import ScopesField from './ScopesField.vue'
import RolesField from './RolesField.vue'
import FormErrors from './FormErrors.vue'

export default {
  name: 'user-form',
  props: ['user', 'action'],
  components: {
    ScopesField,
    RolesField,
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
    deleteRole (scope) {
      this.user.roles.splice(
        this.user.roles.indexOf(scope),
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
    }
  }
}
</script>
