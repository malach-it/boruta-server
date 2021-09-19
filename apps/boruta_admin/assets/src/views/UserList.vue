<template>
  <div class="user-list">
    <div class="ui container">
      <h1>Users</h1>
      <div v-for="user in users" class="ui big user segments" :key="user.id">
        <div class="ui segment">
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
          </div>
          <span v-for="scope in user.authorized_scopes" class="ui olive label" :key="scope.model.id">
            {{ scope.model.name }}
          </span>
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
