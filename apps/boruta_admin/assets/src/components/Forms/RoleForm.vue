<template>
  <div class="ui role-form segment">
    <FormErrors v-if="role.errors" :errors="role.errors" />
    <form class="ui form" @submit.prevent="submit">
      <h2>General configuration</h2>
      <div class="field" :class="{ 'error': role.errors?.name }">
        <label for="role-name">Name</label>
        <input id="role-name" type="text" v-model="role.name" placeholder="administrator" />
      </div>
      <h3>Authorized scopes</h3>
      <ScopesField :currentScopes="role.scopes" @add-scope="addScope" @delete-scope="deleteScope" />
      <div class="actions">
        <button class="ui primary button" :class="{ loading: role.loading }" :disabled="role.loading" type="submit">{{ action }}</button>
      </div>
    </form>
  </div>
</template>

<script>
import Scope from '../../models/scope.model'
import FormErrors from './FormErrors.vue'
import ScopesField from './ScopesField.vue'

export default {
  name: 'role-form',
  props: ['role', 'action'],
  emits: ['submit'],
  components: {
    FormErrors,
    ScopesField
  },
  methods: {
    submit () {
      this.$emit('submit')
    },
    addScope () {
      this.role.scopes.push({ model: new Scope(), method: 'GET' })
    },
    deleteScope (scope) {
      this.role.scopes.splice(
        this.role.scopes.indexOf(scope),
        1
      )
    }
  }
}
</script>
