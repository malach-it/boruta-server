<template>
  <div class="edit-user">
    <Toaster :active="success" message="User has been updated" type="success" />
    <div class="container">
      <div class="ui stackable grid">
        <div class="four wide column">
          <div class="sidebar">
            <div class="ui segment">
              <div class="ui attribute list">
                <div class="item">
                  <span class="header">Backend</span>
                  <span class="description">{{ user.backend.name }}</span>
                </div>
                <div class="item">
                  <span class="header">User ID</span>
                  <span class="description">{{ user.id }}</span>
                </div>
                <div class="item">
                  <span class="header">User UID</span>
                  <span class="description">{{ user.uid }}</span>
                </div>
                <div class="item">
                  <span class="header">Email</span>
                  <span class="description">{{ user.email }}</span>
                </div>
              </div>
            </div>
            <div class="ui segment" v-for="(attributes, federatedServerName) in user.federated_metadata">
              <h2>Federated attributes - {{ federatedServerName }}</h2>
              <div class="ui attribute list">
                <div class="item" v-for="(value, name) in attributes">
                  <span class="header">{{ name }}</span>
                  <span class="description">{{ value }}</span>
                </div>
              </div>
            </div>
            <router-link :to="{ name: 'client-list' }" class="ui right floated button">Back</router-link>
          </div>
        </div>
        <div class="twelve wide column">
          <UserForm :user="user" @submit="updateUser()" @back="back()" action="Update" />
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
  name: 'edit-user',
  components: {
    UserForm,
    Toaster
  },
  mounted() {
    const { userId } = this.$route.params
    User.get(userId).then((user) => {
      this.user = user
    })
  },
  data() {
    return {
      user: new User(),
      success: false
    }
  },
  methods: {
    back() {
      this.$router.push({ name: 'user-list' })
    },
    async updateUser () {
      this.success = false
      return this.user.save().then(() => {
        this.success = true
      }).catch()
    }
  }
}
</script>
