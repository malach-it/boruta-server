<template>
  <div class="edit-user">
    <Toaster :active="success" message="User has been updated" type="success" />
    <div class="ui container">
      <div class="ui segment">
        <div class="ui attribute list">
          <div class="item">
            <span class="header">Provider</span>
            <span class="description">{{ user.provider }}</span>
          </div>
          <div class="item">
            <span class="header">User ID</span>
            <span class="description">{{ user.id }}</span>
          </div>
          <div class="item">
            <span class="header">Email</span>
            <span class="description">{{ user.email }}</span>
          </div>
        </div>
      </div>
      <UserForm :user="user" @submit="updateUser()" @back="back()" action="Update" />
    </div>
  </div>
</template>

<script>
import User from '../../models/user.model'
import UserForm from '../../components/Forms/UserForm.vue'
import Toaster from '../../components/Toaster.vue'

export default {
  name: 'edit-user',
  components: {
    UserForm,
    Toaster
  },
  mounted () {
    const { userId } = this.$route.params
    User.get(userId).then((user) => {
      this.user = user
    })
  },
  data () {
    return {
      user: new User(),
      success: false
    }
  },
  methods: {
    back () {
      this.$router.push({ name: 'user-list' })
    },
    updateUser () {
      this.success = false
      return this.user.save().then(() => {
        this.success = true
      }).catch()
    }
  }
}
</script>
