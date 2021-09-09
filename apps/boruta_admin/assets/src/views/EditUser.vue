<template>
  <div class="edit-user">
    <div class="ui container">
      <h1>Edit a user</h1>
      <div class="ui big violet segment">
        <h2>{{ user.email }}</h2>
        <FormErrors :errors="errors" v-if="errors" />
        <p><strong>id:</strong> {{ user.id }}</p>
        <h3>Accessible scopes</h3>
        <form class="ui form" v-on:submit.prevent="updateUser()">
          <ScopesField :currentScopes="user.authorized_scopes" @delete-scope="deleteScope" @add-scope="addScope" />
          <button class="ui violet button" type="submit">Update</button>
          <router-link :to="{ name: 'user-list' }" class="ui button">Back</router-link>
        </form>
      </div>
    </div>
  </div>
</template>

<script>
import User from '@/models/user.model'
import Scope from '@/models/scope.model'
import ScopesField from '@/components/ScopesField.vue'
import FormErrors from '@/components/FormErrors.vue'

export default {
  name: 'users',
  // TODO look for async components
  components: {
    ScopesField,
    FormErrors
  },
  mounted () {
    const { userId } = this.$route.params
    User.get(userId).then((user) => {
      this.user = user
    })
    Scope.all().then((scopes) => {
      this.scopes = scopes
    })
  },
  data () {
    return {
      errors: null,
      scopes: [],
      user: new User()
    }
  },
  methods: {
    updateUser () {
      this.errors = null
      return this.user.save().then(() => {
        this.$router.push({ name: 'user-list' })
      }).catch((errors) => {
        this.errors = errors
      })
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

<style scoped lang="scss">
.edit-user {
}
</style>
