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
          <input type="text" v-model="user.email" placeholder="email@example.com">
        </div>
        <div class="field" v-if="!user.isPersisted">
          <label>Password</label>
          <input type="password" v-model="user.password">
        </div>
        <section v-if="user.isPersisted">
          <h3>Authorized scopes</h3>
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
import Backend from '../../models/backend.model'
import ScopesField from './ScopesField.vue'
import FormErrors from './FormErrors.vue'

export default {
  name: 'user-form',
  props: ['user', 'action'],
  components: {
    ScopesField,
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
      console.log(this.backends)
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
    }
  }
}
</script>
