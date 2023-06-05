<template>
  <div class="role-list">
    <Toaster :active="deleted" message="Role has been deleted" type="warning" />
    <router-link :to="{ name: 'new-role' }" class="ui violet main create button">Add a role</router-link>
    <div class="container">
      <div class="ui info message">
        TODO Roles description
      </div>
      <div class="ui three column roles stackable grid">
        <div v-for="role in roles" :key="role.id" class="column">
          <div class="ui upstream highlightable segment">
            <div class="actions">
              <router-link
                :to="{ name: 'edit-role', params: { roleId: role.id } }"
                class="ui tiny blue button">edit</router-link>
              <a v-on:click="deleteRole(role)" class="ui tiny red button">delete</a>
            </div>
            <div class="ui attribute list">
              <div class="item">
                <span class="header">Role ID</span>
                <span class="description">{{ role.id }}</span>
              </div>
              <div class="item">
                <span class="header">Name</span>
                <span class="description">{{ role.name }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import Role from '../../models/role.model'
import Toaster from '../../components/Toaster.vue'

export default {
  name: 'role-list',
  components: {
    Toaster
  },
  data () {
    return {
      roles: [],
      deleted: false
    }
  },
  mounted () {
    this.getRoles()
  },
  methods: {
    getRoles () {
      Role.all().then((roles) => {
        this.roles = roles
      })
    },
    deleteRole (role) {
      if (!confirm('Are you sure ?')) return
      this.deleted = false
      role.destroy().then(() => {
        this.deleted = true
        this.roles.splice(this.roles.indexOf(role), 1)
      })
    }
  }
}
</script>

<style scoped lang="scss">
</style>
