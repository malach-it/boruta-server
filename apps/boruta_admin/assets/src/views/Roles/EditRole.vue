<template>
  <div class="edit-role">
    <Toaster :active="success" message="Role has been updated" type="success" />
    <div class="container">
      <div class="ui error message" v-if="error">
        {{ error }}
      </div>
      <div class="ui stackable grid">
        <div class="four wide column">
          <div class="sidebar">
            <div class="ui segment">
              <div class="ui attribute list">
                <div class="item">
                  <span class="header">Role ID</span>
                  <span class="description">{{ role.id }}</span>
                </div>
              </div>
            </div>
            <router-link :to="{ name: 'role-list' }" class="ui right floated button">Back</router-link>
          </div>
        </div>
        <div class="twelve wide column">
          <ResourceEditTabs :resource-id="role.id">
            <RoleForm :role="role" @submit="updateRole()" action="Update" />
          </ResourceEditTabs>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import Role from '../../models/role.model'
import RoleForm from '../../components/Forms/RoleForm.vue'
import ResourceEditTabs from '../../components/ResourceEditTabs.vue'
import Toaster from '../../components/Toaster.vue'

export default {
  name: 'roles',
  components: {
    RoleForm,
    ResourceEditTabs,
    Toaster
  },
  mounted () {
    const { roleId } = this.$route.params
    Role.get(roleId).then((role) => {
      this.error = null
      this.role = role
    }).catch((error) => {
      this.error = error.response?.data?.message || error.message
    })
  },
  data () {
    return {
      role: new Role(),
      success: false,
      error: null
    }
  },
  methods: {
    updateRole () {
      this.success = false
      return this.role.save().then(() => {
        this.success = true
      }).catch()
    }
  }
}
</script>
