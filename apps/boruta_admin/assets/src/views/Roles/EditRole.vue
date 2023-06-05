<template>
  <div class="edit-role">
    <Toaster :active="success" message="Role has been updated" type="success" />
    <div class="ui container">
      <div class="ui segment">
        <div class="ui attribute list">
          <div class="item">
            <span class="header">Role ID</span>
            <span class="description">{{ role.id }}</span>
          </div>
        </div>
      </div>
      <RoleForm :role="role" @submit="updateRole()" @back="back()" action="Update" />
    </div>
  </div>
</template>

<script>
import Role from '../../models/role.model'
import RoleForm from '../../components/Forms/RoleForm.vue'
import Toaster from '../../components/Toaster.vue'

export default {
  name: 'roles',
  components: {
    RoleForm,
    Toaster
  },
  mounted () {
    const { roleId } = this.$route.params
    Role.get(roleId).then((role) => {
      this.role = role
    })
  },
  data () {
    return {
      role: new Role(),
      success: false
    }
  },
  methods: {
    back () {
      this.$router.push({ name: 'role-list' })
    },
    updateRole () {
      this.success = false
      return this.role.save().then(() => {
        this.success = true
      }).catch()
    }
  }
}
</script>
