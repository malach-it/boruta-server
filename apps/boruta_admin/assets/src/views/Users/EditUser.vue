<template>
  <div class="edit-user">
    <div class="main header">
      <h1>Edit a user</h1>
    </div>
    <div class="ui container">
      <UserForm :user="user" @submit="updateUser()" @back="back()" action="Update" />
    </div>
  </div>
</template>

<script>
import User from '@/models/user.model'
import UserForm from '@/components/Forms/UserForm.vue'

export default {
  name: 'users',
  components: {
    UserForm
  },
  mounted () {
    const { userId } = this.$route.params
    User.get(userId).then((user) => {
      this.user = user
    })
  },
  data () {
    return {
      user: new User()
    }
  },
  methods: {
    back () {
      this.$router.push({ name: 'user-list' })
    },
    updateUser () {
      return this.user.save().then(() => {
        this.$router.push({ name: 'user-list' })
      }).catch(console.debug)
    }
  }
}
</script>
