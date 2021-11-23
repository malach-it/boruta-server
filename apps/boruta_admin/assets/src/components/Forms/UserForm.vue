<template>
  <div class="user-form">
    <div class="ui large segment">
      <FormErrors :errors="user.errors" v-if="user.errors" />
      <h3>Accessible scopes</h3>
      <form class="ui form" v-on:submit.prevent="submit()">
        <ScopesField :currentScopes="user.authorized_scopes" @delete-scope="deleteScope" @add-scope="addScope" />
        <hr />
        <button class="ui large right floated violet button" type="submit">{{ action }}</button>
        <a v-on:click="back()" class="ui large button">Back</a>
      </form>
    </div>
  </div>
</template>

<script>
import Scope from '@/models/scope.model'
import ScopesField from '@/components/Forms/ScopesField.vue'
import FormErrors from '@/components/Forms/FormErrors.vue'

export default {
  name: 'user-form',
  props: ['user', 'action'],
  components: {
    ScopesField,
    FormErrors
  },
  mounted () {
    Scope.all().then((scopes) => {
      this.scopes = scopes
    })
  },
  data () {
    return {
      scopes: []
    }
  },
  methods: {
    back () {
      this.$emit('back')
    },
    submit () {
      this.$emit('submit', this.user)
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
