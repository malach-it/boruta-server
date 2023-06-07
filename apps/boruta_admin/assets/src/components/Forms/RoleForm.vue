<template>
  <div class="role-form">
    <div class="ui segment">
      <FormErrors v-if="role.errors" :errors="role.errors" />
      <form class="ui form" @submit.prevent="submit">
        <div class="field" :class="{ 'error': role.errors?.name }">
          <label>Name</label>
          <input type="text" v-model="role.name" placeholder="administrator">
        </div>
        <hr />
        <ScopesField :currentScopes="role.scopes" @addScope="addScope" @deleteScope="deleteScope" />
        <button class="ui right floated violet button" type="submit">{{ action }}</button>
        <a class="ui button" v-on:click="back()">Back</a>
      </form>
    </div>
  </div>
</template>

<script>
import Scope from '../../models/scope.model'
import Role from '../../models/role.model'
import FormErrors from '../../components/Forms/FormErrors.vue'
import ScopesField from '../../components/Forms/ScopesField.vue'

export default {
  name: 'role-form',
  props: ['role', 'action'],
  components: {
    FormErrors,
    ScopesField
  },
  mounted () {
  },
  methods: {
    back () {
      this.$emit('back')
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

<style scoped lang="scss">
.role-form {
  .field {
    position: relative;
    &.roles input {
      margin-right: 3em;
    }
  }
  .ui.icon.input>i.icon.close {
    cursor: pointer;
    pointer-events: all;
    position: absolute;
  }
  .authorized-scopes-select {
    margin-right: 3em;
  }
}
</style>
