<template>
  <div class="new-role">
    <div class="container">
      <div class="ui stackable grid">
        <div class="four wide column">
          <div class="sidebar">
            <router-link :to="{ name: 'role-list' }" class="ui right floated button">Back</router-link>
          </div>
        </div>
        <div class="twelve wide column">
          <RoleForm :role="role" @submit="createRole()" action="Create" />
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import Role from '../../models/role.model'
import RoleForm from '../../components/Forms/RoleForm.vue'

export default {
  name: 'new-role',
  components: {
    RoleForm
  },
  data () {
    return {
      role: new Role()
    }
  },
  methods: {
    createRole () {
      return this.role.save().then(({ id }) => {
        this.$router.push({ name: 'edit-role', params: { roleId: id } })
      }).catch()
    }
  }
}
</script>
