<template>
  <div class="new-role">
    <div class="ui container">
      <RoleForm :role="role" @submit="createRole()" @back="back()" action="Create" />
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
    back () {
      this.$router.push({ name: 'role-list' })
    },
    createRole () {
      return this.role.save().then(() => {
        this.$router.push({ name: 'role-list' })
      }).catch()
    }
  }
}
</script>

<style scoped lang="scss">
.new-role {
  .field {
    position: relative;
    &.roles input {
      margin-right: 3em;
    }
  }
  .ui.icon.input>i.icon.close {
    cursor: pointer;
    pointer-events: all;
  }
  .authorized-scopes-select {
    margin-right: 3em;
  }
}
</style>
