<template>
  <div class="edit-user">
    <div class="ui container">
      <h1>Edit a user</h1>
      <div class="ui big violet segment">
        <h2>{{ user.email }}</h2>
        <div v-if="errors" class="ui error message">
          <ul>
            <li v-for="key in Object.keys(errors)" :key="key"><strong>{{ key }} :</strong> {{ errors[key][0] }}</li>
          </ul>
        </div>
        <p><strong>id:</strong> {{ user.id }}</p>
        <h3>Accessible scopes</h3>
        <form class="ui form" v-on:submit.prevent="updateUser()">
          <div class="field">
            <div v-for="(authorizedScope, index) in user.authorized_scopes" class="field" :key="index">
              <div class="ui right icon input">
                <select type="text" v-model="authorizedScope.model" class="authorized-scopes-select">
                  <option :value="scope" v-for="scope in scopeModels(authorizedScope)" :key="scope.id">{{ scope.name }}</option>
                </select>
                <i v-on:click="deleteScope(authorizedScope)" class="close icon"></i>
              </div>
            </div>
            <button v-on:click.prevent="addScope()" class="ui blue fluid button">Add a scope</button>
          </div>
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

export default {
  name: 'users',
  // TODO look for async components
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
  computed: {
    scopeModels () {
      const vm = this
      return function (authorizedScope) {
        return vm.scopes.map((scope) => {
          if (authorizedScope.id === scope.id) {
            return authorizedScope
          }
          return scope
        })
      }
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
  .ui.icon.input>i.icon.close {
    cursor: pointer;
    pointer-events: all;
  }
  .authorized-scopes-select {
    margin-right: 3em;
  }
}
</style>
