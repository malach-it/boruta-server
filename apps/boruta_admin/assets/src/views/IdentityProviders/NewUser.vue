<template>
  <div class="new-user">
    <div class="container">
      <div class="ui stackable grid">
        <div class="four wide column">
          <div class="sidebar">
            <router-link :to="{ name: 'user-list' }" class="ui right floated button">Back</router-link>
          </div>
        </div>
        <div class="twelve wide column">
          <UserForm :user="user" @submit="createUser()" @back="back()" action="Create" />
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import User from '../../models/user.model'
import UserForm from '../../components/Forms/UserForm.vue'
import Toaster from '../../components/Toaster.vue'

export default {
  name: 'new-user',
  components: {
    UserForm,
    Toaster
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
    createUser () {
      this.success = false
      return this.user.save().then(() => {
        this.success = true
        this.$router.push({ name: 'edit-user', params: { userId: this.user.id } })
      }).catch()
    }
  }
}
</script>
