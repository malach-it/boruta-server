<template>
  <div class="user-list">
    <h1>User management</h1>
    <div class="container">
      <div class="ui three column stackable grid">
        <div v-for="user in users" class="column" :key="user.id">
          <div class="ui large user segment">
            <div class="actions">
              <router-link
                :to="{ name: 'edit-user', params: { userId: user.id } }"
                class="ui tiny blue button">edit</router-link>
              <a v-on:click="deleteUser(user)" class="ui tiny red button">delete</a>
            </div>
            <div class="ui attribute list">
              <div class="item">
                <span class="header">Email</span>
                <span class="description">{{ user.email }}</span>
              </div>
              <div class="item" v-if="user.authorized_scopes.length">
                <span class="header">Scopes</span>
                <div class="description">
                  <span v-for="scope in user.authorized_scopes" class="ui olive label" :key="scope.model.id">
                    {{ scope.model.name }}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import User from '@/models/user.model'

export default {
  name: 'user-list',
  data () {
    return { users: [] }
  },
  mounted () {
    this.getUsers()
  },
  methods: {
    getUsers () {
      User.all().then((users) => {
        this.users = users
      })
    },
    deleteUser (user) {
      if (confirm('Are you sure ?')) {
        user.destroy().then(() => {
          this.users.splice(this.users.indexOf(user), 1)
        })
      }
    }
  }
}
</script>

<style scoped lang="scss">
</style>
