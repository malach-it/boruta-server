<template>
  <div class="ui segment">
    <div class="ui breadcrumb">
      <span v-for="(item, index) in items" :key="item.path">
        <span v-if="index + 1 < items.length">
          <router-link :to="item.path" class="section">{{ item.label }}</router-link>
          <i class="right angle icon divider"></i>
        </span>
        <span class="section" v-else>
          {{ item.label }}
        </span>
      </span>
    </div>
  </div>
</template>

<script>
const labels = {
  'root': 'Home',
  'dashboard': 'Dashboard',
  'relying-parties': "Relying parties",
  'new-relying-party': 'Create',
  'edit-relying-party': 'Edit',
  'edit-registration-template': 'Edit registration template',
  'edit-session-template': 'Edit login template',
  'edit-new-reset-password-template': 'Edit send reset password instructions template',
  'edit-edit-reset-password-template': 'Edit reset password template',
  'edit-registration-template': 'Edit registration template',
  'user-list': 'Users',
  'edit-user': 'Edit user',
  'clients': 'Clients',
  'new-client': 'Create',
  'edit-client': 'Edit',
  'upstreams': 'Upstreams',
  'new-upstream': 'Create',
  'edit-upstream': 'Edit',
  'scopes': 'Scopes'
}

export default {
  name: 'breadcrumb',
  computed: {
    items () {
      const items = this.$route.matched
        .filter(({ name }) => name)
        .filter(({ name }) => labels[name])
        .map(({ name, path }) => {
          return {
            label: labels[name],
            path: path
          }
        })

      console.log(items)
      return items || []
    }
  }
}
</script>

<style scoped lang="scss">
.breadcrumb {
  font-size: 1.3em;
  .divider {
    color: white!important;
  }
}
</style>
