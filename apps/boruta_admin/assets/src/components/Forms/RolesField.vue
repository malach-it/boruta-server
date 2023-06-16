<template>
  <div class="field edit-roles">
    <div v-for="(role, index) in currentRoles" class="field" :key="index">
      <div class="ui right icon input">
        <select type="text" v-model="role.model" class="roles-select">
          <option :value="role" v-for="role in roleOptions(role.model)" :key="role.id">{{ role.name }}</option>
        </select>
        <i v-on:click="deleteRole(role)" class="close icon"></i>
      </div>
    </div>
    <a v-on:click.prevent="addRole()" class="ui blue fluid button">Add a role</a>
  </div>
</template>

<script>
import Role from '../../models/role.model'

export default {
  name: 'RolesField',
  props: ['currentRoles'],
  data () {
    return {
      roles: []
    }
  },
  computed: {
    roleOptions () {
      const vm = this
      return function (role) {
        return vm.roles.map((currentRole) => {
          if (role.id === currentRole.id) {
            return role
          }
          return currentRole
        })
      }
    }
  },
  mounted () {
    Role.all().then((roles) => {
      this.roles = roles
    })
  },
  methods: {
    deleteRole (role) {
      this.$emit('delete-role', role)
    },
    addRole () {
      this.$emit('add-role')
    }
  }
}
</script>

<!-- Add "roled" attribute to limit CSS to this component only -->
<style roled lang="scss">
.edit-roles {
  .ui.icon.input>i.icon.close {
    cursor: pointer;
    pointer-events: all;
  }
  .roles-select {
    margin-right: 3em;
  }
}
</style>
